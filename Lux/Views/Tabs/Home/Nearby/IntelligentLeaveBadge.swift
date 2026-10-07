//
//  IntelligentLeaveBadge.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import SwiftUI
import LuxCom

struct IntelligentLeaveBadge: View {
    let pick: NearbyIntelligence.Pick

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        let leaveIn = Int((pick.leaveAt.timeIntervalSince(now) / 60).rounded(.down))
        let tint = leaveIn <= 0 ? Color.orange : Color.luxAccent
        return HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .bold))
            Text(leaveIn <= 0 ? String(localized: "Partez") : String(localized: "\(leaveIn) min"))
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
            if let weather = pick.weather, weather.isHarsh {
                Image(systemName: weather.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 9))
            }
            if let crowd = pick.crowd, crowd >= 3.5 {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(ReportAttribute.crowd.color(for: crowd))
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(tint.opacity(0.14), in: Capsule())
        .fixedSize()
        .animation(.snappy, value: leaveIn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(leaveIn <= 0
            ? String(localized: "Magic : partez maintenant, \(pick.walkMinutes) min à pied")
            : String(localized: "Magic : partez dans \(leaveIn) min, \(pick.walkMinutes) min à pied"))
    }
}
