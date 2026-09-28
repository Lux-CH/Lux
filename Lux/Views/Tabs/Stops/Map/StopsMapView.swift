//
//  StopsMapView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.09.2026.
//

import SwiftUI
import MapKit
import LuxCom

struct StopsMapSelection: Identifiable, Equatable {
    let stop: SearchResult
    let track: String?

    var id: String { "\(stop.id)|\(track ?? "")" }

    static func == (lhs: StopsMapSelection, rhs: StopsMapSelection) -> Bool {
        lhs.id == rhs.id
    }
}

struct MapStation: Identifiable {
    let stop: SearchResult
    let quais: [Place]
    let importance: Double

    var id: String { stop.id }

    static func load(min: (Double, Double), max: (Double, Double)) async throws -> [MapStation] {
        var order: [String] = []
        var anchors: [String: Place] = [:]
        var modes: [String: [TransportationMode]] = [:]
        var quais: [String: [Place]] = [:]
        for place in try await getMapStops(min: min, max: max) {
            guard let id = place.parentId ?? place.stopId, !id.isEmpty else { continue }
            let track = place.track ?? place.scheduledTrack
            if let track, !track.isEmpty, let stopId = place.stopId,
               !(quais[id]?.contains { $0.stopId == stopId } ?? false) {
                quais[id, default: []].append(place)
            }
            for mode in place.modes where !(modes[id]?.contains(mode) ?? false) {
                modes[id, default: []].append(mode)
            }
            if let anchor = anchors[id] {
                if track == nil, (anchor.track ?? anchor.scheduledTrack) != nil { anchors[id] = place }
            } else {
                order.append(id)
                anchors[id] = place
            }
        }
        return order.compactMap { id in
            guard let anchor = anchors[id] else { return nil }
            let stop = SearchResult(
                type: .stop,
                tokens: [[]],
                name: anchor.name,
                id: id,
                lat: anchor.lat,
                lon: anchor.lon,
                level: anchor.level,
                areas: [],
                score: 0,
                modes: modes[id] ?? [],
                groupedStopIds: [id]
            )
            return MapStation(stop: stop, quais: quais[id] ?? [], importance: anchor.importance ?? 0)
        }
    }
}

struct StopsMapPin: Equatable {
    let coordinate: CLLocationCoordinate2D
    var name: String?
    var nearby: [SearchResult] = []
    var isLoading = true

    static func == (lhs: StopsMapPin, rhs: StopsMapPin) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.name == rhs.name
            && lhs.nearby.map(\.id) == rhs.nearby.map(\.id)
            && lhs.isLoading == rhs.isLoading
    }
}

@MainActor
@Observable
final class StopsMapModel {
    var selection: StopsMapSelection?
    var presentedSelection: StopsMapSelection?
    var pin: StopsMapPin?
    var isLoading = false
    var isZoomedOut = false
    var trackingMode: MKUserTrackingMode = .none
    var focusToken = 0
    @ObservationIgnored var savedCamera: MKMapCamera?

    @ObservationIgnored private var pinTask: Task<Void, Never>?

    func select(_ stop: SearchResult, track: String? = nil) {
        let selection = StopsMapSelection(stop: stop, track: track)
        guard selection != self.selection else { return }
        self.selection = selection
        presentedSelection = selection
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    func dropPin(at coordinate: CLLocationCoordinate2D) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        selection = nil
        pin = StopsMapPin(coordinate: coordinate)
        pinTask?.cancel()
        pinTask = Task { [weak self] in
            let place = (coordinate.latitude, coordinate.longitude)
            async let names = try? LuxData.reverseGeocode(place: place)
            async let stops = try? getMapSearchResults(currentLoc: place)
            let (resolved, found) = await (names, stops)
            guard let self, !Task.isCancelled else { return }
            let pinLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let nearby = (found ?? []).sorted {
                pinLocation.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon))
                    < pinLocation.distance(from: CLLocation(latitude: $1.lat, longitude: $1.lon))
            }
            pin?.name = resolved?.first { $0.type != .stop }?.name
            pin?.nearby = Array(nearby.prefix(6))
            pin?.isLoading = false
            focusToken += 1
        }
    }

    func clearPin() {
        pinTask?.cancel()
        pin = nil
    }

    func destination(for pin: StopsMapPin) -> SearchResult {
        let name = pin.name ?? String(localized: "Repère sur la carte")
        return SearchResult(
            type: .place,
            tokens: [[0, name.count]],
            name: name,
            id: "map-pin-\(pin.coordinate.latitude),\(pin.coordinate.longitude)",
            lat: pin.coordinate.latitude,
            lon: pin.coordinate.longitude,
            areas: [],
            score: 1
        )
    }
}

