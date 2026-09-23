//
//  OnboardSession.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import MapKit
import LuxCom

@MainActor
@Observable
final class OnboardSession {
    let offRouteDistance: CLLocationDistance = 35
    let arrivalRadius: CLLocationDistance = 20
    let stopRadius: CLLocationDistance = 30
    let usableAccuracy: CLLocationAccuracy = 80
    let crowdReportInterval: TimeInterval = 10
    let rerouteCooldown: TimeInterval = 20

    let destinationName: String
    var legs: [Leg]
    var paths: [RoutePath]
    @ObservationIgnored var stopAlongs: [[CLLocationDistance]]
    @ObservationIgnored var maneuvers: [[WalkManeuver]]

    var phase: OnboardPhase = .walking
    var legIndex = 0
    var userLocation: CLLocation?
    var heading: CLLocationDirection?
    var alongInLeg: CLLocationDistance = 0
    var isOffRoute = false
    var hasWeakGPS = false
    var nextManeuver: WalkManeuver?
    var distanceToManeuver: CLLocationDistance?
    var followingManeuver: WalkManeuver?
    var nextStopIndex = 1
    var dwellingStopIndex: Int?
    var arrivalDate: Date
    var remainingDistance: CLLocationDistance = 0
    var connectionRisk: ConnectionRisk = .comfortable
    var alert: OnboardAlert?
    var crowdStatus: CrowdStatus?
    var approachingVehicle: RelayClient.CrowdVehicle?
    var isSharingPosition = Settings.shared.sharesOnboardPosition
    var rideInfo: InfoResponse?
    var rideReports: [ReportAttribute: Int] = [:]
    var showsCrowdPrompt = false
    var replan: ReplanProposal?
    var isBehindOrAheadOfSchedule = false
    var positionDelay: TimeInterval?
    @ObservationIgnored var positionDelayAt: Date = .distantPast
    var hasEstimatedVehicle = false
    var isReplanning = false

    var needsSharingConsent: Bool { Settings.shared.onboardCrowdConsent == .undecided }

    @ObservationIgnored var now = Date()

    var voiceEnabled: Bool {
        didSet {
            announcer.voiceEnabled = voiceEnabled
            Settings.shared.onboardVoiceGuidance = voiceEnabled
            if !voiceEnabled { announcer.stop() }
        }
    }

    let locationProvider = OnboardLocationProvider()
    let motion = OnboardMotionDetector()
    @ObservationIgnored var measuredPace: CLLocationSpeed?
    @ObservationIgnored var tripKeyFrames: [Int: (frames: [VehicleVisualisation.KeyFrame], at: Date)] = [:]
    @ObservationIgnored var paceSamples = 0
    let announcer: OnboardAnnouncer
    let liveActivity = OnboardLiveActivityController()
    @ObservationIgnored var liveFeeds: [Int: RelayLiveFeed<Itinerary>] = [:]
    @ObservationIgnored var vehicleTasks: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored var rideInfoTask: Task<Void, Never>?
    @ObservationIgnored var crowdPromptTask: Task<Void, Never>?
    @ObservationIgnored var promptedLegs: Set<Int> = []
    @ObservationIgnored var lastAtBoardingStop: Date?
    @ObservationIgnored var boarding: (legIndex: Int, stopId: String, at: Date)?
    @ObservationIgnored var retargetedLegs: Set<Int> = []
    @ObservationIgnored var replanTask: Task<Void, Never>?
    @ObservationIgnored var arrivalTask: Task<Void, Never>?
    @ObservationIgnored var isTracking = false
    @ObservationIgnored var relayQueue: Task<Void, Never>?
    @ObservationIgnored var lastReplanAt: Date = .distantPast
    @ObservationIgnored var declinedReplanLegs: Set<Int> = []
    @ObservationIgnored var liveVehicles: [Int: RelayClient.CrowdVehicle] = [:]
    @ObservationIgnored var tickTask: Task<Void, Never>?
    @ObservationIgnored var crowdAckTask: Task<Void, Never>?
    @ObservationIgnored var alertDismissTask: Task<Void, Never>?
    @ObservationIgnored var rerouteTask: Task<Void, Never>?
    @ObservationIgnored var isRunning = false
    @ObservationIgnored var hasResolvedStart = false
    @ObservationIgnored var lastFixAt: Date?
    @ObservationIgnored var compassHeading: CLLocationDirection?
    @ObservationIgnored var compassAccuracy: CLLocationDirection = -1
    @ObservationIgnored var compassAt: Date = .distantPast
    @ObservationIgnored var offRouteStreak = 0
    @ObservationIgnored var lastRerouteAt: Date = .distantPast
    @ObservationIgnored var lastCrowdReportAt: Date = .distantPast
    @ObservationIgnored var spokenManeuvers: Set<String> = []
    @ObservationIgnored var announcedStopAlerts: Set<String> = []
    @ObservationIgnored var announcedDelays: [Int: Int] = [:]
    @ObservationIgnored var announcedCancellations: Set<Int> = []
    @ObservationIgnored var announcedRisk: ConnectionRisk = .comfortable
    @ObservationIgnored var missedDepartureAlerted: Set<Int> = []

