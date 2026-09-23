//
//  OnboardSession+Live.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import MapKit
import LuxCom

extension OnboardSession {
    func startLiveFeeds() {
        liveFeeds.values.forEach { $0.stop() }
        liveFeeds.removeAll()
        vehicleTasks.values.forEach { $0.cancel() }
        vehicleTasks.removeAll()
        liveVehicles.removeAll()
        tripKeyFrames.removeAll()
        for index in legs.indices {
            startLiveFeed(for: index)
        }
    }

    func startLiveFeed(for index: Int) {
        tripKeyFrames[index] = nil
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
        guard let vehicle = approachingVehicle, let leg = nextTransitLeg?.leg else { return nil }
        return CLLocation(latitude: leg.from.lat, longitude: leg.from.lon)
            .distance(from: CLLocation(latitude: vehicle.lat, longitude: vehicle.lon))
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

    func estimatedVehicleCoordinate(at date: Date) -> CLLocationCoordinate2D? {
        guard phase == .walking || phase == .waiting, approachingVehicle == nil, let (index, _) = nextTransitLeg,
              let frames = tripKeyFrames[index]?.frames else { return nil }
        return VehicleVisualisation.interpolatePosition(at: date.timeIntervalSince1970, using: frames)
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
            spoken: "\(title). \(message).",
            urgency: .notice
        )
    }
}
