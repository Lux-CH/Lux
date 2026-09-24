//
//  OnboardMapView.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import MapKit
import LuxCom

struct OnboardMapView: UIViewRepresentable {
    let session: OnboardSession
    @Binding var isFollowing: Bool
    @Binding var showsOverview: Bool
    let topInset: CGFloat
    let bottomInset: CGFloat

    func makeCoordinator() -> OnboardMapController {
        OnboardMapController(session: session)
    }

    func makeUIView(context: Context) -> MKMapView {
        context.coordinator.mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let controller = context.coordinator
        controller.onUserMovedMap = {
            guard isFollowing || showsOverview else { return }
            withAnimation(.snappy) {
                isFollowing = false
                showsOverview = false
            }
        }
        controller.setInsets(top: topInset, bottom: bottomInset)
        controller.syncContent()
        controller.setMode(following: isFollowing, overview: showsOverview)
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: OnboardMapController) {
        coordinator.teardown()
    }
}

@MainActor
final class OnboardMapController: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
    let mapView = MKMapView()
    var onUserMovedMap: () -> Void = {}

    private let session: OnboardSession
    private let frameDriver = FrameDriver()
    private let puckModel = PuckModel()

    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0
    private var isFollowing = true
    private var showsOverview = false
    private var isTouching = false
    private var lastPhase: OnboardPhase?

    private var puck: MapPin?
    private var ghost: MapPin?
    private var estimated: MapPin?
    private var approaching: MapPin?
    private var destination: MapPin?
    private var stopPins: [MapPin] = []
    private var levelPins: [MapPin] = []
    private var sectorPins: [MapPin] = []
    private var sectorSignature = ""
    private var levelSignature = ""
    private var stationOverlays: [MKOverlay] = []
    private var stationPins: [MapPin] = []
    private var stationContent = StationOverlayContent()
    private var stationLayouts: [Int: StationLayout] = [:]
    private var stationTask: Task<Void, Never>?
    private var stationLegsSignature = ""
    private var stationSignature = ""
    private var stationDetail: StationDetail = .hidden

    private var routeSignature = ""
    private var arrowSignature = ""
    private var stopSignature = ""
    private var routeLines: [RouteLine] = []
    private var arrowOverlays: [MKOverlay] = []
    private var travelledLine: RouteLine?
    private var remainingLines: [RouteLine] = []
    private var displayedAlong: CLLocationDistance = 0
    private var appliedAlong: CLLocationDistance = -1
    private var appliedAlongAt: CFTimeInterval = 0

    private var lastFrame: CFTimeInterval?
    private var puckCoordinate: CLLocationCoordinate2D?
    private var puckHeading: CLLocationDirection?
    private var followDistance: CLLocationDistance = 430
    private var followPitch: Double = 40
    private var followHeading: CLLocationDirection?
    private var aheadRatio: Double = 0.12
    private var hasPlacedCamera = false
    private var transition: (from: MKMapCamera, began: CFTimeInterval)?

    private static let transitionDuration: CFTimeInterval = 0.4
    private static let walkBlue = UIColor(red: 0.1, green: 0.5, blue: 1, alpha: 1)
    private static let walkBlueDark = UIColor(red: 0.05, green: 0.3, blue: 0.7, alpha: 1)

    init(session: OnboardSession) {
        self.session = session
        super.init()

        let configuration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration
        mapView.delegate = self
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = false
        mapView.insetsLayoutMarginsFromSafeArea = false

        for recognizer: UIGestureRecognizer in [UIPanGestureRecognizer(), UIPinchGestureRecognizer(), UIRotationGestureRecognizer()] {
            recognizer.addTarget(self, action: #selector(userGesture(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            mapView.addGestureRecognizer(recognizer)
        }
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(userTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        doubleTap.cancelsTouchesInView = false
        mapView.addGestureRecognizer(doubleTap)
        let touch = TouchRecognizer(target: self, action: #selector(touchChanged(_:)))
        touch.delegate = self
        mapView.addGestureRecognizer(touch)

        frameDriver.onFrame = { [weak self] timestamp in self?.frame(at: timestamp) }
        frameDriver.isRunning = UIApplication.shared.applicationState != .background
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func teardown() {
        frameDriver.isRunning = false
        stationTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func didEnterBackground() {
        frameDriver.isRunning = false
    }

    @objc private func willEnterForeground() {
        lastFrame = nil
        frameDriver.isRunning = true
    }

    // MARK: - SwiftUI inputs

    func setInsets(top: CGFloat, bottom: CGFloat) {
        guard top != topInset || bottom != bottomInset else { return }
        topInset = top
        bottomInset = bottom
        mapView.layoutMargins = UIEdgeInsets(top: top, left: 10, bottom: bottom, right: 10)
    }

    func setMode(following: Bool, overview: Bool) {
        let wasFollowing = isFollowing
        let wasOverview = showsOverview
        isFollowing = following
        showsOverview = overview

        if overview && !wasOverview {
            transition = nil
            showOverview()
        } else if following && (!wasFollowing || wasOverview) {
            beginTransition()
        }
    }

    // MARK: - Content

    func syncContent() {
        let phase = session.phase
        if lastPhase != nil, lastPhase != phase, isFollowing, !showsOverview {
            beginTransition()
        }
        lastPhase = phase

        syncRoute()
        syncArrow()
        syncStops()
        syncStations()
        syncLevelChanges()
        syncSectors()
        syncMarkers()
        puckModel.style = puckStyle
    }

    // Platform edges of the stations where the trip boards or leaves a train; the
    // tracks it uses get a tinted platform, a darker rail in the line's colour and a callout.
    private func syncStations() {
        let legs = session.legs
        let legsSignature = legs.map { "\($0.tripId ?? "")|\($0.from.stopId ?? "")|\($0.to.stopId ?? "")" }.joined(separator: ",")
        if legsSignature != stationLegsSignature {
            stationLegsSignature = legsSignature
            stationTask?.cancel()
            stationTask = Task { [weak self] in
                let layouts = await StationLayoutStore.shared.layouts(for: legs)
                guard let self, !Task.isCancelled else { return }
                self.stationLayouts = layouts
                self.stationSignature = ""
                self.syncStations()
            }
        }

        let signature = "\(stationLayouts.keys.sorted())|" + legs.map { "\($0.from.track ?? "")>\($0.to.track ?? "")" }.joined(separator: ",")
        guard signature != stationSignature else { return }
        stationSignature = signature
        stationContent = StationOverlayContent(legs: legs, layouts: stationLayouts)
        applyStationDetail(force: true)
    }

    // Sector letters on the platform of the train about to be boarded, up close: solid
    // where its coaches stop (1st class with the yellow band), faded elsewhere.
    private func syncSectors() {
        var sectors: [StationLayout.Sector] = []
        var covered: Set<String>?
        var firstClass: Set<String> = []
        if stationDetail >= .allLabels, session.phase == .walking || session.phase == .waiting,
           let (_, leg) = session.nextTransitLeg, leg.mode.isMainlineRail,
           let uic = StationLayout.uic(fromStopId: leg.from.stopId), let layout = stationLayouts[uic],
           let track = layout.track(named: leg.from.track ?? leg.from.scheduledTrack, stopId: leg.from.stopId) {
            sectors = track.sectors
            if let formation = session.formation {
                covered = formation.coveredSectors
                firstClass = Set(formation.sectors.first)
            }
        }
        let signature = sectors.map(\.s).joined() + "|" + (covered.map { $0.sorted().joined() } ?? "?") + "|" + firstClass.sorted().joined()
        guard signature != sectorSignature else { return }
        sectorSignature = signature
        mapView.removeAnnotations(sectorPins)
        sectorPins = sectors.map { sector in
            let pin = MapPin(kind: .sector, coordinate: sector.coordinate, anchorY: nil)
            pin.content = AnyView(SectorChipView(
                letter: sector.s,
                covered: covered.map { $0.contains(sector.s) },
                firstClass: firstClass.contains(sector.s)
            ))
            return pin
        }
        mapView.addAnnotations(sectorPins)
    }

    // Stairs, lifts and ramps of the current walk, where it changes level in a station.
    private func syncLevelChanges() {
        var changes: [WalkManeuver] = []
        if session.phase == .walking, session.maneuvers.indices.contains(session.legIndex) {
            changes = session.maneuvers[session.legIndex].filter(\.isLevelChange)
        }
        let path = session.currentPath
        let signature = "\(session.legIndex)|\(path?.coordinates.count ?? 0)|" + changes.map { "\(Int($0.along))\($0.symbolName)" }.joined(separator: ",")
        guard signature != levelSignature else { return }
        levelSignature = signature
        mapView.removeAnnotations(levelPins)
        levelPins = changes.compactMap { change in
            guard let coordinate = path?.coordinate(at: change.along) else { return nil }
            let pin = MapPin(kind: .levelChange, coordinate: coordinate, anchorY: nil)
            pin.content = AnyView(
                Image(systemName: change.symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(Self.walkBlue)))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .accessibilityLabel(Text(change.instruction))
            )
            return pin
        }
        mapView.addAnnotations(levelPins)
    }

    private func applyStationDetail(force: Bool = false) {
        let detail = StationDetail(cameraDistance: mapView.camera.centerCoordinateDistance)
        guard force || detail != stationDetail else { return }
        stationDetail = detail
        syncSectors()

        mapView.removeOverlays(stationOverlays)
        mapView.removeAnnotations(stationPins)
        stationOverlays = []
        stationPins = []
        guard detail >= .tracks else { return }

        // bottom to top: rails, platforms, our rails, platform edges
        func area(_ coordinates: [CLLocationCoordinate2D], fill: UIColor, stroke: UIColor = .clear) -> StationArea {
            let polygon = StationArea(coordinates: coordinates, count: coordinates.count)
            polygon.fill = fill
            polygon.stroke = stroke
            return polygon
        }
        let idleRails: [MKOverlay] = stationContent.rails.filter { $0.color == nil }.map {
            area($0.coordinates, fill: StationStyle.idleRail)
        }
        let areas: [MKOverlay] = stationContent.areas.map {
            area(
                $0.coordinates,
                fill: $0.color.map { UIColor($0).withAlphaComponent(StationStyle.highlightedPlatformOpacity) } ?? StationStyle.platformFill,
                stroke: StationStyle.platformStroke
            )
        }
        let ourRails: [MKOverlay] = stationContent.rails.compactMap { rail in
            rail.color.map { area(rail.coordinates, fill: StationStyle.ourRailColor(for: $0)) }
        }
        let edges: [MKOverlay] = stationContent.lines.map {
            RouteLine.make($0.coordinates, color: StationStyle.idleEdge, width: StationStyle.idleEdgeWidth)
        }
        let stairs: [MKOverlay] = stationContent.visibleStairs(at: detail).flatMap { stairway -> [MKOverlay] in
            [area(stairway.band, fill: StationStyle.stairBand)]
                + (stairway.treads.count >= 3 ? [area(stairway.treads, fill: StationStyle.stairTread)] : [])
        }
        stationOverlays = idleRails + areas + ourRails + stairs + edges
        // all under the route, so the walk between platforms stays on top
        for overlay in stationOverlays.reversed() {
            mapView.insertOverlay(overlay, at: 0, level: .aboveRoads)
        }

        stationPins = stationContent.visibleLabels(at: detail)
            .map { label in
                let kind: MapPin.Kind = label.color == nil ? .stationTrack : .stationCurrentTrack
                let pin = MapPin(kind: kind, coordinate: label.coordinate, anchorY: StationLabelView.anchorsAtBottom(label) ? MapPin.bottom : nil)
                pin.content = AnyView(StationLabelView(label: label))
                return pin
            }
            + stationContent.visibleAccess(at: detail).map { point in
                let pin = MapPin(kind: .stationAccess, coordinate: point.coordinate, anchorY: nil)
                pin.content = AnyView(StationAccessView(kind: point.kind))
                return pin
            }
        mapView.addAnnotations(stationPins)
    }

    private func syncRoute() {
        let legs = session.legs
        let paths = session.paths
        let current = session.phase == .arrived ? legs.count : session.legIndex
        let signature = "\(current)|" + paths.enumerated().map { index, path in
            "\(legs[index].tripId ?? "")-\(path.coordinates.count)-\(Int(path.length))"
        }.joined(separator: ",")

        if signature != routeSignature {
            routeSignature = signature
            mapView.removeOverlays(routeLines)
            routeLines = []
            travelledLine = nil
            remainingLines = []
            appliedAlong = -1

            for (index, leg) in legs.enumerated() where index < paths.count {
                let coordinates = paths[index].coordinates
                guard coordinates.count >= 2 else { continue }
                let color = leg.isTransit ? UIColor(getLegColor(leg)) : Self.walkBlue

                if index < current {
                    routeLines.append(RouteLine.make(coordinates, color: UIColor.gray.withAlphaComponent(0.45), width: 5))
                } else if index == current {
                    let travelled = RouteLine.make(coordinates, color: UIColor.gray.withAlphaComponent(0.5), width: 6)
                    travelled.strokeEnd = 0
                    let casing = RouteLine.make(coordinates, color: .white, width: leg.isTransit ? 11 : 10)
                    let fill = RouteLine.make(coordinates, color: color, width: leg.isTransit ? 7 : 6)
                    routeLines += [travelled, casing, fill]
                    travelledLine = travelled
                    remainingLines = [casing, fill]
                } else {
                    routeLines.append(RouteLine.make(coordinates, color: .white, width: 8))
                    routeLines.append(RouteLine.make(coordinates, color: color.withAlphaComponent(0.75), width: 5))
                }
            }
            mapView.addOverlays(routeLines, level: .aboveRoads)
            arrowSignature = ""
        }
    }

    private func syncArrow() {
        var signature = ""
        var arrow: TurnArrow?
        if session.phase == .walking, !session.isOffRoute, let path = session.currentPath, let maneuver = session.nextManeuver {
            arrow = TurnArrow(path: path, along: maneuver.along)
            signature = "\(session.legIndex)-\(maneuver.along)-\(path.coordinates.count)"
        }
        guard signature != arrowSignature else { return }
        arrowSignature = signature
        mapView.removeOverlays(arrowOverlays)
        arrowOverlays = []
        guard let arrow else { return }
        arrowOverlays = [
            RouteLine.make(arrow.shaft, color: Self.walkBlueDark, width: 14),
            ArrowHead.make(arrow.head, fill: Self.walkBlueDark, outline: 4),
            RouteLine.make(arrow.shaft, color: .white, width: 8),
            ArrowHead.make(arrow.head, fill: .white, outline: 0)
        ]
        mapView.addOverlays(arrowOverlays, level: .aboveRoads)
    }

    private func syncStops() {
        var signature = ""
        var stops: [Place] = []
        var color = UIColor.gray
        var passed = 0
        if let (index, leg) = focusedTransitLeg {
            stops = leg.allStops
            color = UIColor(getLegColor(leg))
            passed = index == session.legIndex && session.phase == .riding ? session.nextStopIndex : 0
            signature = "\(index)-\(leg.tripId ?? "")-\(stops.count)-\(passed)"
        }
        guard signature != stopSignature else { return }
        stopSignature = signature
        mapView.removeAnnotations(stopPins)
        stopPins = stops.enumerated().map { stopIndex, stop in
            let isEnd = stopIndex == 0 || stopIndex == stops.count - 1
            let size: CGFloat = isEnd ? 16 : 9
            let ring = Color(stopIndex < passed ? .gray : color)
            let pin = MapPin(kind: .stop, coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon), anchorY: size / 2)
            pin.content = AnyView(
                VStack(spacing: 2) {
                    Circle()
                        .fill(.white)
                        .frame(width: size, height: size)
                        .overlay(Circle().stroke(ring, lineWidth: isEnd ? 4 : 2.5))
                        .shadow(color: .black.opacity(0.2), radius: 1.5)
                    if isEnd {
                        MapLabel(text: stop.name)
                    }
                }
            )
            return pin
        }
        mapView.addAnnotations(stopPins)
    }

    private func syncMarkers() {
        if let last = session.legs.last {
            let coordinate = CLLocationCoordinate2D(latitude: last.to.lat, longitude: last.to.lon)
            let name = session.destinationName.capitalizedFirstLetter
            if destination == nil {
                let pin = MapPin(kind: .destination, coordinate: coordinate, anchorY: 30)
                destination = pin
                mapView.addAnnotation(pin)
            }
            destination?.coordinate = coordinate
            update(destination, content: AnyView(
                VStack(spacing: 2) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.red.gradient))
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    MapLabel(text: name)
                }
            ), key: name)
        }

        let nextLeg = session.nextTransitLeg?.leg
        if let vehicle = session.approachingVehicle, let leg = nextLeg {
            let coordinate = CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lon)
            approaching = place(approaching, kind: .approaching, at: coordinate)
            update(approaching, content: AnyView(
                VehicleAnnotationView(annotation: VehicleAnnotation(id: "approaching", coordinate: coordinate, routeShortName: leg.routeShortName, color: getLegColor(leg), isLive: true))
            ), key: leg.tripId ?? "")
            approaching?.coordinate = coordinate
        } else {
            approaching = remove(approaching)
        }

        if session.hasEstimatedVehicle, session.approachingVehicle == nil, let leg = nextLeg,
           let coordinate = session.estimatedVehicleCoordinate(at: Date()) {
            estimated = place(estimated, kind: .estimated, at: coordinate)
            update(estimated, content: AnyView(
                VehicleAnnotationView(annotation: VehicleAnnotation(id: "estimated", coordinate: coordinate, routeShortName: leg.routeShortName, color: getLegColor(leg)))
                    .opacity(0.8)
            ), key: leg.tripId ?? "")
        } else {
            estimated = remove(estimated)
        }

        if session.isBehindOrAheadOfSchedule, let coordinate = session.scheduledWalkerCoordinate(at: Date()) {
            if ghost == nil {
                ghost = place(nil, kind: .ghost, at: coordinate)
                update(ghost, content: AnyView(
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color(Self.walkBlue)))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .opacity(0.55)
                ), key: "ghost")
            }
        } else {
            ghost = remove(ghost)
        }

        if puck == nil, let coordinate = session.riderCoordinate {
            let pin = MapPin(kind: .puck, coordinate: coordinate, anchorY: nil)
            pin.content = AnyView(PuckView(model: puckModel))
            puck = pin
            puckCoordinate = coordinate
            mapView.addAnnotation(pin)
        }
    }

    private func place(_ pin: MapPin?, kind: MapPin.Kind, at coordinate: CLLocationCoordinate2D) -> MapPin {
        if let pin { return pin }
        let pin = MapPin(kind: kind, coordinate: coordinate, anchorY: nil)
        mapView.addAnnotation(pin)
        return pin
    }

    private func remove(_ pin: MapPin?) -> MapPin? {
        if let pin { mapView.removeAnnotation(pin) }
        return nil
    }

    private func update(_ pin: MapPin?, content: @autoclosure () -> AnyView, key: String) {
        guard let pin, pin.contentKey != key else { return }
        pin.contentKey = key
        pin.content = content()
        (mapView.view(for: pin) as? HostingAnnotationView)?.show(pin)
    }

    private var focusedTransitLeg: (Int, Leg)? {
        guard session.phase != .arrived else { return nil }
        if let leg = session.currentLeg, leg.isTransit { return (session.legIndex, leg) }
        return session.nextTransitLeg
    }

    private var puckStyle: NavigationPuck.Style {
        if session.phase == .riding, let leg = session.currentLeg {
            let pill = LinePill(line: leg.routeShortName ?? "", mode: leg.mode, agency: leg.agencyId)
            return .vehicle(color: pill.lineColor, textColor: pill.textColorOnLineColor, symbol: NavigationPuck.vehicleSymbol(for: leg.mode))
        }
        return .walker
    }

    // MARK: - Frame loop

    private func frame(at timestamp: CFTimeInterval) {
        let dt = min(0.1, max(0, timestamp - (lastFrame ?? timestamp - 1.0 / 60)))
        lastFrame = timestamp
        func blend(_ timeConstant: Double) -> Double { 1 - exp(-dt / timeConstant) }

        glidePuck(blend: blend)
        glideRouteSplit(at: timestamp, blend: blend)

        let date = Date()
        if let ghost, let coordinate = session.scheduledWalkerCoordinate(at: date) {
            ghost.coordinate = coordinate
        }
        if let estimated, let coordinate = session.estimatedVehicleCoordinate(at: date) {
            estimated.coordinate = coordinate
        }

        driveCamera(at: timestamp, blend: blend)
        applyStationDetail()

        let camera = mapView.camera
        if let puckHeading {
            let relative = Angle360.delta(from: camera.heading, to: puckHeading)
            if puckModel.heading.map({ abs($0 - relative) > 0.3 }) ?? true { puckModel.heading = relative }
        } else if puckModel.heading != nil {
            puckModel.heading = nil
        }
        if abs(puckModel.pitch - camera.pitch) > 0.3 { puckModel.pitch = camera.pitch }
    }

    private func glidePuck(blend: (Double) -> Double) {
        guard let target = session.riderCoordinate else { return }
        if let current = puckCoordinate, current.distance(to: target) < 250 {
            let factor = blend(0.27)
            puckCoordinate = CLLocationCoordinate2D(
                latitude: current.latitude + (target.latitude - current.latitude) * factor,
                longitude: current.longitude + (target.longitude - current.longitude) * factor
            )
        } else {
            puckCoordinate = target
        }
        if let puckCoordinate { puck?.coordinate = puckCoordinate }

        if let targetHeading = session.heading {
            if let current = puckHeading {
                puckHeading = Angle360.normalized(current + Angle360.delta(from: current, to: targetHeading) * blend(0.23))
            } else {
                puckHeading = targetHeading
            }
        } else {
            puckHeading = nil
        }
    }

    private func glideRouteSplit(at timestamp: CFTimeInterval, blend: (Double) -> Double) {
        guard let travelledLine, let path = session.currentPath, path.length > 0 else { return }
        let target = session.alongInLeg
        displayedAlong = abs(target - displayedAlong) > 200 ? target : displayedAlong + (target - displayedAlong) * blend(0.4)
        guard abs(displayedAlong - appliedAlong) > 1, timestamp - appliedAlongAt > 0.2 else { return }
        appliedAlong = displayedAlong
        appliedAlongAt = timestamp
        let fraction = CGFloat(max(0, min(1, displayedAlong / path.length)))
        if let renderer = mapView.renderer(for: travelledLine) as? MKPolylineRenderer {
            renderer.strokeEnd = fraction
            renderer.setNeedsDisplay()
        }
        travelledLine.strokeEnd = fraction
        for line in remainingLines {
            line.strokeStart = fraction
            if let renderer = mapView.renderer(for: line) as? MKPolylineRenderer {
                renderer.strokeStart = fraction
                renderer.setNeedsDisplay()
            }
        }
    }

    // MARK: - Camera

    private func followTarget() -> (distance: CLLocationDistance, pitch: Double) {
        switch session.phase {
        case .walking: return session.isInStation ? (260, 30) : (430, 40)
        case .waiting: return (520, 35)
        case .riding:
            let speed = max(0, session.userLocation?.speed ?? 0)
            return (min(2600, max(800, 700 + speed * 55)), 45)
        case .arrived: return (650, 30)
        }
    }

    private func followCamera(distance: CLLocationDistance, pitch: Double, heading: CLLocationDirection) -> MKMapCamera? {
        guard let center = puckCoordinate ?? session.riderCoordinate
                ?? session.currentPath?.coordinate(at: session.alongInLeg) else { return nil }
        let lookAt = center.offset(by: distance * aheadRatio, bearing: heading)
        return MKMapCamera(lookingAtCenter: lookAt, fromDistance: distance, pitch: pitch, heading: heading)
    }

    private func driveCamera(at timestamp: CFTimeInterval, blend: (Double) -> Double) {
        guard isFollowing, !showsOverview, !isTouching else { return }
        let target = followTarget()
        let targetHeading = puckHeading ?? followHeading ?? 0

        if !hasPlacedCamera {
            guard let camera = followCamera(distance: target.distance, pitch: target.pitch, heading: targetHeading) else { return }
            hasPlacedCamera = true
            followDistance = target.distance
            followPitch = target.pitch
            followHeading = targetHeading
            mapView.setCamera(camera, animated: false)
            return
        }

        if let transition {
            let progress = min(1, (timestamp - transition.began) / Self.transitionDuration)
            let eased = 1 - pow(1 - progress, 3)
            guard let goal = followCamera(distance: target.distance, pitch: target.pitch, heading: targetHeading) else { return }
            let from = transition.from
            let camera = MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(
                    latitude: from.centerCoordinate.latitude + (goal.centerCoordinate.latitude - from.centerCoordinate.latitude) * eased,
                    longitude: from.centerCoordinate.longitude + (goal.centerCoordinate.longitude - from.centerCoordinate.longitude) * eased
                ),
                fromDistance: from.centerCoordinateDistance + (goal.centerCoordinateDistance - from.centerCoordinateDistance) * eased,
                pitch: from.pitch + (goal.pitch - from.pitch) * eased,
                heading: Angle360.normalized(from.heading + Angle360.delta(from: from.heading, to: goal.heading) * eased)
            )
            mapView.setCamera(camera, animated: false)
            if progress >= 1 {
                self.transition = nil
                followDistance = target.distance
                followPitch = target.pitch
                followHeading = targetHeading
            }
            calibrateAhead()
            return
        }

        followDistance += (target.distance - followDistance) * blend(0.8)
        followPitch += (target.pitch - followPitch) * blend(0.8)
        if let current = followHeading {
            followHeading = Angle360.normalized(current + Angle360.delta(from: current, to: targetHeading) * blend(0.3))
        } else {
            followHeading = targetHeading
        }
        guard let camera = followCamera(distance: followDistance, pitch: followPitch, heading: followHeading ?? 0) else { return }
        mapView.setCamera(camera, animated: false)
        calibrateAhead()
    }

    private func calibrateAhead() {
        let bounds = mapView.bounds
        let visibleHeight = bounds.height - topInset - bottomInset
        guard bounds.width > 0, visibleHeight > 100 else { return }
        let camera = mapView.camera
        let anchor = CGPoint(x: bounds.midX, y: topInset + visibleHeight * 0.68)
        let underAnchor = mapView.convert(anchor, toCoordinateFrom: mapView)
        let center = camera.centerCoordinate
        let distance = center.distance(to: underAnchor)
        guard distance.isFinite, camera.centerCoordinateDistance > 0 else { return }
        let direction = Angle360.delta(from: camera.heading, to: center.bearing(to: underAnchor))
        let behind = -distance * cos(direction * .pi / 180)
        let ratio = behind / camera.centerCoordinateDistance
        guard ratio.isFinite, abs(ratio) < 2 else { return }
        aheadRatio += (ratio - aheadRatio) * 0.2
    }

    private func beginTransition() {
        guard hasPlacedCamera else { return }
        transition = (mapView.camera.copy() as! MKMapCamera, CACurrentMediaTime())
    }

    private func showOverview() {
        var rect = MKMapRect.null
        let startLeg = session.phase == .arrived ? 0 : session.legIndex
        for index in startLeg..<session.legs.count where index < session.paths.count {
            let path = session.paths[index]
            let coordinates = index == session.legIndex ? path.slice(from: session.alongInLeg, to: path.length) : path.coordinates
            for coordinate in coordinates {
                let point = MKMapPoint(coordinate)
                rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
            }
        }
        if let location = session.userLocation {
            let point = MKMapPoint(location.coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        guard !rect.isNull else { return }
        let padding = UIEdgeInsets(top: topInset + 40, left: 40, bottom: bottomInset + 40, right: 40)
        let flat = MKMapCamera(lookingAtCenter: mapView.camera.centerCoordinate, fromDistance: mapView.camera.centerCoordinateDistance, pitch: 0, heading: 0)
        UIView.animate(withDuration: 1.1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.mapView.setCamera(flat, animated: false)
            self.mapView.setVisibleMapRect(rect, edgePadding: padding, animated: false)
        }
    }

    // MARK: - Gestures

    @objc private func userGesture(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .began else { return }
        transition = nil
        onUserMovedMap()
    }

    @objc private func userTapped(_ recognizer: UIGestureRecognizer) {
        transition = nil
        onUserMovedMap()
    }

    @objc private func touchChanged(_ recognizer: UIGestureRecognizer) {
        isTouching = recognizer.state == .began || recognizer.state == .changed
    }

    nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    // MARK: - Rendering

    nonisolated func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        MainActor.assumeIsolated {
            if let line = overlay as? RouteLine {
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = line.color
                renderer.lineWidth = line.width
                renderer.lineCap = .round
                renderer.lineJoin = .round
                renderer.strokeStart = line.strokeStart
                renderer.strokeEnd = line.strokeEnd
                return renderer
            }
            if let area = overlay as? StationArea {
                let renderer = MKPolygonRenderer(polygon: area)
                renderer.fillColor = area.fill
                renderer.strokeColor = area.stroke
                renderer.lineWidth = 1
                return renderer
            }
            if let head = overlay as? ArrowHead {
                let renderer = MKPolygonRenderer(polygon: head)
                renderer.fillColor = head.fill
                renderer.strokeColor = head.fill
                renderer.lineWidth = head.outline
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    nonisolated func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        MainActor.assumeIsolated {
            guard let pin = annotation as? MapPin else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: HostingAnnotationView.reuseIdentifier) as? HostingAnnotationView
                ?? HostingAnnotationView(annotation: pin, reuseIdentifier: HostingAnnotationView.reuseIdentifier)
            view.annotation = pin
            view.show(pin)
            return view
        }
    }
}

// MARK: - Map objects

private final class RouteLine: MKPolyline {
    var color: UIColor = .systemBlue
    var width: CGFloat = 6
    var strokeStart: CGFloat = 0
    var strokeEnd: CGFloat = 1

    static func make(_ coordinates: [CLLocationCoordinate2D], color: UIColor, width: CGFloat) -> RouteLine {
        let line = RouteLine(coordinates: coordinates, count: coordinates.count)
        line.color = color
        line.width = width
        return line
    }
}

private final class ArrowHead: MKPolygon {
    var fill: UIColor = .white
    var outline: CGFloat = 0

    static func make(_ coordinates: [CLLocationCoordinate2D], fill: UIColor, outline: CGFloat) -> ArrowHead {
        let head = ArrowHead(coordinates: coordinates, count: coordinates.count)
        head.fill = fill
        head.outline = outline
        return head
    }
}

private final class StationArea: MKPolygon {
    var fill: UIColor = .clear
    var stroke: UIColor = .clear
}

private final class MapPin: NSObject, MKAnnotation {
    enum Kind {
        case puck, ghost, estimated, approaching, stop, destination, stationTrack, stationCurrentTrack, stationAccess, levelChange, sector

        var zPriority: MKAnnotationViewZPriority {
            switch self {
            case .puck: return .max
            case .approaching, .estimated: return MKAnnotationViewZPriority(rawValue: 700)
            case .ghost: return MKAnnotationViewZPriority(rawValue: 600)
            case .destination: return MKAnnotationViewZPriority(rawValue: 500)
            case .stop: return .defaultUnselected
            case .levelChange: return MKAnnotationViewZPriority(rawValue: 550)
            case .sector: return MKAnnotationViewZPriority(rawValue: 420)
            case .stationCurrentTrack: return MKAnnotationViewZPriority(rawValue: 450)
            case .stationTrack: return MKAnnotationViewZPriority(rawValue: 400)
            case .stationAccess: return MKAnnotationViewZPriority(rawValue: 380)
            }
        }
    }

    let kind: Kind
    @objc dynamic var coordinate: CLLocationCoordinate2D
    /// Distance from the view's top to the point on the coordinate; nil = centre, `bottom` = bottom edge.
    let anchorY: CGFloat?
    static let bottom = CGFloat.infinity
    var content = AnyView(EmptyView())
    var contentKey = ""

    init(kind: Kind, coordinate: CLLocationCoordinate2D, anchorY: CGFloat?) {
        self.kind = kind
        self.coordinate = coordinate
        self.anchorY = anchorY
    }
}

private final class HostingAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "onboard"
    private var host: UIHostingController<AnyView>?

    func show(_ pin: MapPin) {
        let host = host ?? {
            let controller = UIHostingController(rootView: AnyView(EmptyView()))
            controller.view.backgroundColor = .clear
            controller.view.isUserInteractionEnabled = false
            addSubview(controller.view)
            self.host = controller
            return controller
        }()
        host.rootView = pin.content
        let size = host.sizeThatFits(in: CGSize(width: 320, height: 320))
        frame.size = size
        host.view.frame = CGRect(origin: .zero, size: size)
        centerOffset = CGPoint(x: 0, y: pin.anchorY.map { $0 == MapPin.bottom ? -size.height / 2 : size.height / 2 - $0 } ?? 0)
        zPriority = pin.kind.zPriority
        displayPriority = .required
        collisionMode = .none
        isEnabled = false
        canShowCallout = false
    }
}