    init(itinerary: Itinerary, destinationName: String?) {
        let legs = itinerary.legs
        self.legs = legs
        self.destinationName = destinationName
            ?? legs.last.map { $0.to.name == "END" ? String(localized: "votre destination") : $0.to.name }
            ?? String(localized: "votre destination")
        self.arrivalDate = itinerary.endTime
        self.voiceEnabled = Settings.shared.onboardVoiceGuidance
        self.announcer = OnboardAnnouncer(voiceEnabled: Settings.shared.onboardVoiceGuidance)

        var paths: [RoutePath] = []
        var stopAlongs: [[CLLocationDistance]] = []
        var maneuvers: [[WalkManeuver]] = []
        for leg in legs {
            let (path, alongs) = Self.buildPath(for: leg)
            paths.append(path)
            stopAlongs.append(alongs)
            maneuvers.append(leg.isTransit ? [] : WalkManeuverBuilder.maneuvers(for: leg.steps ?? [], on: path))
        }
        self.paths = paths
        self.stopAlongs = stopAlongs
        self.maneuvers = maneuvers
        self.remainingDistance = paths.reduce(0) { $0 + $1.length }
    }

    static func canStart(_ itinerary: Itinerary, at date: Date = Date()) -> Bool {
        guard !itinerary.legs.isEmpty else { return false }
        return itinerary.startTime.timeIntervalSince(date) < 3 * 3600 && itinerary.endTime.timeIntervalSince(date) > -10 * 60
    }

    func start() {
        guard !isRunning, !legs.isEmpty else { return }
        isRunning = true

        enterLeg(0, announce: false)

        locationProvider.onLocation = { [weak self] location in self?.handle(location) }
        locationProvider.onHeading = { [weak self] heading in self?.handle(heading) }
        locationProvider.start()
        motion.start()
        isTracking = true

        UIApplication.shared.isIdleTimerDisabled = true
        enqueueRelay { await RelayClient.shared.setBackgroundKeepAlive(true) }
        startLiveFeeds()
        startCrowdAcks()

        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }

