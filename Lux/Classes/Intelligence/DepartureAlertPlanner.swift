//
//  DepartureAlertPlanner.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import Foundation
import CoreLocation
import EventKit
import UserNotifications
import BackgroundTasks
import LuxCom

@MainActor
final class DepartureAlertPlanner {
    static let shared = DepartureAlertPlanner()
    static let taskIdentifier = "ch.cclerc.luxapp.departure-alerts"

    private struct Target {
        let id: String
        let name: String
        let destination: CLLocationCoordinate2D
        let stopId: String?
        let time: Date
        let arriveBy: Bool
    }

    private let identifierPrefix = "intelligent-departure-"
    private let horizon: TimeInterval = 2 * 3600
    private let maxAlerts = 8
    private let locationManager = CLLocationManager()
    private var refreshTask: Task<Void, Never>?
    private var lastRefresh = Date.distantPast

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                let work = Task { await DepartureAlertPlanner.shared.plan() }
                task.expirationHandler = { work.cancel() }
                await work.value
                DepartureAlertPlanner.shared.scheduleBackgroundRefresh()
                task.setTaskCompleted(success: !work.isCancelled)
            }
        }
    }

    func setEnabled(_ enabled: Bool) async {
        IntelligenceStore.shared.departureAlerts = enabled
        if enabled {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            refresh(force: true)
        } else {
            refreshTask?.cancel()
            await clearPending()
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        }
    }

    func refresh(force: Bool = false) {
        guard IntelligenceStore.shared.departureAlerts else { return }
        guard force || Date().timeIntervalSince(lastRefresh) > 10 * 60 else { return }
        lastRefresh = Date()
        refreshTask?.cancel()
        refreshTask = Task { await plan() }
        scheduleBackgroundRefresh()
    }

    func scheduleBackgroundRefresh() {
        guard IntelligenceStore.shared.departureAlerts else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(45 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func plan() async {
        guard IntelligenceStore.shared.departureAlerts else { return }
        guard !OfflineRouter.shared.isOfflineActive,
              let location = locationManager.location,
              -location.timestamp.timeIntervalSinceNow < 15 * 60 else {
            await clearPending()
            return
        }
        let origin = location.coordinate

        let now = Date()
        let underway = OnboardSession.active.flatMap { $0.isRunning ? $0.finalDestination : nil }
        func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
            CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        }
        let targets = (shortcutTargets(now: now) + calendarTargets(now: now))
            .filter { distance($0.destination, origin) > 500 }
            .filter { target in underway.map { distance(target.destination, $0) > 500 } ?? true }
            .sorted { $0.time < $1.time }
            .prefix(maxAlerts)

        var requests: [UNNotificationRequest] = []
        for target in targets {
            guard !Task.isCancelled else { return }
            if let request = await request(for: target, from: origin, now: now) {
                requests.append(request)
            }
        }
        guard !Task.isCancelled else { return }
        await clearPending()
        let center = UNUserNotificationCenter.current()
        for request in requests {
            try? await center.add(request)
        }
    }

    private func request(for target: Target, from origin: CLLocationCoordinate2D, now: Date) async -> UNNotificationRequest? {
        let destination = target.stopId.map { RouteOptions.RouteLocation(stopId: $0) }
            ?? RouteOptions.RouteLocation(coordinates: (target.destination.latitude, target.destination.longitude))
        let base = OnboardSession.savedRouteOptions(
            from: RouteOptions.RouteLocation(coordinates: (origin.latitude, origin.longitude)),
            to: destination,
            time: target.arriveBy ? target.time : target.time.addingTimeInterval(-10 * 60)
        )
        let options = RouteOptions(
            from: base.from, to: base.to, via: nil, viaMinimumStay: [], time: base.time,
            arriveBy: target.arriveBy, maxTransfers: base.maxTransfers, minTransferTime: base.minTransferTime,
            pedestrianProfile: base.pedestrianProfile, pedestrianSpeed: base.pedestrianSpeed, transitModes: base.transitModes,
            numItineraries: 5, timetableView: true, maxPreTransitTime: base.maxPreTransitTime, maxPostTransitTime: base.maxPostTransitTime
        )
        guard let trip = try? await LuxData.route(options) else { return nil }

        let candidates = (trip.itineraries + trip.direct).filter { itinerary in
            if target.arriveBy { return itinerary.endTime <= target.time.addingTimeInterval(60) }
            return itinerary.startTime >= target.time.addingTimeInterval(-10 * 60) && itinerary.startTime <= target.time.addingTimeInterval(25 * 60)
        }
        let weather = await WeatherService.shared.snapshot(latitude: origin.latitude, longitude: origin.longitude, at: target.time)
        let context = TripIntelligence.Context(weather: weather, arriveBy: target.arriveBy, crowd: [:])
        guard let suggestion = TripIntelligence.suggest(from: candidates, context: context) else { return nil }

        let itinerary = suggestion.itinerary
        let fireAt = itinerary.startTime.addingTimeInterval(target.arriveBy ? -5 * 60 : -3 * 60)
        guard fireAt > now.addingTimeInterval(60) else { return nil }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Partez maintenant pour \(target.name)")
        var body: String
        if let transit = itinerary.legs.first(where: \.isTransit) {
            let line = transit.routeShortName ?? ""
            body = String(localized: "Prenez \(line) à \(formatTime(transit.startTime)) depuis \(transit.from.name), arrivée à \(formatTime(itinerary.endTime)).")
        } else {
            body = String(localized: "À pied, arrivée à \(formatTime(itinerary.endTime)).")
        }
        let isFastest = suggestion.chosen.itinerary.intelligenceSignature == suggestion.fastest.itinerary.intelligenceSignature
        if !isFastest, let reason = suggestion.reasons.first {
            body += " " + reason.text + "."
        }
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "intelligent-departure"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifierPrefix + target.id, content: content, trigger: trigger)
    }

    private func shortcutTargets(now: Date) -> [Target] {
        let calendar = Calendar.current
        return ShortcutStorage().loadShortcuts().flatMap { shortcut -> [Target] in
            guard let schedule = shortcut.timeSchedule else { return [] }
            return (0...1).compactMap { offset -> Target? in
                guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
                let weekday = calendar.component(.weekday, from: day)
                guard schedule.daysOfWeek.contains(where: { $0.rawValue % 7 + 1 == weekday }),
                      let time = calendar.date(bySettingHour: schedule.time.hour, minute: schedule.time.minute, second: 0, of: day),
                      time > now.addingTimeInterval(10 * 60), time < now.addingTimeInterval(horizon) else { return nil }
                return Target(
                    id: "shortcut-\(shortcut.id.uuidString)-\(Int(time.timeIntervalSince1970))",
                    name: shortcut.name,
                    destination: CLLocationCoordinate2D(latitude: shortcut.coordinates.latitude, longitude: shortcut.coordinates.longitude),
                    stopId: shortcut.stopId,
                    time: time,
                    arriveBy: false
                )
            }
        }
    }

    private func calendarTargets(now: Date) -> [Target] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let store = EKEventStore()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(20 * 60), end: now.addingTimeInterval(horizon), calendars: nil)
        return store.events(matching: predicate).compactMap { event in
            guard !event.isAllDay, event.calendar.title != "Itinéraires Lux",
                  let location = event.structuredLocation?.geoLocation else { return nil }
            return Target(
                id: "event-\(event.eventIdentifier ?? UUID().uuidString)-\(Int(event.startDate.timeIntervalSince1970))",
                name: event.title ?? String(localized: "votre rendez-vous"),
                destination: location.coordinate,
                stopId: nil,
                time: event.startDate.addingTimeInterval(-5 * 60),
                arriveBy: true
            )
        }
    }

    private func clearPending() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) })
    }
}