struct StopsMapScreen: View {
    let initialLocation: CLLocation?
    let onGo: (SearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model = StopsMapModel()
    @State private var pinCardHeight: CGFloat = 0
    @State private var showsHint = true
    @State private var openedTrip: TripDestination?
    @State private var shouldRenderMap = true
    @State private var isOnScreen = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    if shouldRenderMap {
                        StopsMapView(
                            model: model,
                            initialLocation: initialLocation,
                            topInset: geometry.safeAreaInsets.top + 64,
                            bottomInset: bottomInset(in: geometry)
                        )
                        .ignoresSafeArea()
                    } else {
                        Color(.secondarySystemBackground)
                            .ignoresSafeArea()
                    }

                    VStack(spacing: 0) {
                        topBar
                        Spacer()
                        if let pin = model.pin, model.selection == nil {
                            pinCard(pin)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                isOnScreen = true
                shouldRenderMap = true
            }
            .onDisappear {
                isOnScreen = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if !isOnScreen { shouldRenderMap = false }
                }
            }
            .navigationDestination(item: $openedTrip) { trip in
                ItineraryView(tripId: trip.tripId, fromNearby: false, otherTripOptions: trip.otherTripOptions, defersDetails: true)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }
        }
        .animation(.snappy, value: model.pin)
        .animation(.snappy, value: model.selection)
        .animation(.snappy, value: model.isZoomedOut)
        .animation(.snappy, value: model.isLoading)
        .animation(.snappy, value: showsHint)
        .sheet(isPresented: Binding(
            get: { model.selection != nil },
            set: { if !$0 { model.selection = nil } }
        )) {
            if let selection = model.presentedSelection {
                NavigationStack {
                    StopDepartureSheet(stop: selection.stop, track: selection.track) {
                        go(selection.stop)
                    }
                    .environment(\.openTrip) { trip in
                        model.selection = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            openedTrip = trip
                        }
                    }
                        .toolbar(.hidden, for: .navigationBar)
                }
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(36)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(4))
            showsHint = false
        }
    }

    private func bottomInset(in geometry: GeometryProxy) -> CGFloat {
        if model.selection != nil { return geometry.size.height * 0.5 }
        if model.pin != nil { return pinCardHeight + 16 }
        return 0
    }

    private func go(_ destination: SearchResult) {
        model.selection = nil
        onGo(destination)
    }

    private var topBar: some View {
        ZStack(alignment: .top) {
            HStack {
                GlassEffectGroup(spacing: 8) {
                    VStack(spacing: 12) {
                        mapButton("xmark", label: String(localized: "Fermer")) {
                            dismiss()
                        }
                        mapButton(locationButtonIcon, label: String(localized: "Suivre ma position")) {
                                withAnimation {
                                cycleTrackingMode()
                            }
                        }
                    }
                }
                Spacer()
            }
            if let status {
                HStack(spacing: 8) {
                    if model.isLoading && !model.isZoomedOut {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(status)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .adaptable(ios26: .glass, fallback: {
                    $0.background(.ultraThickMaterial, in: Capsule(style: .continuous))
                })
                .shadow(radius: 2)
                .padding(.top, 2)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .liquidGlassLightModeButtonTintOptOut()
    }

    private var locationButtonIcon: String {
        switch model.trackingMode {
        case .follow: return "location.fill"
        case .followWithHeading: return "location.north.line.fill"
        default: return "location"
        }
    }

    private func cycleTrackingMode() {
        switch model.trackingMode {
        case .none: model.trackingMode = .follow
        case .follow: model.trackingMode = .followWithHeading
        default: model.trackingMode = .none
        }
    }

    private var status: String? {
        if model.isZoomedOut { return String(localized: "Zoomez pour voir les arrêts") }
        if model.isLoading { return String(localized: "Chargement…") }
        if showsHint && model.pin == nil { return String(localized: "Maintenez pour placer un repère") }
        return nil
    }

    private func mapButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundColor(.accentColor)
                .frame(width: 45, height: 45)
                .contentShape(Circle())
                .clipShape(Circle())
                .adaptable(ios26: .glassButton, fallback: {
                    $0.background(.ultraThickMaterial, in: Circle()).overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                })
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func pinCard(_ pin: StopsMapPin) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white, .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.name ?? String(localized: "Repère sur la carte"))
                        .font(.headline)
                        .lineLimit(1)
                        .redacted(reason: pin.isLoading && pin.name == nil ? .placeholder : [])
                    if let distance = distanceFromUser(to: pin.coordinate) {
                        Text("À \(formatDistance(distance)) de vous")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    model.clearPin()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary, Color(.tertiarySystemFill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retirer le repère")
            }

            if pin.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Recherche des arrêts proches…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 44)
            } else if !pin.nearby.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pin.nearby) { stop in
                            Button {
                                model.select(stop)
                            } label: {
                                nearbyChip(stop, from: pin.coordinate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 18, for: .scrollContent)
                .padding(.horizontal, -18)
            }

            Button {
                go(model.destination(for: pin))
            } label: {
                Label("Y aller", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .contentShape(Capsule(style: .continuous))
                    .adaptable(ios26: .glassButtonTintedIn(AnyShape(Capsule(style: .continuous)), .accentColor), fallback: {
                        $0.background(Color.accentColor, in: Capsule(style: .continuous))
                    })
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .adaptable(ios26: .glassIn(AnyShape(RoundedRectangle(cornerRadius: 34, style: .continuous))), fallback: {
            $0.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        })
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pinCardHeight = $0 }
    }

    private func nearbyChip(_ stop: SearchResult, from coordinate: CLLocationCoordinate2D) -> some View {
        let mode = StopsMapStyle.primaryMode(of: stop.modes)
        let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: stop.lat, longitude: stop.lon))
        return HStack(spacing: 8) {
            Image(systemName: "signpost.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color(StopsMapStyle.color(for: mode)), in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(stop.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(formatDistance(distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .frame(height: 48)
        .background(Color(.tertiarySystemFill).opacity(0.6), in: Capsule(style: .continuous))
    }

    private func distanceFromUser(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        initialLocation?.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
}

enum StopsMapStyle {
    static func primaryMode(of modes: [TransportationMode]) -> TransportationMode? {
        modes.first { $0.isMainlineRail }
            ?? modes.first { $0 == .subway || $0 == .metro }
            ?? modes.first { $0 == .tram }
            ?? modes.first { $0 == .ferry }
            ?? modes.first { $0 == .funicular }
            ?? modes.first
    }

    static func color(for mode: TransportationMode?) -> UIColor {
        guard let mode else { return .systemBlue }
        if mode.isMainlineRail { return UIColor(red: 0.92, green: 0, blue: 0, alpha: 1) }
        switch mode {
        case .subway, .metro: return .systemPurple
        case .tram: return .systemOrange
        case .ferry: return .systemCyan
        case .funicular: return .systemBrown
        default: return .systemBlue
        }
    }
}

struct StopsMapView: UIViewRepresentable {
    let model: StopsMapModel
    let initialLocation: CLLocation?
    let topInset: CGFloat
    let bottomInset: CGFloat

    func makeCoordinator() -> StopsMapController {
        StopsMapController(model: model, initialLocation: initialLocation)
    }

    func makeUIView(context: Context) -> MKMapView {
        context.coordinator.mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let controller = context.coordinator
        controller.setInsets(top: topInset, bottom: bottomInset)
        controller.sync(
            selection: model.selection,
            pin: model.pin,
            trackingMode: model.trackingMode,
            focusToken: model.focusToken
        )
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: StopsMapController) {
        coordinator.teardown()
    }
}

@MainActor
final class StopsMapController: NSObject, MKMapViewDelegate {
    let mapView = MKMapView()

    private let model: StopsMapModel
    private let initialLocation: CLLocation?

    private var stations: [String: MapStation] = [:]
    private var stationPins: [String: StationPin] = [:]
    private var quaiPins: [String: QuaiPin] = [:]
    private var droppedPin: DroppedPin?
    private var stationOverlays: [MKOverlay] = []
    private var layouts: [Int: StationLayout] = [:]
    private var requestedLayouts: Set<Int> = []
    private var loadedRects: [MKMapRect] = []
    private var loadTask: Task<Void, Never>?
    private var pendingRect: MKMapRect?
    private var layoutTasks: [Task<Void, Never>] = []
    private var detail: StationDetail = .hidden
    private var selectionId: String?
    private var selectedStop: SearchResult?
    private var selectedTrack: String?
    private var focusToken = 0
    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0
    private var isMutatingAnnotations = false

    private static let maxLoadDistance: CLLocationDistance = 9000
    private static let maxStations = 1500
    private static let switzerland = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.80, longitude: 8.23),
        span: MKCoordinateSpan(latitudeDelta: 2.6, longitudeDelta: 4.6)
    )

    init(model: StopsMapModel, initialLocation: CLLocation?) {
        self.model = model
        self.initialLocation = initialLocation
        super.init()

        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.publicTransport])
        mapView.preferredConfiguration = configuration
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.showsScale = false
        mapView.showsCompass = false
        mapView.insetsLayoutMarginsFromSafeArea = false

        if let camera = model.savedCamera {
            mapView.setCamera(camera, animated: false)
        } else if let coordinate = initialLocation?.coordinate {
            mapView.setCamera(MKMapCamera(lookingAtCenter: coordinate, fromDistance: 1800, pitch: 0, heading: 0), animated: false)
        } else {
            mapView.setRegion(Self.switzerland, animated: false)
        }

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
        longPress.minimumPressDuration = 0.35
        mapView.addGestureRecognizer(longPress)
    }

    func teardown() {
        model.savedCamera = mapView.camera.copy() as? MKMapCamera
        if model.isLoading { model.isLoading = false }
        loadTask?.cancel()
        layoutTasks.forEach { $0.cancel() }
    }

    func setInsets(top: CGFloat, bottom: CGFloat) {
        guard top != topInset || bottom != bottomInset else { return }
        topInset = top
        bottomInset = bottom
        mapView.layoutMargins = UIEdgeInsets(top: top, left: 16, bottom: bottom + 20, right: 16)
    }

    func sync(selection: StopsMapSelection?, pin: StopsMapPin?, trackingMode: MKUserTrackingMode, focusToken: Int) {
        syncPin(pin)
        syncSelection(selection)
        if trackingMode != mapView.userTrackingMode {
            mapView.setUserTrackingMode(trackingMode, animated: true)
        }
        if focusToken != self.focusToken {
            self.focusToken = focusToken
            if let pin { focus(on: pin) }
        }
    }

    private func syncPin(_ pin: StopsMapPin?) {
        guard let pin else {
            if let droppedPin {
                mapView.removeAnnotation(droppedPin)
                self.droppedPin = nil
            }
            return
        }
        if let droppedPin,
           droppedPin.coordinate.latitude == pin.coordinate.latitude,
           droppedPin.coordinate.longitude == pin.coordinate.longitude {
            if droppedPin.title != pin.name { droppedPin.title = pin.name }
            return
        }
        if let droppedPin { mapView.removeAnnotation(droppedPin) }
        let annotation = DroppedPin()
        annotation.coordinate = pin.coordinate
        annotation.title = pin.name
        droppedPin = annotation
        mapView.addAnnotation(annotation)
    }

    private func syncSelection(_ selection: StopsMapSelection?) {
        guard selection?.id != selectionId else { return }
        selectionId = selection?.id
        selectedStop = selection?.stop
        selectedTrack = selection?.track

        isMutatingAnnotations = true
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: true)
        }
        isMutatingAnnotations = false

        rebuildQuais()
        guard let selection else { return }
        selectCurrentAnnotation()
        reveal(CLLocationCoordinate2D(latitude: selection.stop.lat, longitude: selection.stop.lon))
    }

    private func selectCurrentAnnotation() {
        guard let selectedStop, let annotation = annotation(for: selectedStop.id, track: selectedTrack) else { return }
        guard !mapView.selectedAnnotations.contains(where: { $0 === annotation }) else { return }
        isMutatingAnnotations = true
        mapView.selectAnnotation(annotation, animated: true)
        isMutatingAnnotations = false
    }

    private func annotation(for stopId: String, track: String?) -> MKAnnotation? {
        if let track {
            return quaiPins[QuaiPin.key(stationId: stopId, track: track)]
        }
        return stationPins[stopId]
    }

    private func reveal(_ coordinate: CLLocationCoordinate2D) {
        let bounds = mapView.bounds
        guard bounds.height > 0 else { return }
        let point = mapView.convert(coordinate, toPointTo: mapView)
        let top = topInset + 40
        let bottom = bounds.height * 0.5 - 40
        guard bottom > top else { return }
        let target = CGPoint(x: bounds.midX, y: top + (bottom - top) * 0.8)
        let center = mapView.convert(
            CGPoint(x: bounds.midX + point.x - target.x, y: bounds.midY + point.y - target.y),
            toCoordinateFrom: mapView
        )
        mapView.setCenter(center, animated: true)
    }

    private func focus(on pin: StopsMapPin) {
        let bounds = mapView.bounds
        guard bounds.height > 0 else { return }
        let point = mapView.convert(pin.coordinate, toPointTo: mapView)
        let top = topInset + 40
        let bottom = bounds.height - bottomInset - 60
        guard bottom > top, point.y < top || point.y > bottom else { return }
        let target = CGPoint(x: point.x, y: (top + bottom) / 2)
        let center = mapView.convert(
            CGPoint(x: bounds.midX, y: bounds.midY + point.y - target.y),
            toCoordinateFrom: mapView
        )
        mapView.setCenter(center, animated: true)
    }

    @objc private func longPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let coordinate = mapView.convert(recognizer.location(in: mapView), toCoordinateFrom: mapView)
        model.dropPin(at: coordinate)
    }

    private func scheduleLoad() {
        let zoomedOut = mapView.camera.centerCoordinateDistance > Self.maxLoadDistance
        if model.isZoomedOut != zoomedOut { model.isZoomedOut = zoomedOut }
        guard !zoomedOut else {
            loadTask?.cancel()
            pendingRect = nil
            if model.isLoading { model.isLoading = false }
            return
        }
        loadLayouts()

        let visible = mapView.visibleMapRect
        guard !loadedRects.contains(where: { $0.contains(visible) }) else { return }
        if let pendingRect, pendingRect.contains(visible) { return }
        let rect = visible.insetBy(dx: -visible.width * 0.25, dy: -visible.height * 0.25)

        loadTask?.cancel()
        pendingRect = rect
        loadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else { return }
            self.model.isLoading = true
            let bounds = Self.bounds(of: rect)
            let result = try? await MapStation.load(min: bounds.min, max: bounds.max)
            guard !Task.isCancelled else { return }
            self.model.isLoading = false
            self.pendingRect = nil
            guard let result else { return }
            self.loadedRects.append(rect)
            if self.loadedRects.count > 40 { self.loadedRects.removeFirst() }
            self.apply(result)
        }
    }

    private static func bounds(of rect: MKMapRect) -> (min: (Double, Double), max: (Double, Double)) {
        let northWest = MKMapPoint(x: rect.minX, y: rect.minY).coordinate
        let southEast = MKMapPoint(x: rect.maxX, y: rect.maxY).coordinate
        return ((southEast.latitude, northWest.longitude), (northWest.latitude, southEast.longitude))
    }

    private func apply(_ result: [MapStation]) {
        for station in result {
            stations[station.id] = station
        }
        if stations.count > Self.maxStations {
            let center = MKMapPoint(mapView.centerCoordinate)
            let ranked = stations.values.sorted {
                MKMapPoint(CLLocationCoordinate2D(latitude: $0.stop.lat, longitude: $0.stop.lon)).distance(to: center)
                    < MKMapPoint(CLLocationCoordinate2D(latitude: $1.stop.lat, longitude: $1.stop.lon)).distance(to: center)
            }
            stations = Dictionary(uniqueKeysWithValues: ranked.prefix(Self.maxStations).map { ($0.id, $0) })
            loadedRects = []
        }
        rebuildStations()
        rebuildQuais()
        loadLayouts()
    }

    private func rebuildStations() {
        isMutatingAnnotations = true
        defer { isMutatingAnnotations = false }

        let stale = stationPins.filter { stations[$0.key] == nil }
        mapView.removeAnnotations(Array(stale.values))
        for key in stale.keys { stationPins[key] = nil }

        var added: [StationPin] = []
        for (id, station) in stations where stationPins[id] == nil {
            let pin = StationPin(station: station)
            stationPins[id] = pin
            added.append(pin)
        }
        mapView.addAnnotations(added)
        if selectedTrack == nil { selectCurrentAnnotation() }
    }

    private func rebuildQuais() {
        isMutatingAnnotations = true
        defer { isMutatingAnnotations = false }

        var desired: [String: QuaiPin] = [:]
        let content = StationOverlayContent(legs: [], layouts: layouts)
        var railStations: [Int: MapStation] = [:]
        for station in stations.values where station.stop.servesMainlineRail {
            if let uic = StationLayout.uic(fromStopId: station.id), layouts[uic] != nil {
                railStations[uic] = station
            }
        }

        func add(station: MapStation, track: String, coordinate: CLLocationCoordinate2D, isRail: Bool) {
            let key = QuaiPin.key(stationId: station.id, track: track)
            let isSelected = station.id == selectedStop?.id && track == selectedTrack
            guard detail >= .allLabels || isSelected, desired[key] == nil else { return }
            desired[key] = quaiPins[key] ?? QuaiPin(key: key, stop: station.stop, track: track, isRail: isRail, coordinate: coordinate)
        }

        for label in content.labels {
            guard let uic = Int(label.id.prefix { $0.isNumber }), let station = railStations[uic] else { continue }
            add(station: station, track: label.text, coordinate: label.coordinate, isRail: true)
        }
        for station in stations.values {
            let hasLayout = StationLayout.uic(fromStopId: station.id).map { railStations[$0] != nil } ?? false
            for quai in station.quais {
                guard let track = quai.track ?? quai.scheduledTrack else { continue }
                let isRail = quai.modes.contains { $0.isMainlineRail }
                if isRail && hasLayout { continue }
                add(
                    station: station,
                    track: StationLayout.normalizedTrack(track),
                    coordinate: CLLocationCoordinate2D(latitude: quai.lat, longitude: quai.lon),
                    isRail: isRail
                )
            }
        }

        let stale = quaiPins.filter { desired[$0.key] == nil }
        mapView.removeAnnotations(Array(stale.values))
        let added = desired.filter { quaiPins[$0.key] == nil }
        quaiPins = desired
        mapView.addAnnotations(Array(added.values))
        if selectedTrack != nil { selectCurrentAnnotation() }
    }

    private func loadLayouts() {
        guard detail >= .tracks else { return }
        let visible = mapView.visibleMapRect
        let area = visible.insetBy(dx: -visible.width * 0.5, dy: -visible.height * 0.5)
        for station in stations.values where station.stop.servesMainlineRail {
            guard let uic = StationLayout.uic(fromStopId: station.id), !requestedLayouts.contains(uic) else { continue }
            guard area.contains(MKMapPoint(CLLocationCoordinate2D(latitude: station.stop.lat, longitude: station.stop.lon))) else { continue }
            requestedLayouts.insert(uic)
            let stopId = station.id
            layoutTasks.append(Task { [weak self] in
                guard let layout = await StationLayoutStore.shared.layout(for: stopId), let self, !Task.isCancelled else { return }
                self.layouts[layout.uic] = layout
                self.rebuildStationShapes()
                self.rebuildQuais()
            })
        }
    }

    private func rebuildStationShapes() {
        mapView.removeOverlays(stationOverlays)
        stationOverlays = StationOverlayContent(legs: [], layouts: layouts).mapOverlays(at: detail)
        mapView.addOverlays(stationOverlays, level: .aboveRoads)
    }

    private func updateDetail() {
        let next = StationDetail(cameraDistance: mapView.camera.centerCoordinateDistance)
        guard next != detail else { return }
        let previous = detail
        detail = next
        let shapesChanged = (previous >= .tracks) != (next >= .tracks) || (previous >= .allLabels) != (next >= .allLabels)
        if shapesChanged { rebuildStationShapes() }
        if (previous >= .allLabels) != (next >= .allLabels) { rebuildQuais() }
        loadLayouts()
    }

    nonisolated func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        MainActor.assumeIsolated {
            if model.trackingMode != mode { model.trackingMode = mode }
        }
    }

    nonisolated func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        MainActor.assumeIsolated { updateDetail() }
    }

    nonisolated func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        MainActor.assumeIsolated {
            updateDetail()
            scheduleLoad()
        }
    }

    nonisolated func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        MainActor.assumeIsolated {
            updateDetail()
            scheduleLoad()
        }
    }

    nonisolated func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        MainActor.assumeIsolated {
            guard !isMutatingAnnotations, let annotation = view.annotation else { return }
            if annotation is StationPin || annotation is QuaiPin {
                choose(annotation)
            } else {
                mapView.deselectAnnotation(annotation, animated: false)
            }
        }
    }

    fileprivate func tapped(_ view: MKAnnotationView) {
        guard let annotation = view.annotation else { return }
        choose(annotation)
        guard !mapView.selectedAnnotations.contains(where: { $0 === annotation }) else { return }
        isMutatingAnnotations = true
        mapView.selectAnnotation(annotation, animated: true)
        isMutatingAnnotations = false
    }

    private func choose(_ annotation: MKAnnotation) {
        let selection: StopsMapSelection
        switch annotation {
        case let pin as StationPin:
            selection = StopsMapSelection(stop: pin.station.stop, track: nil)
        case let pin as QuaiPin:
            selection = StopsMapSelection(stop: pin.stop, track: pin.track)
        default:
            return
        }
        guard selection.id != selectionId else { return }
        selectionId = selection.id
        selectedStop = selection.stop
        selectedTrack = selection.track
        model.select(selection.stop, track: selection.track)
        reveal(annotation.coordinate)
    }

    nonisolated func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        MainActor.assumeIsolated {
            guard !isMutatingAnnotations, view.annotation is StationPin || view.annotation is QuaiPin else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let stillSelected = self.mapView.selectedAnnotations.contains { $0 is StationPin || $0 is QuaiPin }
                guard !stillSelected, self.model.selection != nil else { return }
                self.selectionId = nil
                self.selectedStop = nil
                self.selectedTrack = nil
                self.model.selection = nil
                self.rebuildQuais()
            }
        }
    }

    nonisolated func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        MainActor.assumeIsolated {
            if let line = overlay as? RouteLine {
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = line.color
                renderer.lineWidth = line.width
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            if let area = overlay as? StationArea {
                let renderer = MKPolygonRenderer(polygon: area)
                renderer.fillColor = area.fill
                renderer.strokeColor = area.stroke
                renderer.lineWidth = 1
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    nonisolated func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        MainActor.assumeIsolated {
            switch annotation {
            case let pin as StationPin:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: StationMarkerView.reuseIdentifier) as? StationMarkerView
                    ?? StationMarkerView(annotation: pin, reuseIdentifier: StationMarkerView.reuseIdentifier)
                view.annotation = pin
                view.configure(with: pin.station)
                view.onTap = { [weak self] view in self?.tapped(view) }
                return view
            case let pin as QuaiPin:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: QuaiAnnotationView.reuseIdentifier) as? QuaiAnnotationView
                    ?? QuaiAnnotationView(annotation: pin, reuseIdentifier: QuaiAnnotationView.reuseIdentifier)
                view.annotation = pin
                view.configure(with: pin)
                view.onTap = { [weak self] view in self?.tapped(view) }
                return view
            case let pin as DroppedPin:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "dropped") as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: pin, reuseIdentifier: "dropped")
                view.annotation = pin
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "mappin")
                view.displayPriority = .required
                view.zPriority = .max
                view.animatesWhenAdded = true
                view.canShowCallout = false
                view.titleVisibility = .visible
                return view
            default:
                return nil
            }
        }
    }
}

