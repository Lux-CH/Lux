//
//  OnboardSession+Replan.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import MapKit
import LuxCom

extension OnboardSession {
    var walkingSpeed: CLLocationSpeed {
        if let walkingPace { return walkingPace }
        let configured = UserDefaults.standard.object(forKey: "routeOptionsPedestrianSpeed") as? Double ?? 1.2
        return max(0.5, configured)
    }

    enum ReplanReason: Equatable {
        case connection, missedDeparture, cancelled
    }

    struct ReplanProposal: Identifiable, Equatable {
        let id = UUID()
        let reason: ReplanReason
        let replaceFrom: Int
        let legs: [Leg]
        let arrival: Date
        let lateBy: TimeInterval
        let autoApplyAt: Date

        var firstTransit: Leg? { legs.first(where: \.isTransit) }

        static func == (lhs: ReplanProposal, rhs: ReplanProposal) -> Bool { lhs.id == rhs.id }
    }

    func requestReplan(_ reason: ReplanReason) {
        guard isRunning, phase != .arrived, !isReplanning, replan == nil, !declinedReplanLegs.contains(legIndex),
              now.timeIntervalSince(lastReplanAt) > 60, !OfflineRouter.shared.isOfflineActive,
              let destination = legs.last?.to else { return }

        let replaceFrom: Int
        let origin: RouteOptions.RouteLocation
        let departure: Date
        if phase == .riding, let leg = currentLeg, !leg.cancelled, let stopId = leg.to.stopId {
            replaceFrom = legIndex + 1
            origin = RouteOptions.RouteLocation(stopId: stopId)
            departure = leg.endTime
        } else if let coordinate = userLocation?.coordinate ?? currentLeg.map({ CLLocationCoordinate2D(latitude: $0.from.lat, longitude: $0.from.lon) }) {
            replaceFrom = legIndex
            origin = RouteOptions.RouteLocation(coordinates: (coordinate.latitude, coordinate.longitude))
            departure = now
        } else {
            return
        }
        guard replaceFrom < legs.count else { return }
        let target = destination.vertexType == .transit && destination.stopId != nil
            ? RouteOptions.RouteLocation(stopId: destination.stopId!)
            : RouteOptions.RouteLocation(coordinates: (destination.lat, destination.lon))
        let options = Self.savedRouteOptions(from: origin, to: target, time: departure)
        let currentArrival = arrivalDate
        let currentNext = legs[replaceFrom...].first(where: \.isTransit)?.tripId

        lastReplanAt = now
        isReplanning = true
        replanTask?.cancel()
        replanTask = Task { [weak self] in
            let result = try? await LuxData.route(options)
            guard let self, !Task.isCancelled else { return }
            self.isReplanning = false
            let candidates = (result?.itineraries ?? []).filter { $0.startTime >= departure.addingTimeInterval(-60) }
            guard let best = candidates.min(by: { $0.endTime < $1.endTime }) else {
                self.showAlert(
                    OnboardAlert(severity: .warning, symbolName: "arrow.triangle.branch", title: String(localized: "Aucune alternative trouvée"), message: nil),
                    spoken: nil,
                    urgency: .notice
                )
                return
            }
            if reason == .connection, best.legs.first(where: \.isTransit)?.tripId == currentNext {
                return
            }
            let proposal = ReplanProposal(
                reason: reason,
                replaceFrom: replaceFrom,
                legs: best.legs,
                arrival: best.endTime,
                lateBy: best.endTime.timeIntervalSince(currentArrival),
                autoApplyAt: Date().addingTimeInterval(60)
            )
            withAnimation(.spring(duration: 0.45)) { self.replan = proposal }
            if let transit = proposal.firstTransit {
                self.announcer.announce(
                    String(localized: "Nouvel itinéraire : prenez \(transit.spokenLineName) à \(formatTime(transit.startTime)), arrivée à \(formatTime(proposal.arrival))."),
                    notificationTitle: String(localized: "Nouvel itinéraire proposé"),
                    urgency: .critical
                )
            }
        }
    }

