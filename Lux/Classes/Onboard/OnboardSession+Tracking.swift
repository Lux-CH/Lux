//
//  OnboardSession+Tracking.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import MapKit
import LuxCom

extension OnboardSession {
    static func buildPath(for leg: Leg) -> (RoutePath, [CLLocationDistance]) {
        let stops = leg.allStops
        let stopCoordinates = stops.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let fallback = leg.isTransit ? stopCoordinates : [stopCoordinates.first!, stopCoordinates.last!]
        let full = RoutePath(encoded: leg.legGeometry.points, precision: 1e6, fallback: fallback)

        guard leg.isTransit else { return (full, []) }

        let alongs = full.projectSequence(stopCoordinates)
        guard let first = alongs.first, let last = alongs.last, last - first > 1 else {
            return (full, alongs)
        }
        let path = full.sliced(from: first, to: last)
        return (path, alongs.map { $0 - first })
    }

    func handle(_ location: CLLocation, at date: Date = Date()) {
        guard isRunning, location.horizontalAccuracy >= 0 else { return }
        now = date
        lastFixAt = now
        assign(\.hasWeakGPS, location.horizontalAccuracy > usableAccuracy)
        userLocation = location
        motion.record(location)
        if phase == .walking, location.horizontalAccuracy <= 30, location.speed >= 0.4, location.speed <= 3 {
            measuredPace = measuredPace.map { $0 * 0.92 + location.speed * 0.08 } ?? location.speed
            paceSamples += 1
        }
        updateHeading()

        if !hasResolvedStart, location.horizontalAccuracy <= usableAccuracy {
            hasResolvedStart = true
            resolveStartingPoint(from: location)
        }
        evaluate()
        checkStillOnBoard()
        updateNearbyStations()
    }

    func handle(_ heading: CLHeading) {
        guard heading.headingAccuracy >= 0 else { return }
        compassHeading = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        compassAccuracy = heading.headingAccuracy
        compassAt = heading.timestamp
        updateHeading()
    }

    func updateHeading() {
        let target: CLLocationDirection?
        let compassIsReliable = compassHeading != nil
            && compassAccuracy >= 0 && compassAccuracy <= 25
            && Date().timeIntervalSince(compassAt) < 5
        if phase == .riding {
            if !followsTimetable, let location = userLocation, location.speed > 2.5, location.course >= 0 {
                target = location.course
            } else {
                target = currentPath?.bearing(at: alongInLeg) ?? compassHeading
            }
        } else if compassIsReliable {
            target = compassHeading
        } else if let location = userLocation, location.speed > 0.8, location.course >= 0, location.courseAccuracy >= 0, location.courseAccuracy <= 30 {
            target = location.course
        } else if phase == .walking, !isOffRoute, userLocation != nil {
            target = currentPath?.bearing(at: alongInLeg)
        } else {
            target = compassHeading
        }
        guard let target else { return }
        if let current = heading, abs(Angle360.delta(from: current, to: target)) < 1 { return }
        heading = target
    }

    func resolveStartingPoint(from location: CLLocation) {
        let point = location.coordinate
        for (index, leg) in legs.enumerated() {
            let path = paths[index]
            guard let projection = path.project(point) else { continue }

            if leg.isTransit {
                let alongs = stopAlongs[index]
                let boardAlong = alongs.first ?? 0
                let alightAlong = alongs.last ?? path.length
                let railRiding = leg.mode.isMainlineRail
                    && projection.offset < 500
                    && now > leg.startTime && now < leg.endTime
                let riding = railRiding || projection.offset < 60
                    && projection.along > boardAlong + 80
                    && projection.along < alightAlong - 30
                    && now > leg.startTime.addingTimeInterval(-120)
                    && now < leg.endTime.addingTimeInterval(600)
                if riding {
                    if index != legIndex { enterLeg(index, announce: false) }
                    board(announce: false, verifiable: false)
                    return
                }
                let atStop = CLLocation(latitude: leg.from.lat, longitude: leg.from.lon).distance(from: location) < 80
                if atStop && now < leg.startTime.addingTimeInterval(180) {
                    if index != legIndex { enterLeg(index, announce: false) }
                    return
                }
            } else if projection.offset < 40 {
                if index != legIndex { enterLeg(index, announce: false) }
                return
            }
        }
    }