private final class StationPin: NSObject, MKAnnotation {
    let station: MapStation
    let coordinate: CLLocationCoordinate2D

    init(station: MapStation) {
        self.station = station
        coordinate = CLLocationCoordinate2D(latitude: station.stop.lat, longitude: station.stop.lon)
    }

    var title: String? { station.stop.name }
}

private final class QuaiPin: NSObject, MKAnnotation {
    let key: String
    let stop: SearchResult
    let track: String
    let isRail: Bool
    let coordinate: CLLocationCoordinate2D

    init(key: String, stop: SearchResult, track: String, isRail: Bool, coordinate: CLLocationCoordinate2D) {
        self.key = key
        self.stop = stop
        self.track = track
        self.isRail = isRail
        self.coordinate = coordinate
    }

    var title: String? { getTrackType(track) }

    static func key(stationId: String, track: String) -> String {
        "\(stationId)|\(track)"
    }
}

private final class DroppedPin: MKPointAnnotation {}

private final class StationMarkerView: MKMarkerAnnotationView {
    static let reuseIdentifier = "station"

    var onTap: ((MKAnnotationView) -> Void)?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func handleTap() {
        onTap?(self)
    }

    func configure(with station: MapStation) {
        let mode = StopsMapStyle.primaryMode(of: station.stop.modes)
        markerTintColor = StopsMapStyle.color(for: mode)
        glyphImage = UIImage(systemName: "signpost.right")
        displayPriority = MKFeatureDisplayPriority(rawValue: Float(500 + 499 * min(1, station.importance * 3)))
        titleVisibility = .adaptive
        subtitleVisibility = .hidden
        canShowCallout = false
        animatesWhenAdded = true
        accessibilityLabel = station.stop.name
    }
}

