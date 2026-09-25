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
        case connection, missedDeparture, cancelled, earlier, faster
    }

    struct ReplanProposal: Identifiable, Equatable {
        let id = UUID()
        let reason: ReplanReason
        let replaceFrom: Int
        let legs: [Leg]
        let arrival: Date
        let lateBy: TimeInterval
        let autoApplyAt: Date?
        var expiresAt: Date? = nil
        var exitName: String? = nil
        var ridingTripId: String? = nil

        var firstTransit: Leg? { legs.first(where: \.isTransit) }
        var nextTransit: Leg? {
            guard let ridingTripId else { return firstTransit }
            return legs.first { $0.isTransit && $0.tripId != ridingTripId }
        }

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
        let options = Self.savedRouteOptions(from: origin, to: Self.routeTarget(destination), time: departure)
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
                    String(localized: "Nouvel itinéraire : prenez \(transit.spokenLineName), \(self.spokenDeparture(transit.startTime)), arrivée à \(formatTime(proposal.arrival))."),
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
        refreshDisruptions()
        loadStationLayouts()

        let staysAboard = phase == .riding && keep == legIndex && legs[keep].tripId == proposal.ridingTripId
        if staysAboard {
            nextStopIndex = 1
            announcedStopAlerts = announcedStopAlerts.filter { !$0.hasPrefix("\(keep)-") }
        } else if keep <= legIndex {
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
        if replan?.reason == .earlier {
            declinedEarlierLegs.insert(legIndex)
        } else {
            declinedReplanLegs.insert(legIndex)
        }
        withAnimation(.spring(duration: 0.4)) { replan = nil }
    }

    static func routeTarget(_ destination: Place) -> RouteOptions.RouteLocation {
        destination.vertexType == .transit && destination.stopId != nil
            ? RouteOptions.RouteLocation(stopId: destination.stopId!)
            : RouteOptions.RouteLocation(coordinates: (destination.lat, destination.lon))
    }

    func lookForEarlierDeparture() {
        guard isRunning, phase == .waiting, replan == nil, !isReplanning, earlierTask == nil,
              !OfflineRouter.shared.isOfflineActive, !declinedEarlierLegs.contains(legIndex),
              now.timeIntervalSince(lastEarlierCheckAt) > 180,
              let leg = currentLeg, leg.isTransit, !leg.cancelled, leg.startTime.timeIntervalSince(now) > 180,
              let stopId = leg.from.stopId, let destination = legs.last?.to,
              let location = usableLocation,
              CLLocation(latitude: leg.from.lat, longitude: leg.from.lon).distance(from: location) < 120 else { return }

        lastEarlierCheckAt = now
        let index = legIndex
        let plannedDeparture = leg.startTime
        let options = Self.savedRouteOptions(from: RouteOptions.RouteLocation(stopId: stopId), to: Self.routeTarget(destination), time: now)
        earlierTask = Task { [weak self] in
            let result = try? await LuxData.route(options)
            guard let self else { return }
            self.earlierTask = nil
            guard !Task.isCancelled, self.isRunning, self.phase == .waiting, self.legIndex == index, self.replan == nil else { return }
            let now = Date()
            let candidates = (result?.itineraries ?? []).filter { itinerary in
                guard let first = itinerary.legs.first(where: \.isTransit), !first.cancelled else { return false }
                return first.startTime > now.addingTimeInterval(45)
                    && first.startTime < plannedDeparture.addingTimeInterval(-60)
                    && itinerary.endTime < self.arrivalDate.addingTimeInterval(-120)
            }
            guard let best = candidates.min(by: { $0.endTime < $1.endTime }), let transit = best.legs.first(where: \.isTransit) else { return }
            let proposal = ReplanProposal(
                reason: .earlier,
                replaceFrom: index,
                legs: best.legs,
                arrival: best.endTime,
                lateBy: best.endTime.timeIntervalSince(self.arrivalDate),
                autoApplyAt: nil
            )
            withAnimation(.spring(duration: 0.45)) { self.replan = proposal }
            self.announcer.announce(
                String(localized: "Départ plus tôt possible : \(transit.spokenLineName), \(self.spokenDeparture(transit.startTime)), arrivée à \(formatTime(proposal.arrival))."),
                notificationTitle: String(localized: "Départ plus tôt possible"),
                urgency: .notice
            )
        }
    }

    func lookForFasterConnection() {
        guard isRunning, phase == .riding, replan == nil, !isReplanning, earlierTask == nil,
              !OfflineRouter.shared.isOfflineActive, legIndex < legs.count - 1,
              let leg = currentLeg, leg.isTransit, let tripId = leg.tripId, let destination = legs.last?.to else { return }
        let stops = leg.allStops
        let exits = Array(stops.indices.filter { $0 >= max(1, nextStopIndex) }.suffix(4))
        guard !exits.isEmpty else { return }
        let index = legIndex
        let target = Self.routeTarget(destination)
        let currentArrival = arrivalDate
        earlierTask = Task { [weak self] in
            var best: (exit: Int, itinerary: Itinerary)?
            await withTaskGroup(of: (Int, Trip?).self) { group in
                for exit in exits {
                    let stop = stops[exit]
                    guard let stopId = stop.stopId else { continue }
                    let time = (stop.arrival ?? stop.scheduledArrival ?? stop.departure ?? Date()).addingTimeInterval(30)
                    let options = Self.savedRouteOptions(from: RouteOptions.RouteLocation(stopId: stopId), to: target, time: time)
                    group.addTask { (exit, try? await LuxData.route(options)) }
                }
                for await (exit, trip) in group {
                    let arrivalAtExit = stops[exit].arrival ?? stops[exit].scheduledArrival ?? Date()
                    for itinerary in trip?.itineraries ?? [] {
                        guard itinerary.startTime >= arrivalAtExit.addingTimeInterval(-60),
                              !itinerary.legs.contains(where: { $0.tripId == tripId }) else { continue }
                        if best.map({ itinerary.endTime < $0.itinerary.endTime }) ?? true {
                            best = (exit, itinerary)
                        }
                    }
                }
            }
            guard let self else { return }
            self.earlierTask = nil
            guard let best, self.isRunning, self.phase == .riding, self.legIndex == index, self.replan == nil,
                  best.itinerary.endTime < currentArrival.addingTimeInterval(-120) else { return }
            let exitsAtAlight = best.exit == stops.count - 1
            var newLegs = best.itinerary.legs
            if !exitsAtAlight {
                guard let shortened = LegLiveMerger.slice(leg, boardIndex: 0, alightIndex: best.exit) else { return }
                newLegs.insert(shortened, at: 0)
            }
            let exit = stops[best.exit]
            let proposal = ReplanProposal(
                reason: .faster,
                replaceFrom: exitsAtAlight ? index + 1 : index,
                legs: newLegs,
                arrival: best.itinerary.endTime,
                lateBy: best.itinerary.endTime.timeIntervalSince(currentArrival),
                autoApplyAt: nil,
                expiresAt: (exit.arrival ?? exit.scheduledArrival)?.addingTimeInterval(-30),
                exitName: self.placeName(exit),
                ridingTripId: tripId
            )
            withAnimation(.spring(duration: 0.45)) { self.replan = proposal }
            let next = proposal.nextTransit.map { String(localized: ", puis prenez \($0.spokenLineName)") } ?? ""
            self.announcer.announce(
                String(localized: "Correspondance plus rapide : descendez à \(proposal.exitName ?? "")\(next), arrivée à \(formatTime(proposal.arrival))."),
                notificationTitle: String(localized: "Correspondance plus rapide"),
                urgency: .notice
            )
        }
    }

    func boardEarlierVehicle(_ leg: Leg) {
        let index = legIndex
        guard !earlierBoardingLegs.contains(index) else { return }
        earlierBoardingLegs.insert(index)
        board(verifiable: false)
        guard let stopId = leg.from.stopId else { return }
        let plannedTrip = leg.tripId
        let isRail = leg.mode.isMainlineRail
        Task { [weak self] in
            let departures = try? await LuxData.departures(stopId: stopId, time: Date().addingTimeInterval(-15 * 60), numberOfEvents: 30)
            let now = Date()
            let candidates = (departures?.stopTimes ?? [])
                .filter { $0.tripId != plannedTrip && !$0.cancelled }
                .filter { isRail ? $0.mode.isMainlineRail : $0.routeShortName == leg.routeShortName }
                .filter { isRail || $0.headsign == nil || leg.headsign == nil || $0.headsign == leg.headsign }
                .compactMap { stopTime -> (tripId: String, departure: Date)? in
                    guard let departure = stopTime.place.departure ?? stopTime.place.scheduledDeparture,
                          departure <= now.addingTimeInterval(60), departure > now.addingTimeInterval(-12 * 60) else { return nil }
                    return (stopTime.tripId, departure)
                }
                .sorted { $0.departure > $1.departure }
                .prefix(3)
            for candidate in candidates {
                guard let trip = try? await LuxData.trip(tripId: candidate.tripId) else { continue }
                guard let self, self.legIndex == index, self.phase == .riding else { return }
                if LegLiveMerger.merge(self.legs[index], with: trip, retargetingTo: candidate.tripId) != nil {
                    self.retargetCurrentLeg(to: candidate.tripId)
                    return
                }
            }
        }
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