    func evaluate() {
        switch phase {
        case .walking: evaluateWalking()
        case .waiting: evaluateWaiting()
        case .riding: evaluateRiding()
        case .arrived: break
        }
        updateConnectionRisk()
        updateArrival()
        updateApproachingVehicle()
        liveActivity.update(activityState())
    }

    var usableLocation: CLLocation? {
        guard let location = userLocation, location.horizontalAccuracy <= usableAccuracy,
              let lastFixAt, now.timeIntervalSince(lastFixAt) < 45 else { return nil }
        return location
    }

    func evaluateWalking() {
        guard let leg = currentLeg, let path = currentPath else { return }
        guard let location = usableLocation, let projection = path.project(location.coordinate, hint: alongInLeg) else {
            walkOffset = .infinity
            updateManeuvers()
            return
        }

        walkOffset = projection.offset
        assign(\.alongInLeg, projection.along)
        let tolerance = max(offRouteDistance, location.horizontalAccuracy)
        if projection.offset > tolerance {
            offRouteStreak += 1
        } else if projection.offset < tolerance * 0.7 {
            offRouteStreak = 0
            if isOffRoute { withAnimation { isOffRoute = false } }
        }
        // indoors GPS drifts, and an Apple Maps re-route would drop the station path
        if offRouteStreak >= 3 && !isOffRoute && !isInStation && alightWatch?.onBoardSince == nil {
            withAnimation { isOffRoute = true }
            reroute()
        }

        updateManeuvers()
        speakManeuverIfNeeded()

        let end = CLLocation(latitude: leg.to.lat, longitude: leg.to.lon)
        let reachedEnd = location.distance(from: end) < max(arrivalRadius, location.horizontalAccuracy * 0.6)
            || (!isOffRoute && path.length - alongInLeg < arrivalRadius)
        if reachedEnd {
            completeLeg()
            return
        }

        if legIndex + 1 < legs.count, legs[legIndex + 1].isTransit {
            let next = legs[legIndex + 1]
            if CLLocation(latitude: next.from.lat, longitude: next.from.lon).distance(from: location) < stopRadius {
                completeLeg()
            }
        }
    }

    func updateManeuvers() {
        let list = maneuvers.indices.contains(legIndex) ? maneuvers[legIndex] : []
        let upcoming = list.filter { $0.along > alongInLeg + 3 }
        assign(\.nextManeuver, upcoming.first)
        let distance = upcoming.first.map { $0.along - alongInLeg }
            ?? currentPath.map { max(0, $0.length - alongInLeg) }
        assign(\.distanceToManeuver, distance.map { ($0 * 2).rounded() / 2 })
        if let first = upcoming.first, upcoming.count > 1, upcoming[1].along - first.along < 60 {
            assign(\.followingManeuver, upcoming[1])
        } else {
            assign(\.followingManeuver, nil)
        }
    }

    func speakManeuverIfNeeded() {
        guard let maneuver = nextManeuver, let distance = distanceToManeuver else { return }
        let key = "\(legIndex)-\(Int(maneuver.along))"
        if distance <= 18, !spokenManeuvers.contains(key + "-now") {
            spokenManeuvers.insert(key + "-now")
            spokenManeuvers.insert(key + "-soon")
            announcer.announce(maneuver.shortInstruction, urgency: .guidance)
        } else if distance <= 90, distance > 35, !spokenManeuvers.contains(key + "-soon") {
            spokenManeuvers.insert(key + "-soon")
            let rounded = Int((distance / 10).rounded() * 10)
            announcer.announce(String(localized: "Dans \(rounded) mètres, \(maneuver.instruction.lowercasedFirstLetter)"), urgency: .guidance)
        }
    }

