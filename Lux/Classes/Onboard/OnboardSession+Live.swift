//
//  OnboardSession+Live.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import MapKit
import LuxCom
import Polyline

extension OnboardSession {
    func startLiveFeeds() {
        liveFeeds.values.forEach { $0.stop() }
        liveFeeds.removeAll()
        vehicleTasks.values.forEach { $0.cancel() }
        vehicleTasks.removeAll()
        liveVehicles.removeAll()
        liveTracks.removeAll()
        tripKeyFrames.removeAll()
        for index in legs.indices {
            startLiveFeed(for: index)
        }
    }

    func startLiveFeed(for index: Int) {
        tripKeyFrames[index] = nil
        tripLegs[index] = nil
        liveTracks[index] = nil
        liveFeeds[index]?.stop()
        vehicleTasks[index]?.cancel()
        let leg = legs[index]
        guard leg.isTransit, let tripId = leg.tripId, !tripId.isEmpty else { return }
        announcedDelays[index] = leg.departureDelayMinutes
        let feed = RelayLiveFeed<Itinerary>()
        feed.start(
            fallbackOnly: OfflineRouter.shared.isOfflineActive,
            fallbackInterval: .seconds(15),
            stream: { await RelayClient.shared.trip(tripId: tripId) },
            fallbackFetch: { try? await LuxData.trip(tripId: tripId) },
            onUpdate: { [weak self] trip in self?.apply(trip, toLeg: index) }
        )
        liveFeeds[index] = feed

        vehicleTasks[index] = Task { [weak self] in
            for await vehicle in await RelayClient.shared.vehicle(tripId: tripId) {
                guard let self, !Task.isCancelled else { return }
                self.liveVehicles[index] = vehicle
                self.trackVehicle(vehicle, forLeg: index)
                self.updateApproachingVehicle()
            }
        }
    }

    func retargetCurrentLeg(to tripId: String) {
        let index = legIndex
        guard !retargetedLegs.contains(index), legs.indices.contains(index), legs[index].tripId != tripId else { return }
        retargetedLegs.insert(index)
        Task { [weak self] in
            guard let trip = try? await LuxData.trip(tripId: tripId), let self, self.legIndex == index,
                  let corrected = LegLiveMerger.merge(self.legs[index], with: trip, retargetingTo: tripId) else { return }
            let earlier = corrected.scheduledStartTime < self.legs[index].scheduledStartTime
            self.legs[index] = corrected
            self.scheduleOffset = nil
            self.positionDelay = nil
            self.crowdStatus = nil
            self.startLiveFeed(for: index)
            self.showAlert(
                OnboardAlert(
                    severity: .info,
                    symbolName: "arrow.triangle.2.circlepath",
                    title: earlier ? String(localized: "Vous êtes dans le véhicule précédent") : String(localized: "Vous êtes dans le véhicule suivant"),
                    message: String(localized: "Horaires mis à jour : arrivée à \(self.placeName(corrected.to)) à \(formatTime(corrected.endTime))")
                ),
                spoken: nil,
                urgency: .notice
            )
            self.evaluate()
            if earlier, self.phase == .riding {
                self.lookForFasterConnection()
            }
        }
    }

    func updateApproachingVehicle() {
        guard phase == .walking || phase == .waiting, let (index, _) = nextTransitLeg,
              let vehicle = liveVehicles[index], vehicle.isFresh else {
            if approachingVehicle != nil { approachingVehicle = nil }
            return
        }
        assign(\.approachingVehicle, vehicle)
    }

    var approachingVehicleDistance: CLLocationDistance? {
        guard let vehicle = approachingVehicleCoordinate(at: Date()), let leg = nextTransitLeg?.leg else { return nil }
        return CLLocation(latitude: leg.from.lat, longitude: leg.from.lon)
            .distance(from: CLLocation(latitude: vehicle.latitude, longitude: vehicle.longitude))
    }

    func trackVehicle(_ vehicle: RelayClient.CrowdVehicle?, forLeg index: Int) {
        guard let vehicle else {
            liveTracks[index] = nil
            return
        }
        let now = Date()
        if var track = liveTracks[index] {
            track.update(with: vehicle, at: now)
            liveTracks[index] = track
        } else if let trip = tripPaths[index] {
            liveTracks[index] = LiveVehicleTrack(path: trip.path, vehicle: vehicle, receivedAt: now)
        }
    }