private final class TouchRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

private struct MapLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .shadow(color: Color(.systemBackground), radius: 1)
            .shadow(color: Color(.systemBackground), radius: 1)
            .lineLimit(1)
            .fixedSize()
    }
}

@MainActor
@Observable
private final class PuckModel {
    var style: NavigationPuck.Style = .walker
    var heading: CLLocationDirection?
    var pitch: Double = 0
}

private struct PuckView: View {
    let model: PuckModel

    var body: some View {
        NavigationPuck(style: model.style, heading: model.heading, pitch: model.pitch)
    }
}

// MARK: - Puck

struct NavigationPuck: View {
    enum Style: Equatable {
        case walker
        case vehicle(color: Color, textColor: Color, symbol: String)
    }

    let style: Style
    let heading: CLLocationDirection?
    let pitch: Double

    private static let walkBlue = Color(red: 0.1, green: 0.42, blue: 0.85)

    static func vehicleSymbol(for mode: TransportationMode) -> String {
        switch mode {
        case .tram: return "tram.fill"
        case .ferry: return "ferry.fill"
        case .subway, .metro: return "tram.tunnel.fill"
        case .funicular: return "cablecar.fill"
        case .bus, .coach: return "bus.fill"
        default: return mode.isRail ? "train.side.front.car" : "bus.fill"
        }
    }