    func evaluateWaiting() {
        guard let leg = currentLeg, let path = currentPath else { return }
        assign(\.alongInLeg, 0)

        if leg.mode.isMainlineRail {
            if now > leg.startTime.addingTimeInterval(20) {
                board()
                return
            }
            // an earlier train: well clear of the platform, at a speed no one runs at
            if let location = usableLocation, let projection = path.project(location.coordinate, hint: 0) {
                if CLLocation(latitude: leg.from.lat, longitude: leg.from.lon).distance(from: location) < 250 {
                    lastAtBoardingStop = now
                }
                let boardAlong = stopAlongs[legIndex].first ?? 0
                let leaving = projection.offset < 60 && projection.along > boardAlong + 200 && location.speed > 7
                if leaving && now < leg.startTime.addingTimeInterval(-120)
                    && lastAtBoardingStop.map({ now.timeIntervalSince($0) < 600 }) == true {
                    boardEarlierVehicle(leg)
                }
            }
            return
        }

        if let location = usableLocation, let projection = path.project(location.coordinate, hint: 0) {
            if CLLocation(latitude: leg.from.lat, longitude: leg.from.lon).distance(from: location) < max(40, location.horizontalAccuracy) {
                lastAtBoardingStop = now
            }
            let boardAlong = stopAlongs[legIndex].first ?? 0
            let movingAway = projection.offset < 50
                && projection.along > boardAlong + 70
                && location.speed > 2
            if movingAway && now > leg.startTime.addingTimeInterval(-120) {
                board()
                return
            }
            if movingAway && lastAtBoardingStop.map({ now.timeIntervalSince($0) < 600 }) == true {
                boardEarlierVehicle(leg)
                return
            }

            let stillAtStop = CLLocation(latitude: leg.from.lat, longitude: leg.from.lon).distance(from: location) < 100
            if stillAtStop && now > leg.startTime.addingTimeInterval(180) && !missedDepartureAlerted.contains(legIndex) {
                missedDepartureAlerted.insert(legIndex)
                showAlert(
                    OnboardAlert(
                        severity: .warning,
                        symbolName: "exclamationmark.triangle.fill",
                        title: String(localized: "Départ manqué ?"),
                        message: String(localized: "\(leg.spokenLineName.capitalizedFirstLetter) est parti. Si vous êtes à bord, touchez « Je suis à bord ».")
                    ),
                    spoken: String(localized: "Il semble que vous ayez manqué \(leg.spokenLineName)."),
                    urgency: .notice
                )
                requestReplan(.missedDeparture)
            }
        } else if now > leg.startTime.addingTimeInterval(90) {
            board(verifiable: false)
        }
    }

    func evaluateRiding() {
        guard let leg = currentLeg, let path = currentPath else { return }
        let alongs = stopAlongs[legIndex]
        guard alongs.count >= 2 else { return }

        if leg.ridesByTimetable {
            evaluateRidingTrain(leg: leg, alongs: alongs)
            return
        }

        var locatedByGPS = false
        var offset = CLLocationDistance.infinity
        if let location = usableLocation,
           let projection = path.project(location.coordinate, hint: alongInLeg),
           projection.offset < max(80, location.horizontalAccuracy) {
            offset = projection.offset
            let clearlyBehind = location.horizontalAccuracy <= 30 && alongInLeg - projection.along > 40
            assign(\.alongInLeg, clearlyBehind ? projection.along : max(alongInLeg - 15, projection.along))
            locatedByGPS = true
        } else {
            assign(\.alongInLeg, max(alongInLeg, estimatedAlongByTime(leg: leg, alongs: alongs)))
        }
        ridesOffPath = usableLocation != nil && offset > (ridesOffPath ? 10 : 15)

        assign(\.dwellingStopIndex, alongs.firstIndex { abs($0 - alongInLeg) <= stopRadius })
        let next = alongs.firstIndex { $0 > alongInLeg + stopRadius * 0.7 } ?? (alongs.count - 1)
        if next != nextStopIndex {
            nextStopIndex = max(1, next)
        }
        announceStopsIfNeeded(leg: leg)

        if locatedByGPS {
            reportCrowdPosition(leg: leg, offsetOK: true)
            updatePositionDelay(leg: leg, alongs: alongs)
            checkDelay(of: leg, at: legIndex)
        } else if positionDelay != nil, now.timeIntervalSince(positionDelayAt) > 60 {
            positionDelay = nil
        }

        let alightAlong = alongs.last ?? path.length
        if locatedByGPS, let location = usableLocation {
            let alight = CLLocation(latitude: leg.to.lat, longitude: leg.to.lon)
            let atAlight = location.distance(from: alight) < 45
            if atAlight && (location.speed < 1.5 || alongInLeg >= alightAlong - 10) {
                completeLeg()
                return
            }
        } else if now > leg.endTime.addingTimeInterval(45) {
            completeLeg()
        }
    }