private final class QuaiAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "quai"
    private var host: UIHostingController<QuaiSignView>?
    private var sign = QuaiSignView(text: "", isRail: false, isSelected: false)

    var onTap: ((MKAnnotationView) -> Void)?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func handleTap() {
        onTap?(self)
    }

    func configure(with pin: QuaiPin) {
        sign = QuaiSignView(text: pin.track, isRail: pin.isRail, isSelected: isSelected)
        render()
        displayPriority = .required
        collisionMode = .circle
        zPriority = MKAnnotationViewZPriority(rawValue: 300)
        canShowCallout = false
        accessibilityLabel = "\(pin.stop.name), \(getTrackType(pin.track))"
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        sign = QuaiSignView(text: sign.text, isRail: sign.isRail, isSelected: selected)
        zPriority = selected ? .max : MKAnnotationViewZPriority(rawValue: 300)
        render()
    }

    private func render() {
        let host = host ?? {
            let controller = UIHostingController(rootView: sign)
            controller.view.backgroundColor = .clear
            controller.view.isUserInteractionEnabled = false
            addSubview(controller.view)
            self.host = controller
            return controller
        }()
        host.rootView = sign
        let size = host.sizeThatFits(in: CGSize(width: 200, height: 200))
        frame.size = size
        host.view.frame = CGRect(origin: .zero, size: size)
    }
}

private struct QuaiSignView: View {
    let text: String
    let isRail: Bool
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(.system(size: isSelected ? 14 : 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, isSelected ? 5 : 3)
            .frame(minWidth: isSelected ? 24 : 17, minHeight: isSelected ? 24 : 17)
            .background(
                RoundedRectangle(cornerRadius: isSelected ? 5 : 3, style: .continuous)
                    .fill(isRail ? StationStyle.signBlue : Color(white: 0.28))
            )
            .padding(isSelected ? 2 : 1)
            .background(
                RoundedRectangle(cornerRadius: isSelected ? 7 : 4, style: .continuous)
                    .fill(isSelected ? Color.accentColor : .white)
            )
            .shadow(color: .black.opacity(0.25), radius: isSelected ? 3 : 1.5, y: 1)
            .padding(8)
            .fixedSize()
            .environment(\.colorScheme, .light)
    }
}
