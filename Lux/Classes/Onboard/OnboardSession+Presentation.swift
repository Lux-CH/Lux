//
//  OnboardSession+Presentation.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import MapKit
import LuxCom

extension OnboardSession {
    func dismissAlert() {
        withAnimation(.spring(duration: 0.35)) { alert = nil }
    }

    func showAlert(_ alert: OnboardAlert, spoken: String?, urgency: OnboardAnnouncer.Urgency, persistent: Bool = false) {
        withAnimation(.spring(duration: 0.4)) { self.alert = alert }
        if let spoken {
            announcer.announce(spoken, notificationTitle: alert.title, urgency: urgency)
        }
        alertDismissTask?.cancel()
        alertDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(persistent ? 25 : 8))
            guard !Task.isCancelled, let self, self.alert == alert else { return }
            self.dismissAlert()
        }
    }

    func startAnnouncement() -> String {
        switch phase {
        case .walking:
            if let leg = currentLeg {
                return String(localized: "C'est parti. Marchez jusqu'à \(placeName(leg.to, isDestination: legIndex == legs.count - 1)).")
            }
        case .waiting:
            if let leg = currentLeg {
                return String(localized: "C'est parti. Prenez \(leg.spokenLineName), départ à \(formatTime(leg.startTime)).")
            }
        case .riding:
            if let leg = currentLeg {
                return String(localized: "C'est parti. Descendez à \(placeName(leg.to)).")
            }
        case .arrived:
            break
        }
        return String(localized: "C'est parti.")
    }

    func activityState() -> OnboardActivityAttributes.ContentState {
        let leg = currentLeg
        var state = OnboardActivityAttributes.ContentState(
            phase: .walking,
            title: "",
            subtitle: "",
            symbolName: "figure.walk",
            arrivalDate: arrivalDate,
            progress: legProgress,
            vehicleIsLive: false,
            isUrgent: false
        )

        func describe(_ leg: Leg) {
            state.line = leg.routeShortName
            state.lineMode = leg.mode.rawValue
            state.lineAgency = leg.agencyId
            state.lineColorHex = getLegColor(leg).hexString
            state.headsign = leg.headsign
        }

        switch phase {
        case .arrived:
            state.phase = .arrived
            state.title = String(localized: "Vous êtes arrivé")
            state.subtitle = destinationName
            state.symbolName = "checkmark"
            state.progress = 1
        case .walking:
            state.phase = .walking
            if isOffRoute {
                state.title = String(localized: "Recalcul de l'itinéraire…")
                state.symbolName = "arrow.triangle.turn.up.right.diamond.fill"
            } else if let maneuver = nextManeuver {
                state.title = maneuver.instruction
                state.symbolName = maneuver.symbolName
            } else if let leg {
                state.title = String(localized: "Marchez jusqu'à \(placeName(leg.to, isDestination: legIndex == legs.count - 1))")
                state.symbolName = "figure.walk"
            }
            state.distanceMeters = distanceToManeuver
            if let next = nextTransitLeg?.leg {
                describe(next)
                state.targetDate = next.startTime
                state.delayMinutes = next.departureDelayMinutes
                state.subtitle = placeName(next.from)
            } else {
                state.subtitle = destinationName
            }
        case .waiting:
            state.phase = .waiting
            if let leg {
                describe(leg)
                state.title = placeName(leg.from)
                state.subtitle = leg.from.track.map { getTrackType($0) } ?? ""
                state.symbolName = leg.mode.symbolName
                state.targetDate = leg.startTime
                state.delayMinutes = leg.departureDelayMinutes
            }
        case .riding:
            state.phase = .riding
            if let leg {
                describe(leg)
                let stops = leg.allStops
                state.title = placeName(leg.to)
                state.subtitle = stopsRemaining > 1 && nextStopIndex < stops.count
                    ? String(localized: "Prochain arrêt : \(stops[nextStopIndex].name)")
                    : String(localized: "Descendez au prochain arrêt")
                state.symbolName = leg.mode.symbolName
                state.targetDate = currentLegArrival
                state.delayMinutes = currentLegDelayMinutes
                state.stopsRemaining = stopsRemaining
                state.totalStops = stops.count
                state.passedStops = min(stops.count, nextStopIndex)
                state.progress = stopProgress
                if followsTimetable || hasWeakGPS, let segment = currentSegmentTimes {
                    state.segmentStart = segment.start
                    state.segmentEnd = segment.end
                }
                state.fromName = placeName(leg.from)
                state.toName = placeName(leg.to)
                state.isUrgent = stopsRemaining <= 1
                state.vehicleIsLive = isSharingPosition && crowdStatus != nil
            }
        }

        if let target = state.targetDate {
            let seconds = target.timeIntervalSince(now)
            state.countdownMinutes = seconds >= 60 ? Int((seconds / 60).rounded(.up)) : 0
        }

        if phase == .walking || phase == .waiting, approachingVehicle != nil {
            state.vehicleIsLive = true
            state.vehicleDistanceMeters = approachingVehicleDistance
        }
        return state
    }
}