    func evaluateRidingTrain(leg: Leg, alongs: [CLLocationDistance]) {
        let timetable = estimatedAlongByTime(leg: leg, alongs: alongs)
        var gpsAlong: CLLocationDistance?
        if let location = userLocation, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 25,
           now.timeIntervalSince(location.timestamp) < 4,
           let projection = currentPath?.project(location.coordinate, hint: alongInLeg),
           projection.offset < 40, abs(projection.along - timetable) < 2500 {
            gpsAlong = projection.along
            if location.timestamp > lastTrainFix {
                lastTrainFix = location.timestamp
                trainFix = (projection.along, max(0, location.speed))
                trainGPSStreak += 1
                trainGPSAt = now
            }
        } else if now.timeIntervalSince(trainGPSAt) >= 15 {
            trainGPSStreak = 0
        }
        let locked = trainGPSStreak >= 3 && now.timeIntervalSince(trainGPSAt) < 15
        if locked != hasTrainGPS {
            withAnimation { hasTrainGPS = locked }
        }

        if locked {
            if let gpsAlong, alongInLeg - gpsAlong > 60 {
                assign(\.alongInLeg, gpsAlong)
            } else {
                let along = gpsAlong ?? trainFix.along + trainFix.speed * now.timeIntervalSince(trainGPSAt)
                assign(\.alongInLeg, max(alongInLeg - 30, along))
            }
        } else {
            assign(\.alongInLeg, timetable)
        }
        assign(\.dwellingStopIndex, alongs.firstIndex { abs($0 - alongInLeg) <= stopRadius })
        let next = alongs.firstIndex { $0 > alongInLeg + stopRadius * 0.7 } ?? (alongs.count - 1)
        if next != nextStopIndex {
            nextStopIndex = max(1, next)
        }
        announceStopsIfNeeded(leg: leg)
        updateHeading()

        let alightAlong = alongs.last ?? alongInLeg
        if locked, let location = userLocation {
            let stoppedAtAlight = CLLocation(latitude: leg.to.lat, longitude: leg.to.lon).distance(from: location) < 120
                && location.speed >= 0 && location.speed < 1.5
            if stoppedAtAlight || alongInLeg > alightAlong + 400 {
                completeLeg()
            }
        } else if now > leg.endTime.addingTimeInterval(15) {
            completeLeg()
        }
    }

    var estimatedAlightTime: Date? {
        guard phase == .riding, !followsTimetable, let positionDelay, now.timeIntervalSince(positionDelayAt) < 60,
              let leg = currentLeg, let scheduled = leg.to.scheduledArrival ?? leg.to.scheduledDeparture else { return nil }
        return max(now, scheduled.addingTimeInterval(positionDelay))
    }

    var currentLegArrival: Date {
        estimatedAlightTime ?? currentLeg?.endTime ?? now
    }

    var currentLegDelayMinutes: Int {
        if estimatedAlightTime != nil, let positionDelay { return Int((positionDelay / 60).rounded()) }
        return currentLeg?.arrivalDelayMinutes ?? 0
    }

    func updatePositionDelay(leg: Leg, alongs: [CLLocationDistance]) {
        guard alongInLeg > (alongs.first ?? 0) + 60 else { return }
        let stops = leg.allStops
        func arrival(_ index: Int) -> Date? { stops[index].scheduledArrival ?? stops[index].scheduledDeparture }
        func departure(_ index: Int) -> Date? { stops[index].scheduledDeparture ?? stops[index].scheduledArrival }

        var delay: TimeInterval?
        if let stop = dwellingStopIndex, let arrive = arrival(stop), let leave = departure(stop) {
            if now < arrive { delay = now.timeIntervalSince(arrive) }
            else if now <= leave { delay = 0 }
            else { delay = now.timeIntervalSince(leave) }
        } else if let segment = (0..<(alongs.count - 1)).first(where: { alongInLeg >= alongs[$0] && alongInLeg < alongs[$0 + 1] }),
                  let leave = departure(segment), let arrive = arrival(segment + 1) {
            let span = alongs[segment + 1] - alongs[segment]
            let fraction = span > 0 ? (alongInLeg - alongs[segment]) / span : 0
            let scheduled = leave.addingTimeInterval(arrive.timeIntervalSince(leave) * fraction)
            delay = now.timeIntervalSince(scheduled)
        }
        guard let delay, delay > -300, delay < 5400 else { return }
        positionDelay = positionDelay.map { $0 * 0.7 + delay * 0.3 } ?? delay
        positionDelayAt = now
    }