    var body: some View {
        Group {
            switch style {
            case .walker:
                walker
            case let .vehicle(color, textColor, symbol):
                vehicle(color: color, textColor: textColor, symbol: symbol)
            }
        }
        .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.35)
        .animation(.spring(duration: 0.5), value: style)
        .accessibilityElement()
        .accessibilityLabel(Text("Votre position"))
    }

    private var walker: some View {
        ZStack {
            Circle()
                .fill(Self.walkBlue.opacity(0.15))
                .frame(width: 64, height: 64)
            Circle()
                .fill(.white)
                .frame(width: 42, height: 42)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            if let heading {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(Self.walkBlue.gradient)
                    .rotationEffect(.degrees(heading))
            } else {
                Circle()
                    .fill(Self.walkBlue.gradient)
                    .frame(width: 22, height: 22)
            }
        }
        .frame(width: 76, height: 76)
        .transition(.scale.combined(with: .opacity))
    }

    private func vehicle(color: Color, textColor: Color, symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 76, height: 76)
            if let heading {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                    .offset(y: -33)
                    .rotationEffect(.degrees(heading))
            }
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.gradient)
                .frame(width: 46, height: 46)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .frame(width: 76, height: 76)
        .transition(.scale.combined(with: .opacity))
    }
}

private struct TurnArrow {
    let shaft: [CLLocationCoordinate2D]
    let head: [CLLocationCoordinate2D]

    init?(path: RoutePath, along: CLLocationDistance) {
        let start = max(0, along - 14)
        let end = min(path.length, along + 11)
        guard end - along > 4,
              let shaftEnd = path.coordinate(at: end),
              let beforeEnd = path.coordinate(at: end - 4),
              beforeEnd.distance(to: shaftEnd) > 0.5 else { return nil }
        let bearing = beforeEnd.bearing(to: shaftEnd)
        shaft = path.slice(from: start, to: end)
        head = [
            shaftEnd.offset(by: 8, bearing: bearing),
            shaftEnd.offset(by: 6, bearing: bearing + 90),
            shaftEnd.offset(by: 6, bearing: bearing - 90)
        ]
        guard shaft.count >= 2 else { return nil }
    }
}

@MainActor
private final class FrameDriver {
    var onFrame: ((CFTimeInterval) -> Void)?
    private var link: CADisplayLink?

    var isRunning = false {
        didSet {
            guard isRunning != oldValue else { return }
            if isRunning {
                let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
                link.add(to: .main, forMode: .common)
                self.link = link
            } else {
                link?.invalidate()
                link = nil
            }
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        onFrame?(link.targetTimestamp)
    }
}