        liveActivity.start(destinationName: destinationName.capitalizedFirstLetter, state: activityState())
        announcer.alertSink = { [weak self] title, body in
            guard let self, self.liveActivity.isActive else { return false }
            self.liveActivity.update(self.activityState(), alert: (title, body ?? ""))
            return true
        }
        announcer.speak(startAnnouncement())
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        tickTask?.cancel()
        crowdAckTask?.cancel()
        alertDismissTask?.cancel()
        rerouteTask?.cancel()
        liveFeeds.values.forEach { $0.stop() }
        liveFeeds.removeAll()
        vehicleTasks.values.forEach { $0.cancel() }
        vehicleTasks.removeAll()
        rideInfoTask?.cancel()
        crowdPromptTask?.cancel()
        replanTask?.cancel()
        arrivalTask?.cancel()
        stopTracking()
        announcer.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        liveActivity.end(finalState: phase == .arrived ? activityState() : nil)
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        locationProvider.stop()
        motion.stop()
        enqueueRelay {
            await RelayClient.shared.stopOnboardReports()
            await RelayClient.shared.setBackgroundKeepAlive(false)
        }
    }

    func enqueueRelay(_ operation: @escaping @Sendable () async -> Void) {
        let previous = relayQueue
        relayQueue = Task {
            await previous?.value
            await operation()
        }
    }

    func assign<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<OnboardSession, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }

    var currentLeg: Leg? { legs.indices.contains(legIndex) ? legs[legIndex] : nil }

    var currentPath: RoutePath? { paths.indices.contains(legIndex) ? paths[legIndex] : nil }

    var currentStops: [Place] { currentLeg?.allStops ?? [] }

    var upcomingStops: [Place] {
        let stops = currentStops
        guard phase == .riding || phase == .waiting, !stops.isEmpty else { return [] }
        let start = phase == .waiting ? 0 : min(nextStopIndex, stops.count - 1)
        return Array(stops[start...])
    }

    var stopsRemaining: Int {
        max(0, currentStops.count - nextStopIndex)
    }

    var nextTransitLeg: (index: Int, leg: Leg)? {
        let start = phase == .waiting ? legIndex : legIndex + 1
        guard start < legs.count else { return nil }
        for index in start..<legs.count where legs[index].isTransit {
            return (index, legs[index])
        }
        return nil
    }

    var legProgress: Double {
        guard let path = currentPath, path.length > 0 else { return phase == .arrived ? 1 : 0 }
        return max(0, min(1, alongInLeg / path.length))
    }

    var stopProgress: Double {
        guard phase == .riding, legs.indices.contains(legIndex) else { return phase == .arrived ? 1 : 0 }
        let alongs = stopAlongs[legIndex]
        guard alongs.count >= 2 else { return legProgress }
        let segment = max(0, min(alongs.count - 2, nextStopIndex - 1))
        let start = alongs[segment]
        let end = alongs[segment + 1]
        let fraction = end > start ? max(0, min(1, (alongInLeg - start) / (end - start))) : 0
        return (Double(segment) + fraction) / Double(alongs.count - 1)
    }

    var currentSegmentTimes: (start: Date, end: Date)? {
        guard phase == .riding, let leg = currentLeg else { return nil }
        let stops = leg.allStops
        guard stops.count >= 2 else { return nil }
        let segment = max(0, min(stops.count - 2, nextStopIndex - 1))
        let departure = stops[segment].departure ?? stops[segment].scheduledDeparture ?? stops[segment].arrival
        let arrival = stops[segment + 1].arrival ?? stops[segment + 1].scheduledArrival ?? stops[segment + 1].departure
        guard let departure, let arrival, arrival > departure else { return nil }
        return (departure, arrival)
    }

    func placeName(_ place: Place, isDestination: Bool = false) -> String {
        if place.name == "END" || (isDestination && place.name.isEmpty) { return destinationName }
        if place.name == "START" { return String(localized: "votre position") }
        return place.name
    }

    var followsTimetable: Bool {
        guard let leg = currentLeg, leg.isTransit else { return false }
        return leg.mode.isMainlineRail && (phase == .riding || phase == .waiting)
    }

    var riderCoordinate: CLLocationCoordinate2D? {
        if followsTimetable, phase == .riding, let point = currentPath?.coordinate(at: alongInLeg) {
            return point
        }
        return userLocation?.coordinate
    }

    func confirmBoarded() {
        guard phase == .waiting else { return }
        HapticFeedback.lightImpact()
        board()
    }

    func skipToNextStep() {
        HapticFeedback.lightImpact()
        if phase == .waiting {
            board()
        } else {
            completeLeg()
        }
    }

    func requestNotificationPermission() {
        announcer.prepare()
    }

    func tick() {
        guard isRunning else { return }
        now = Date()
        if let replan, now >= replan.autoApplyAt {
            acceptReplan()
        }
        catchUpWithVehicle()
        updateEstimates()
        if let lastFixAt, now.timeIntervalSince(lastFixAt) > 45 {
            assign(\.hasWeakGPS, true)
        } else if lastFixAt == nil, now.timeIntervalSince(legs.first?.startTime ?? now) > 0 {
            assign(\.hasWeakGPS, true)
        }
        evaluate()
    }

    deinit {
        arrivalTask?.cancel()
        tickTask?.cancel()
        crowdAckTask?.cancel()
        alertDismissTask?.cancel()
        rerouteTask?.cancel()
    }
}

extension String {
    var capitalizedFirstLetter: String { prefix(1).uppercased() + dropFirst() }
    var lowercasedFirstLetter: String { prefix(1).lowercased() + dropFirst() }
}

extension Color {
    var hexString: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02X%02X%02X", Int(max(0, min(1, red)) * 255), Int(max(0, min(1, green)) * 255), Int(max(0, min(1, blue)) * 255))
    }
}