    func estimatedAlongByTime(leg: Leg, alongs: [CLLocationDistance]) -> CLLocationDistance {
        if let along = keyFrameAlong(leg: leg) { return along }
        let stops = leg.allStops
        let times: [Date] = stops.enumerated().map { index, stop in
            (index == 0 ? stop.departure ?? stop.arrival : stop.arrival ?? stop.departure)
                ?? leg.startTime.addingTimeInterval(Double(index) / Double(max(1, stops.count - 1)) * Double(leg.duration))
        }
        guard let first = times.first, now > first else { return alongs.first ?? 0 }
        for index in 0..<(times.count - 1) {
            let departure = stops[index].departure ?? times[index]
            let arrival = times[index + 1]
            if now < departure { return alongs[index] }
            if now < arrival {
                let fraction = arrival > departure ? now.timeIntervalSince(departure) / arrival.timeIntervalSince(departure) : 1
                return alongs[index] + (alongs[index + 1] - alongs[index]) * fraction
            }
        }
        return alongs.last ?? 0
    }

    private func keyFrameAlong(leg: Leg) -> CLLocationDistance? {
        let times = leg.allStops.compactMap { ($0.arrival ?? $0.departure)?.timeIntervalSince1970 }.reduce(0, +)
        let key = "\(legIndex)|\(leg.tripId ?? "")|\(times)"
        if legKeyFrames?.key != key {
            legKeyFrames = (key, VehicleVisualisation.calculateKeyFrames(for: leg, polylineString: leg.legGeometry.points, precision: 1e6))
        }
        guard let frames = legKeyFrames?.frames, !frames.isEmpty, let path = currentPath,
              let position = VehicleVisualisation.interpolatePosition(at: now.timeIntervalSince1970, using: frames),
              let projection = path.project(position, hint: alongInLeg) else { return nil }
        return projection.along
    }

    func announceStopsIfNeeded(leg: Leg) {
        let stops = leg.allStops
        let alightName = placeName(leg.to)
        let remaining = stopsRemaining
        let key = "\(legIndex)"

        let alongs = stopAlongs.indices.contains(legIndex) ? stopAlongs[legIndex] : []
        if alongs.count >= 2, phase == .riding, !announcedStopAlerts.contains(key + "-final") {
            let alight = alongs[alongs.count - 1]
            let previous = alongs[alongs.count - 2]
            if alight - previous > 300, alongInLeg > previous, alight - alongInLeg <= 20 {
                announcedStopAlerts.insert(key + "-final")
                announcer.speak(String(localized: "Descendez maintenant, \(alightName)."))
            }
        }

        if remaining == 1, !announcedStopAlerts.contains(key + "-next") {
            announcedStopAlerts.insert(key + "-next")
            announcedStopAlerts.insert(key + "-two")
            let title = String(localized: "Descendez au prochain arrêt")
            announcer.announce(String(localized: "Descendez au prochain arrêt, \(alightName)."), notificationTitle: title, urgency: .critical)
        } else if remaining == 2, stops.count >= 4, !announcedStopAlerts.contains(key + "-two") {
            announcedStopAlerts.insert(key + "-two")
            showAlert(
                OnboardAlert(
                    severity: .info,
                    symbolName: "bell.fill",
                    title: String(localized: "Descente dans 2 arrêts"),
                    message: alightName
                ),
                spoken: String(localized: "Préparez-vous à descendre dans 2 arrêts, à \(alightName)."),
                urgency: .notice
            )
        }
    }

    func enterLeg(_ index: Int, announce: Bool = true) {
        guard legs.indices.contains(index) else { return }
        let leg = legs[index]
        let newPhase: OnboardPhase = leg.isTransit
            ? (leg.interlineWithPreviousLeg == true && index > 0 ? .riding : .waiting)
            : .walking
        withAnimation(.spring(duration: 0.45)) {
            legIndex = index
            phase = newPhase
        }
        alongInLeg = 0
        offRouteStreak = 0
        isOffRoute = false
        nextStopIndex = 1
        dwellingStopIndex = nil
        hasTrainGPS = false
        trainGPSStreak = 0
        crowdStatus = nil
        rideReports = [:]
        positionDelay = nil
        showsCrowdPrompt = false
        crowdPromptTask?.cancel()
        lastAtBoardingStop = nil
        if boarding?.legIndex != index { boarding = nil }

        if leg.isTransit {
            startRideInfo()
            if announce {
                let direction = leg.headsign.map { String(localized: " direction \($0)") } ?? ""
                announcer.announce(
                    String(localized: "Prenez \(leg.spokenLineName)\(direction), \(spokenDeparture(leg.startTime))."),
                    notificationTitle: String(localized: "Prochaine étape"),
                    urgency: .notice
                )
            }
        } else {
            rideInfoTask?.cancel()
            rideInfo = nil
            if paths[index].length < 15 && index < legs.count - 1 {
                completeLeg(announce: announce)
                return
            }
            updateManeuvers()
            if announce {
                let target = placeName(leg.to, isDestination: index == legs.count - 1)
                announcer.announce(
                    String(localized: "Marchez jusqu'à \(target)."),
                    notificationTitle: String(localized: "Prochaine étape"),
                    urgency: .guidance
                )
            }
        }
        refreshDisruptions()
        liveActivity.update(activityState())
    }

