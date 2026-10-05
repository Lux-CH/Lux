//
//  OnboardSession+Platform.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import SwiftUI
import CoreLocation
import LuxCom

struct PlatformAdvice: Equatable {
    let alightName: String
    let exitSector: String
    let exitKind: StationLayout.Access.Kind?
    let boardSector: String?
    let coach: String?
    let busyTrain: Bool
}

extension OnboardSession {
    func refreshPlatformAdvice() {
        var target = ""
        var plan: (index: Int, leg: Leg)?
        if IntelligenceStore.isIntelligentMode, !OfflineRouter.shared.isOfflineActive {
            if phase == .riding, let leg = currentLeg, leg.isTransit {
                plan = (legIndex, leg)
            } else if phase == .walking || phase == .waiting {
                plan = nextTransitLeg
            }
        }
        if let plan, plan.leg.mode.isMainlineRail, let tripId = plan.leg.tripId, let alight = plan.leg.to.stopId {
            target = "\(tripId)|\(alight)|\(plan.leg.to.track ?? plan.leg.to.scheduledTrack ?? "")|\(phase == .riding)|\(formation?.coaches.count ?? 0)"
        }
        guard target != platformAdviceTarget else { return }
        let sameLeg = target.split(separator: "|").prefix(3) == platformAdviceTarget.split(separator: "|").prefix(3)
        platformAdviceTarget = target
        platformAdviceTask?.cancel()
        if !sameLeg, platformAdvice != nil {
            withAnimation { platformAdvice = nil }
        }
        guard let plan, !target.isEmpty else {
            if platformAdvice != nil { withAnimation { platformAdvice = nil } }
            return
        }

        let leg = plan.leg
        let index = plan.index
        let tripId = leg.tripId ?? ""
        let alightStopId = leg.to.stopId ?? ""
        let alightName = placeName(leg.to)
        let goal = exitGoal(after: index)
        let wantsElevator = UserDefaults.standard.string(forKey: "routeOptionsPedestrianProfile") == PedestrianProfile.wheelchair.rawValue
        let boardFormation = phase == .riding ? nil : formation
        let avoidsCrowds = IntelligenceStore.shared.profile.crowd != .indifferent

        platformAdviceTask = Task { [weak self] in
            guard let goal,
                  let layout = await StationLayoutStore.shared.layout(for: alightStopId),
                  let track = layout.track(named: leg.to.track ?? leg.to.scheduledTrack, stopId: alightStopId),
                  !track.sectors.isEmpty else { return }

            func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
                CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            }

            let nearPlatform = (layout.access ?? []).filter { access in
                (!wantsElevator || access.kind == .elevator)
                    && track.sectors.contains { distance($0.coordinate, access.coordinate) < 45 }
            }
            let exit = nearPlatform.min { distance($0.coordinate, goal) < distance($1.coordinate, goal) }
            let exitPoint = exit?.coordinate ?? goal
            guard let exitSector = track.sectors.min(by: { distance($0.coordinate, exitPoint) < distance($1.coordinate, exitPoint) })?.s else { return }

            var boardSector: String?
            var coachNumber: String?
            if let boardFormation, !boardFormation.coaches.isEmpty {
                var alightFormation: TrainFormation?
                for await value in await RelayClient.shared.formation(tripId: tripId, stopId: alightStopId) {
                    alightFormation = value
                    break
                }
                if let alightFormation {
                    let usable = alightFormation.coaches.filter { !$0.isLocomotive && !$0.closed && $0.s == exitSector }
                    let coach = usable.first { !$0.isFirstClass && !$0.isRestaurant } ?? usable.first
                    if let coach {
                        if let number = coach.n, let boardCoach = boardFormation.coaches.first(where: { $0.n == number }) {
                            boardSector = boardCoach.s
                            coachNumber = number
                        }
                    }
                }
            }

            let occupancy = (boardFormation?.occupancy?.second ?? boardFormation?.occupancy?.first) ?? 0
            let advice = PlatformAdvice(
                alightName: alightName,
                exitSector: exitSector,
                exitKind: exit?.kind,
                boardSector: boardSector,
                coach: coachNumber,
                busyTrain: avoidsCrowds && occupancy >= 2
            )
            guard let self, !Task.isCancelled, self.platformAdviceTarget == target else { return }
            withAnimation(.snappy) { self.platformAdvice = advice }
        }
    }

    private func exitGoal(after index: Int) -> CLLocationCoordinate2D? {
        let next = index + 1
        guard next < legs.count else { return nil }
        if legs[next].isTransit {
            return CLLocationCoordinate2D(latitude: legs[next].from.lat, longitude: legs[next].from.lon)
        }
        let path = paths[next]
        guard !path.isEmpty else {
            return CLLocationCoordinate2D(latitude: legs[next].to.lat, longitude: legs[next].to.lon)
        }
        let along = min(120, path.length)
        guard let segment = path.cumulative.firstIndex(where: { $0 >= along }) else { return path.coordinates.last }
        return path.coordinates[segment]
    }
}