    func acceptReplan() {
        guard let proposal = replan, proposal.replaceFrom <= legs.count else { return }
        HapticFeedback.notification(type: .success)
        withAnimation(.spring(duration: 0.45)) { replan = nil }

        let keep = proposal.replaceFrom
        legs = Array(legs[..<keep]) + proposal.legs
        paths = Array(paths[..<keep])
        stopAlongs = Array(stopAlongs[..<keep])
        for leg in proposal.legs {
            let (path, alongs) = Self.buildPath(for: leg)
            paths.append(path)
            stopAlongs.append(alongs)
        }
        // from the walk leading into the new part too: its "vers la voie X" named the old train
        let rebuildFrom = keep > 0 && !reroutedWalks.contains(keep - 1) ? keep - 1 : keep
        maneuvers = Array(maneuvers[..<rebuildFrom]) + Self.buildManeuvers(legs: legs, paths: paths, stations: stationLayouts)[rebuildFrom...]
        announcedCancellations = announcedCancellations.filter { $0 < keep }
        missedDepartureAlerted = missedDepartureAlerted.filter { $0 < keep }
        announcedStopAlerts = announcedStopAlerts.filter { (Int($0.split(separator: "-").first ?? "") ?? 0) < keep }
        retargetedLegs = retargetedLegs.filter { $0 < keep }
        reroutedWalks = reroutedWalks.filter { $0 < keep }
        announcedRisk = .comfortable
        startLiveFeeds()
        loadStationLayouts()

        if keep <= legIndex {
            enterLeg(keep)
        }
        arrivalDate = proposal.arrival
        evaluate()
        showAlert(
            OnboardAlert(
                severity: .success,
                symbolName: "checkmark.circle.fill",
                title: String(localized: "Itinéraire mis à jour"),
                message: String(localized: "Arrivée prévue à \(formatTime(proposal.arrival))")
            ),
            spoken: nil,
            urgency: .guidance
        )
    }

    func declineReplan() {
        declinedReplanLegs.insert(legIndex)
        withAnimation(.spring(duration: 0.4)) { replan = nil }
    }

    static func savedRouteOptions(from: RouteOptions.RouteLocation, to: RouteOptions.RouteLocation, time: Date) -> RouteOptions {
        let defaults = UserDefaults.standard
        let maxTransfers = defaults.object(forKey: "routeOptionsMaxTransfers") as? Int ?? 5
        let minTransferTime = defaults.object(forKey: "routeOptionsMinTransferTime") as? Int ?? 0
        let profile = PedestrianProfile(rawValue: defaults.string(forKey: "routeOptionsPedestrianProfile") ?? "") ?? .foot
        let speed = defaults.object(forKey: "routeOptionsPedestrianSpeed") as? Double ?? 1.2
        let maxWalking = defaults.object(forKey: "routeOptionsMaxWalkingTime") as? Int ?? 900
        let modes = defaults.data(forKey: "routeOptionsTransportModes")
            .flatMap { try? JSONDecoder().decode(Set<TransportationMode>.self, from: $0) }
            .flatMap { $0.isEmpty ? nil : Array($0) }
        return RouteOptions(
            from: from,
            to: to,
            via: nil,
            viaMinimumStay: [],
            time: time,
            arriveBy: false,
            maxTransfers: maxTransfers,
            minTransferTime: minTransferTime,
            pedestrianProfile: profile,
            pedestrianSpeed: speed == 1.2 ? nil : speed,
            transitModes: modes,
            numItineraries: 5,
            timetableView: true,
            maxPreTransitTime: maxWalking == 900 ? nil : maxWalking,
            maxPostTransitTime: maxWalking == 900 ? nil : maxWalking
        )
    }