    func board(announce: Bool = true, verifiable: Bool = true) {
        guard let leg = currentLeg, leg.isTransit else { return }
        if verifiable, let stopId = leg.from.stopId {
            boarding = (legIndex, stopId, lastAtBoardingStop ?? now)
        }
        withAnimation(.spring(duration: 0.45)) { phase = .riding }
        nextStopIndex = 1
        scheduleCrowdPrompt()
        if announce {
            let count = leg.allStops.count - 1
            announcer.announce(
                String(localized: "Vous êtes à bord. Descendez à \(placeName(leg.to)) dans \(count) arrêts."),
                urgency: .guidance
            )
        }
    }

    func completeLeg(announce: Bool = true) {
        if phase == .riding, isSharingPosition {
            enqueueRelay { await RelayClient.shared.stopOnboardReports() }
        }
        if phase == .riding, let leg = currentLeg {
            alightWatch = AlightWatch(legIndex: legIndex, leg: leg, since: now)
        }
        if legIndex >= legs.count - 1 {
            arrive()
        } else {
            enterLeg(legIndex + 1, announce: announce)
        }
    }

    func arrive() {
        guard phase != .arrived else { return }
        withAnimation(.spring(duration: 0.5)) { phase = .arrived }
        alongInLeg = currentPath?.length ?? 0
        arrivalDate = Date()
        remainingDistance = 0
        HapticFeedback.notification(type: .success)
        announcer.announce(
            String(localized: "Vous êtes arrivé à \(destinationName)."),
            notificationTitle: String(localized: "Vous êtes arrivé"),
            urgency: .notice
        )
        liveActivity.update(activityState())
        arrivalTask?.cancel()
        arrivalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self, !Task.isCancelled, self.phase == .arrived else { return }
            self.stopTracking()
            self.liveActivity.end(finalState: self.activityState())
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func reroute() {
        guard let leg = currentLeg, !leg.isTransit, let location = usableLocation,
              now.timeIntervalSince(lastRerouteAt) > rerouteCooldown else { return }
        lastRerouteAt = now
        let index = legIndex

        rerouteTask?.cancel()
        rerouteTask = Task { [weak self] in
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: leg.to.lat, longitude: leg.to.lon)))
            request.transportType = .walking
            guard let route = try? await MKDirections(request: request).calculate().routes.first,
                  !Task.isCancelled, let self, self.legIndex == index, self.phase == .walking else { return }

            let points = route.polyline.points()
            let coordinates = (0..<route.polyline.pointCount).map { points[$0].coordinate }
            let path = RoutePath(coordinates: coordinates)
            guard !path.isEmpty else { return }
            self.paths[index] = path
            self.maneuvers[index] = WalkManeuverBuilder.maneuvers(for: [StepInstruction](), on: path)
            self.reroutedWalks.insert(index)
            self.alongInLeg = 0
            self.offRouteStreak = 0
            self.spokenManeuvers.removeAll()
            withAnimation { self.isOffRoute = false }
            self.announcer.announce(String(localized: "Nouvel itinéraire à pied."), urgency: .guidance)
            self.evaluate()
        }
    }

    func catchUpWithVehicle() {
        guard isRunning, phase == .walking || phase == .waiting, motion.isInVehicle else { return }
        let running = legs.indices.first { index in
            index >= legIndex && legs[index].isTransit
                && now >= legs[index].startTime.addingTimeInterval(-60)
                && now <= legs[index].endTime.addingTimeInterval(120)
        }
        guard let index = running else { return }
        hasResolvedStart = true
        if index != legIndex { enterLeg(index, announce: false) }
        board(verifiable: false)
    }
}