    func approachingVehicleCoordinate(at date: Date) -> CLLocationCoordinate2D? {
        guard let vehicle = approachingVehicle else { return nil }
        guard let (index, _) = nextTransitLeg, let track = liveTracks[index] else { return vehicle.coordinate }
        return track.coordinate(at: date, limit: tripPaths[index]?.boardAlong) ?? vehicle.coordinate
    }

    func scheduledWalkerAlong(at date: Date) -> CLLocationDistance? {
        guard phase == .walking, let leg = currentLeg, let path = currentPath, leg.duration > 0 else { return nil }
        let nextDeparture = legIndex + 1 < legs.count && legs[legIndex + 1].isTransit ? legs[legIndex + 1].startTime : nil
        let end = nextDeparture.map { min($0, leg.endTime) } ?? leg.endTime
        let start = end.addingTimeInterval(-Double(leg.duration))
        let fraction = max(0, min(1, date.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))))
        return fraction * path.length
    }

    func scheduledWalkerCoordinate(at date: Date) -> CLLocationCoordinate2D? {
        scheduledWalkerAlong(at: date).flatMap { currentPath?.coordinate(at: $0) }
    }

    func remainingApproach(at date: Date) -> (index: Int, coordinates: [CLLocationCoordinate2D])? {
        guard phase == .walking || phase == .waiting, let (index, _) = nextTransitLeg, let trip = tripPaths[index] else { return nil }
        let vehicle = approachingVehicleCoordinate(at: date) ?? estimatedVehicleCoordinate(at: date)
        guard let vehicle, let projection = trip.path.project(vehicle, hint: trip.boardAlong),
              projection.along < trip.boardAlong - 10 else { return nil }
        let coordinates = trip.path.slice(from: projection.along, to: trip.boardAlong)
        return coordinates.count >= 2 ? (index, coordinates) : nil
    }

    func estimatedVehicleCoordinate(at date: Date) -> CLLocationCoordinate2D? {
        guard phase == .walking || phase == .waiting, approachingVehicle == nil, let (index, _) = nextTransitLeg,
              let frames = tripKeyFrames[index]?.frames,
              let position = VehicleVisualisation.interpolatePosition(at: date.timeIntervalSince1970, using: frames) else { return nil }
        guard let trip = tripPaths[index], let projection = trip.path.project(position, hint: trip.boardAlong) else { return position }
        return projection.along < trip.boardAlong - 10 ? position : nil
    }

    func updateEstimates() {
        let showsWalker = userLocation != nil && scheduledWalkerAlong(at: now).map { abs($0 - alongInLeg) > 15 } == true
        if showsWalker != isBehindOrAheadOfSchedule { isBehindOrAheadOfSchedule = showsWalker }
        let hasEstimate = estimatedVehicleCoordinate(at: now) != nil
        if hasEstimate != hasEstimatedVehicle { hasEstimatedVehicle = hasEstimate }
    }

    func apply(_ trip: Itinerary, toLeg index: Int) {
        if let tripLeg = trip.legs.first(where: { $0.tripId != nil }) ?? trip.legs.first,
           Date().timeIntervalSince(tripKeyFrames[index]?.at ?? .distantPast) > 20 {
            tripKeyFrames[index] = (VehicleVisualisation.calculateKeyFrames(for: tripLeg, polylineString: tripLeg.legGeometry.points, precision: 1e6), Date())
            tripLegs[index] = tripLeg
            if legs.indices.contains(index) {
                let tripPath = RoutePath(encoded: tripLeg.legGeometry.points, precision: 1e6)
                let board = legs[index].from
                if let projection = tripPath.project(CLLocationCoordinate2D(latitude: board.lat, longitude: board.lon)) {
                    tripPaths[index] = (tripPath, projection.along)
                }
            }
        }
        guard isRunning, legs.indices.contains(index), let merged = LegLiveMerger.merge(legs[index], with: trip) else { return }
        let previous = legs[index]
        legs[index] = merged
        if merged.from.track != previous.from.track || merged.to.track != previous.to.track {
            // the walks to and from this train now lead to another track
            let rebuilt = Self.buildManeuvers(legs: legs, paths: paths, stations: stationLayouts)
            for walk in [index - 1, index + 1] where maneuvers.indices.contains(walk) && !reroutedWalks.contains(walk) {
                maneuvers[walk] = rebuilt[walk]
            }
        }

        guard index >= legIndex else { return }
        checkCancellation(of: merged, at: index)
        checkDelay(of: merged, at: index)
        checkTrackChange(from: previous, to: merged, at: index)
        evaluate()
    }

    /// A train leaving from (or arriving on) another track than announced: the rider may
    /// be waiting on the wrong platform, so this is loud. The station map, the "VOIE"
    /// callout and the walk instructions follow on their own.
    func checkTrackChange(from previous: Leg, to leg: Leg, at index: Int) {
        func track(_ place: Place) -> String? {
            let track = (place.track ?? place.scheduledTrack)?.trimmingCharacters(in: .whitespaces)
            return track?.isEmpty == false ? track : nil
        }
        let name = leg.spokenLineName.capitalizedFirstLetter
        let boarded = index == legIndex && phase == .riding

        if !boarded, leg.startTime > now,
           let old = track(previous.from), let new = track(leg.from), old != new {
            HapticFeedback.notification(type: .warning)
            let title = String(localized: "Changement de voie")
            let message = String(localized: "\(name) part de \(StationWalk.trackPhrase(new)) au lieu de \(StationWalk.trackPhrase(old))")
            showAlert(
                OnboardAlert(severity: .critical, symbolName: "exclamationmark.arrow.triangle.2.circlepath", title: title, message: message),
                spoken: "\(title). \(message).",
                urgency: .critical,
                persistent: true
            )
        } else if leg.endTime > now, index + 1 < legs.count,
                  let old = track(previous.to), let new = track(leg.to), old != new {
            // only worth saying when the rider then walks on from that platform
            let title = String(localized: "Arrivée sur une autre voie")
            let message = String(localized: "\(name) arrive sur \(StationWalk.trackPhrase(new)) au lieu de \(StationWalk.trackPhrase(old))")
            showAlert(
                OnboardAlert(severity: .warning, symbolName: "arrow.triangle.swap", title: title, message: message),
                spoken: "\(title). \(message).",
                urgency: .notice
            )
        }
    }

    func checkCancellation(of leg: Leg, at index: Int) {
        guard leg.cancelled, !announcedCancellations.contains(index) else { return }
        announcedCancellations.insert(index)
        showAlert(
            OnboardAlert(
                severity: .critical,
                symbolName: "xmark.octagon.fill",
                title: String(localized: "\(leg.spokenLineName.capitalizedFirstLetter) est supprimé"),
                message: String(localized: "Cherchez un autre itinéraire depuis l'onglet Trajets.")
            ),
            spoken: String(localized: "Attention, \(leg.spokenLineName) est supprimé."),
            urgency: .critical,
            persistent: true
        )
        requestReplan(.cancelled)
    }

    func checkDelay(of leg: Leg, at index: Int) {
        let boarded = index == legIndex && phase == .riding
        let delay = boarded ? currentLegDelayMinutes : leg.departureDelayMinutes
        let previous = announcedDelays[index] ?? 0
        guard abs(delay - previous) >= 2 || (delay <= 0 && previous >= 2) else { return }
        announcedDelays[index] = delay

        let name = leg.spokenLineName.capitalizedFirstLetter
        let title: String
        let severity: OnboardAlert.Severity
        if delay >= 2 {
            title = String(localized: "\(name) a \(delay) min de retard")
            severity = .warning
        } else if delay <= -2 {
            title = String(localized: "\(name) a \(-delay) min d'avance")
            severity = .warning
        } else {
            title = String(localized: "\(name) est de nouveau à l'heure")
            severity = .success
        }
        let message = boarded
            ? String(localized: "Arrivée à \(placeName(leg.to)) à \(formatTime(currentLegArrival))")
            : String(localized: "Départ de \(placeName(leg.from)) à \(formatTime(leg.startTime))")
        showAlert(
            OnboardAlert(severity: severity, symbolName: delay >= 2 ? "clock.badge.exclamationmark.fill" : "clock.fill", title: title, message: message),
            spoken: boarded ? "\(title). \(message)." : "\(title). \(spokenDeparture(from: leg.from, at: leg.startTime))",
            urgency: .notice
        )
    }

    struct AlightWatch {
        let legIndex: Int
        let leg: Leg
        let since: Date
        var onBoardSince: Date?
    }

    func checkStillOnBoard() {
        guard var watch = alightWatch else { return }
        guard now.timeIntervalSince(watch.since) < 180, phase != .riding,
              let trip = tripPaths[watch.legIndex] else {
            alightWatch = nil
            return
        }
        let alight = CLLocationCoordinate2D(latitude: watch.leg.to.lat, longitude: watch.leg.to.lon)
        guard let location = usableLocation, location.horizontalAccuracy <= 30,
              let alightOnTrip = trip.path.project(alight, hint: trip.boardAlong),
              let projection = trip.path.project(location.coordinate, hint: alightOnTrip.along) else {
            watch.onBoardSince = nil
            alightWatch = watch
            return
        }
        let vehicleSpeed: CLLocationSpeed = watch.leg.mode.isMainlineRail ? 6 : 4
        let onBoard = projection.offset < 25
            && projection.along > alightOnTrip.along + 15
            && location.speed > vehicleSpeed
        if !onBoard {
            watch.onBoardSince = nil
        } else if watch.onBoardSince == nil {
            watch.onBoardSince = now
        } else if let since = watch.onBoardSince, now.timeIntervalSince(since) >= 7.5 {
            alightWatch = nil
            resumeRide(watch, at: projection.along - alightOnTrip.along)
            return
        }
        alightWatch = watch
    }

    private func resumeRide(_ watch: AlightWatch, at pastAlight: CLLocationDistance) {
        let index = watch.legIndex
        guard legs.indices.contains(index), let tripLeg = tripLegs[index] else { return }
        let stops = tripLeg.allStops
        func position(of place: Place, after lower: Int) -> Int? {
            stops.indices.first { candidate in
                candidate > lower && (place.stopId.map { stops[candidate].stopId == $0 } ?? (stops[candidate].name == place.name))
            }
        }
        guard let boardIndex = position(of: watch.leg.from, after: -1),
              let alightIndex = position(of: watch.leg.to, after: boardIndex),
              alightIndex + 1 < stops.count,
              let extended = LegLiveMerger.slice(tripLeg, boardIndex: boardIndex, alightIndex: alightIndex + 1) else { return }

        let isNewFinalStopDestination = index == legs.count - 1 && watch.leg.to.vertexType == .transit
        let hasWalkBackAfter = walkBackLegIndex == index + 1

        arrivalTask?.cancel()
        legs[index] = extended
        let (path, alongs) = Self.buildPath(for: extended)
        paths[index] = path
        stopAlongs[index] = alongs
        announcedStopAlerts = announcedStopAlerts.filter { !$0.hasPrefix("\(index)-") }
        if isNewFinalStopDestination {
            appendWalkBack(to: watch.leg.to, from: extended.to, after: extended.endTime)
        } else if hasWalkBackAfter {
            updateWalkBack(at: index + 1, from: extended.to, after: extended.endTime)
        }
        enterLeg(index, announce: false)
        board(announce: false, verifiable: false)
        let alightAlong = alongs.count >= 2 ? alongs[alongs.count - 2] : 0
        alongInLeg = min(path.length, alightAlong + max(0, pastAlight))
        announcedStopAlerts.insert("\(index)-next")
        announcedStopAlerts.insert("\(index)-two")
        let next = placeName(extended.to)
        showAlert(
            OnboardAlert(
                severity: .critical,
                symbolName: "exclamationmark.octagon.fill",
                title: String(localized: "Vous avez dépassé votre arrêt"),
                message: String(localized: "Descendez au prochain arrêt, \(next).")
            ),
            spoken: String(localized: "Vous avez dépassé votre arrêt. Descendez au prochain arrêt, \(next)."),
            urgency: .critical
        )
        evaluate()
    }

    private func appendWalkBack(to destination: Place, from start: Place, after date: Date) {
        let walk = Self.straightWalk(from: start, to: destination, after: date, walkingSpeed: walkingSpeed)
        let index = legs.count
        legs.append(walk)
        let (path, _) = Self.buildPath(for: walk)
        paths.append(path)
        stopAlongs.append([])
        maneuvers.append(WalkManeuverBuilder.maneuvers(for: [StepInstruction](), on: path))
        walkBackLegIndex = index
        fetchWalkBackRoute(at: index, from: start, to: destination)
    }

    private func updateWalkBack(at index: Int, from start: Place, after date: Date) {
        guard legs.indices.contains(index) else { return }
        let destination = legs[index].to
        legs[index] = Self.straightWalk(from: start, to: destination, after: date, walkingSpeed: walkingSpeed)
        let (path, _) = Self.buildPath(for: legs[index])
        paths[index] = path
        stopAlongs[index] = []
        maneuvers[index] = WalkManeuverBuilder.maneuvers(for: [StepInstruction](), on: path)
        fetchWalkBackRoute(at: index, from: start, to: destination)
    }

    private static func straightWalk(from start: Place, to destination: Place, after date: Date, walkingSpeed: CLLocationSpeed) -> Leg {
        let distance = CLLocationCoordinate2D(latitude: start.lat, longitude: start.lon)
            .distance(to: CLLocationCoordinate2D(latitude: destination.lat, longitude: destination.lon))
        let duration = max(60, Int(distance / walkingSpeed))
        let end = date.addingTimeInterval(Double(duration))
        let to = Place(
            name: "END", stopId: nil, parentId: nil, lat: destination.lat, lon: destination.lon, level: destination.level,
            arrival: end, departure: nil, scheduledArrival: end, scheduledDeparture: nil,
            scheduledTrack: nil, track: nil, vertexType: .normal
        )
        return Leg(
            mode: .walk, from: start, to: to, duration: duration, startTime: date, endTime: end,
            scheduledStartTime: date, scheduledEndTime: end, realTime: false, cancelled: false,
            distance: distance, headsign: nil, routeShortName: nil, intermediateStops: nil,
            legGeometry: LegGeometry(points: "", length: 0), agencyId: nil, tripId: nil, steps: nil
        )
    }

    private func fetchWalkBackRoute(at index: Int, from start: Place, to destination: Place) {
        walkBackRouteTask?.cancel()
        walkBackRouteTask = Task { [weak self] in
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: start.lat, longitude: start.lon)))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: destination.lat, longitude: destination.lon)))
            request.transportType = .walking
            guard let route = try? await MKDirections(request: request).calculate().routes.first,
                  !Task.isCancelled, let self, self.walkBackLegIndex == index, self.legs.indices.contains(index),
                  !self.legs[index].isTransit else { return }

            let points = route.polyline.points()
            let coordinates = (0..<route.polyline.pointCount).map { points[$0].coordinate }
            let path = RoutePath(coordinates: coordinates)
            guard !path.isEmpty else { return }
            self.paths[index] = path
            self.maneuvers[index] = WalkManeuverBuilder.maneuvers(for: [StepInstruction](), on: path)
            self.reroutedWalks.insert(index)
            let current = self.legs[index]
            let end = current.startTime.addingTimeInterval(route.expectedTravelTime)
            let to = Place(
                name: current.to.name, stopId: current.to.stopId, parentId: current.to.parentId,
                lat: current.to.lat, lon: current.to.lon, level: current.to.level,
                arrival: end, departure: nil, scheduledArrival: end, scheduledDeparture: nil,
                scheduledTrack: nil, track: nil, vertexType: current.to.vertexType
            )
            self.legs[index] = Leg(
                mode: current.mode, from: current.from, to: to, duration: Int(route.expectedTravelTime),
                startTime: current.startTime, endTime: end, scheduledStartTime: current.scheduledStartTime,
                scheduledEndTime: end, realTime: current.realTime, cancelled: current.cancelled,
                distance: route.distance, headsign: current.headsign, routeShortName: current.routeShortName,
                intermediateStops: current.intermediateStops,
                legGeometry: LegGeometry(points: Polyline(coordinates: coordinates, precision: 1e6).encodedPolyline, length: coordinates.count),
                agencyId: current.agencyId, tripId: current.tripId, steps: current.steps
            )
            if self.legIndex == index {
                self.alongInLeg = 0
                self.offRouteStreak = 0
                self.spokenManeuvers.removeAll()
                withAnimation { self.isOffRoute = false }
                self.evaluate()
            }
        }
    }
}
