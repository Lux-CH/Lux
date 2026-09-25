//
//  OnboardSession+Crowd.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import MapKit
import LuxCom

extension OnboardSession {
    func setSharing(_ enabled: Bool) {
        Settings.shared.onboardCrowdConsent = enabled ? .granted : .declined
        isSharingPosition = enabled
        if !enabled {
            crowdStatus = nil
            enqueueRelay { await RelayClient.shared.stopOnboardReports() }
        } else {
            lastCrowdReportAt = .distantPast
        }
    }

    var canReportRide: Bool {
        guard Settings.shared.crowdbackAllowed, phase == .riding, let leg = currentLeg else { return false }
        return leg.tripId != nil && leg.routeShortName != nil
    }

    func reportRide(_ attribute: ReportAttribute, level: Int) {
        guard canReportRide, let leg = currentLeg, let tripId = leg.tripId, let line = leg.routeShortName,
              let coordinate = userLocation?.coordinate else { return }
        rideReports[attribute] = level
        let report = Report(
            tripId: tripId,
            routeShortName: line,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            attribute: attribute,
            level: level
        )
        Task { [weak self] in
            _ = try? await sendLCBReport(report: report)
            await self?.refreshRideInfo()
        }
    }

    func dismissCrowdPrompt() {
        withAnimation(.spring(duration: 0.4)) { showsCrowdPrompt = false }
    }

    func startRideInfo() {
        rideInfoTask?.cancel()
        rideInfo = nil
        guard Settings.shared.crowdbackAllowed, !OfflineRouter.shared.isOfflineActive else { return }
        rideInfoTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshRideInfo()
                try? await Task.sleep(for: .seconds(120))
            }
        }
    }

    func refreshRideInfo() async {
        guard let leg = currentLeg, leg.isTransit, let tripId = leg.tripId, let line = leg.routeShortName else { return }
        let coordinate = userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: leg.from.lat, longitude: leg.from.lon)
        let info = try? await getLCBInfo(tripId: tripId, routeShortName: line, latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard !Task.isCancelled, currentLeg?.tripId == tripId else { return }
        rideInfo = info
    }

    func scheduleCrowdPrompt() {
        crowdPromptTask?.cancel()
        let index = legIndex
        guard Settings.shared.crowdbackAllowed, !promptedLegs.contains(index) else { return }
        crowdPromptTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard let self, !Task.isCancelled, self.legIndex == index, self.canReportRide,
                  self.rideReports[.crowd] == nil, self.stopsRemaining > 1 else { return }
            self.promptedLegs.insert(index)
            withAnimation(.spring(duration: 0.45)) { self.showsCrowdPrompt = true }
            try? await Task.sleep(for: .seconds(45))
            if !Task.isCancelled { self.dismissCrowdPrompt() }
        }
    }

    func reportCrowdPosition(leg: Leg, offsetOK: Bool) {
        guard isSharingPosition,
              !leg.mode.isMainlineRail,
              !OfflineRouter.shared.isOfflineActive,
              offsetOK,
              let tripId = leg.tripId, !tripId.isEmpty,
              let location = usableLocation, location.horizontalAccuracy <= 50,
              now.timeIntervalSince(lastCrowdReportAt) >= crowdReportInterval else { return }
        lastCrowdReportAt = now
        let coordinate = location.coordinate
        let board = boarding.flatMap { $0.legIndex == legIndex ? $0 : nil }
        let accuracy = location.horizontalAccuracy
        let speed = location.speed >= 0 ? location.speed : nil
        let timestamp = location.timestamp
        Task {
            await RelayClient.shared.reportOnboardPosition(
                tripId: tripId,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                accuracy: accuracy,
                speed: speed,
                boardStopId: board?.stopId,
                boardedAt: board?.at,
                timestamp: timestamp
            )
        }
    }

    func startCrowdAcks() {
        crowdAckTask = Task { [weak self] in
            let acks = await RelayClient.shared.crowdAcks()
            for await ack in acks {
                guard let self, !Task.isCancelled else { return }
                guard ack.tripId == self.currentLeg?.tripId, self.phase == .riding else { continue }
                if let watched = ack.watched, watched != self.crowdWatched {
                    self.crowdWatched = watched
                    if watched { self.lastCrowdReportAt = .distantPast }
                }
                let state: CrowdStatus.State?
                switch ack.status {
                case "ok": state = .contributing(riders: ack.riders ?? 1, delaySeconds: ack.delay ?? 0)
                case "learning": state = .learning
                case "unverified":
                    state = .unverified
                    if let likely = ack.likelyTripId {
                        self.retargetCurrentLeg(to: likely)
                    }
                default: state = nil
                }
                if let state { self.crowdStatus = CrowdStatus(state: state) }
            }
        }
    }
}
