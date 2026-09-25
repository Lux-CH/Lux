//
//  OnboardLiveActivityController.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import ActivityKit
import Foundation

@MainActor
final class OnboardLiveActivityController {
    private var activity: Activity<OnboardActivityAttributes>?
    private var lastState: OnboardActivityAttributes.ContentState?
    private var lastPush: Date = .distantPast
    private static let staleAfter: TimeInterval = 180
    private static let refreshAfter: TimeInterval = 60

    func start(destinationName: String, state: OnboardActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, activity == nil else { return }
        for stale in Activity<OnboardActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
        do {
            activity = try Activity.request(
                attributes: OnboardActivityAttributes(destinationName: destinationName),
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(Self.staleAfter)),
                pushType: nil
            )
            lastState = state
            lastPush = Date()
        } catch {
            print("onboard live activity failed: \(error.localizedDescription)")
        }
    }

    func update(_ state: OnboardActivityAttributes.ContentState, alert: (title: String, body: String)? = nil) {
        let needsRefresh = Date().timeIntervalSince(lastPush) >= Self.refreshAfter
        guard let activity, state != lastState || alert != nil || needsRefresh else { return }
        if alert == nil, !needsRefresh, let lastState, isMinorChange(from: lastState, to: state) {
            let progressMoved = abs(lastState.progress - state.progress) >= 0.02
            let sinceLastPush = Date().timeIntervalSince(lastPush)
            guard (progressMoved && sinceLastPush >= 5) || sinceLastPush >= 15 else { return }
        }
        lastState = state
        lastPush = Date()

        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(Self.staleAfter))
        let alertConfiguration = alert.map {
            AlertConfiguration(title: LocalizedStringResource(stringLiteral: $0.title), body: LocalizedStringResource(stringLiteral: $0.body), sound: .default)
        }
        Task { await activity.update(content, alertConfiguration: alertConfiguration) }
    }

    var isActive: Bool { activity != nil }

    nonisolated static func endAll() {
        for activity in Activity<OnboardActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    nonisolated static func endAllBeforeTermination() {
        let activities = Activity<OnboardActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 2)
    }

    func end(finalState: OnboardActivityAttributes.ContentState?) {
        guard let activity else { return }
        self.activity = nil
        let content = finalState.map { ActivityContent(state: $0, staleDate: nil) }
        Task { await activity.end(content, dismissalPolicy: finalState?.phase == .arrived ? .after(.now + 120) : .immediate) }
    }

    private func isMinorChange(from old: OnboardActivityAttributes.ContentState, to new: OnboardActivityAttributes.ContentState) -> Bool {
        old.phase == new.phase
            && old.title == new.title
            && old.subtitle == new.subtitle
            && old.stopsRemaining == new.stopsRemaining
            && old.delayMinutes == new.delayMinutes
            && old.isUrgent == new.isUrgent
            && old.vehicleIsLive == new.vehicleIsLive
            && abs((old.distanceMeters ?? 0) - (new.distanceMeters ?? 0)) < 25
            && old.passedStops == new.passedStops
            && old.countdownMinutes == new.countdownMinutes
            && old.segmentStart == new.segmentStart
            && old.segmentEnd == new.segmentEnd
            && abs((old.targetDate ?? .distantPast).timeIntervalSince(new.targetDate ?? .distantPast)) < 30
    }
}
