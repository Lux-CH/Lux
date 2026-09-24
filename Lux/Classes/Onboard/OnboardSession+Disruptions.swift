//
//  OnboardSession+Disruptions.swift
//  Lux
//
//  Created by Constantin Clerc on 24.09.2026.
//

import SwiftUI
import LuxCom

struct LegDisruption: Identifiable, Equatable {
    let legIndex: Int
    let leg: Leg
    let disruption: Disruption

    var id: String { disruption.id }

    static func == (lhs: LegDisruption, rhs: LegDisruption) -> Bool {
        lhs.legIndex == rhs.legIndex && lhs.disruption == rhs.disruption
    }
}

extension OnboardSession {
    var endsWithButton: Bool {
        phase == .waiting || (phase != .arrived && !legDisruptions.isEmpty)
    }

    var disruptionGroups: [DisruptionGroup] {
        Dictionary(grouping: legDisruptions, by: \.legIndex)
            .sorted { $0.key < $1.key }
            .map { index, items in DisruptionGroup(id: "\(index)", leg: items.first?.leg, disruptions: items.map(\.disruption)) }
    }

    func updateDisruptions(_ all: [Disruption]) {
        knownDisruptions = all
        refreshDisruptions()
    }

    func refreshDisruptions() {
        guard phase != .arrived else {
            if !legDisruptions.isEmpty { withAnimation { legDisruptions = [] } }
            return
        }
        guard let knownDisruptions else { return }
        var seen: Set<String> = []
        var found: [LegDisruption] = []
        for index in legIndex..<legs.count where legs[index].isTransit {
            for disruption in DisruptionManager.matching(knownDisruptions, leg: legs[index]) where seen.insert(disruption.id).inserted {
                found.append(LegDisruption(legIndex: index, leg: legs[index], disruption: disruption))
            }
        }
        if found != legDisruptions {
            withAnimation(.spring(duration: 0.4)) { legDisruptions = found }
        }

        guard let announced = announcedDisruptionIds else {
            announcedDisruptionIds = seen
            return
        }
        if let fresh = found.first(where: { !announced.contains($0.id) }) {
            let line = fresh.leg.routeShortName ?? fresh.leg.spokenLineName
            showAlert(
                OnboardAlert(
                    severity: .warning,
                    symbolName: "exclamationmark.triangle.fill",
                    title: "\(line) · \(fresh.disruption.shortTitle)",
                    message: fresh.disruption.summary
                ),
                spoken: String(localized: "Perturbation sur \(fresh.leg.spokenLineName)."),
                urgency: .notice,
                persistent: true
            )
        }
        announcedDisruptionIds = announced.union(seen)
    }
}