    func updateConnectionRisk() {
        let risk = computeConnectionRisk()
        if risk != connectionRisk {
            withAnimation { connectionRisk = risk }
        }
        if risk == .missed {
            requestReplan(.connection)
        } else if risk == .comfortable, replan?.reason == .connection {
            withAnimation(.spring(duration: 0.4)) { replan = nil }
        }
        guard risk != announcedRisk else { return }
        defer { announcedRisk = risk }
        guard let next = nextTransitLeg?.leg else { return }

        switch risk {
        case .missed where announcedRisk != .missed:
            showAlert(
                OnboardAlert(
                    severity: .critical,
                    symbolName: "arrow.triangle.branch",
                    title: String(localized: "Correspondance compromise"),
                    message: String(localized: "\(next.spokenLineName.capitalizedFirstLetter) part à \(formatTime(next.startTime)) de \(placeName(next.from)).")
                ),
                spoken: String(localized: "Attention, votre correspondance avec \(next.spokenLineName) risque d'être manquée."),
                urgency: .critical
            )
        case .tight where announcedRisk == .comfortable:
            showAlert(
                OnboardAlert(
                    severity: .warning,
                    symbolName: "hare.fill",
                    title: String(localized: "Correspondance serrée"),
                    message: String(localized: "\(next.spokenLineName.capitalizedFirstLetter) part à \(formatTime(next.startTime)). Pressez le pas.")
                ),
                spoken: nil,
                urgency: .notice
            )
        default:
            break
        }
    }

    func computeConnectionRisk() -> ConnectionRisk {
        guard phase != .arrived, phase != .waiting, let (nextIndex, next) = nextTransitLeg else { return .comfortable }

        let ready: Date
        let walkBetween = ((legIndex + 1)..<nextIndex).reduce(0.0) { total, index in
            total + (legs[index].isTransit ? 0 : walkTime(ofLegAt: index))
        }
        if phase == .riding, currentLeg != nil {
            ready = currentLegArrival.addingTimeInterval(walkBetween)
        } else if let path = currentPath, let leg = currentLeg {
            ready = now.addingTimeInterval(remainingWalkTime(leg: leg, path: path) + walkBetween)
        } else {
            return .comfortable
        }

        let margin = next.startTime.timeIntervalSince(ready)
        if margin < -30 { return .missed }
        if margin < 120 { return .tight }
        return .comfortable
    }

    var walkingPace: CLLocationSpeed? {
        if let stepPace = motion.walkingSpeed { return max(0.5, stepPace) }
        guard paceSamples >= 10, let measuredPace else { return nil }
        return max(0.5, measuredPace)
    }

    func walkTime(ofLegAt index: Int) -> TimeInterval {
        let leg = legs[index]
        if let walkingPace { return paths[index].length / walkingPace }
        return Double(leg.duration)
    }

    func remainingWalkTime(leg: Leg, path: RoutePath) -> TimeInterval {
        let remaining = max(0, path.length - alongInLeg)
        if let walkingPace { return remaining / walkingPace }
        guard path.length > 0, leg.duration > 0 else { return remaining / walkingSpeed }
        return remaining / path.length * Double(leg.duration)
    }

    func updateArrival() {
        guard phase != .arrived else { return }

        var remaining = max(0, (currentPath?.length ?? 0) - alongInLeg)
        for index in (legIndex + 1)..<max(legIndex + 1, legs.count) {
            remaining += paths[index].length
        }
        assign(\.remainingDistance, (remaining / 10).rounded() * 10)

        let estimate: Date
        if let lastTransit = legs.lastIndex(where: \.isTransit), lastTransit >= legIndex {
            let walkAfter = ((lastTransit + 1)..<legs.count).reduce(0.0) { $0 + walkTime(ofLegAt: $1) }
            let lastArrival = lastTransit == legIndex && phase == .riding ? currentLegArrival : legs[lastTransit].endTime
            estimate = lastArrival.addingTimeInterval(walkAfter)
        } else if let leg = currentLeg, let path = currentPath, !leg.isTransit {
            estimate = now.addingTimeInterval(remainingWalkTime(leg: leg, path: path))
        } else {
            estimate = now.addingTimeInterval(remaining / walkingSpeed)
        }
        if abs(estimate.timeIntervalSince(arrivalDate)) >= 30 {
            arrivalDate = estimate
        }
    }
}
