//
//  TrainFormationView.swift
//  Lux
//
//  Created by Constantin Clerc on 24.09.2026.
//

import SwiftUI

/// Where to stand on the platform: the train's coaches in platform order under their
/// sector letters (1st class with SBB's yellow band), and where 1st / 2nd class, the
/// restaurant, bikes and wheelchair spaces are.
struct TrainFormationView: View {
    let formation: TrainFormation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(formation.coaches.enumerated()), id: \.offset) { index, coach in
                        VStack(spacing: 3) {
                            Text(startsSector(at: index) ? coach.s ?? "" : " ")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.secondary)
                            CoachView(coach: coach)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            summary
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private func startsSector(at index: Int) -> Bool {
        index == 0 || formation.coaches[index - 1].s != formation.coaches[index].s
    }

    private var summary: some View {
        let sectors = formation.sectors
        let items: [(icon: String?, label: String?, sectors: [String])] = [
            (nil, String(localized: "1re"), sectors.first),
            (nil, String(localized: "2e"), sectors.second),
            ("fork.knife", nil, sectors.restaurant),
            ("bicycle", nil, sectors.bike),
            ("figure.roll", nil, sectors.wheelchair),
        ]
        return HStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                if !item.sectors.isEmpty {
                    HStack(spacing: 3) {
                        if let icon = item.icon {
                            Image(systemName: icon)
                        }
                        if let label = item.label {
                            Text(label).fontWeight(.bold)
                        }
                        Text(TrainFormation.sectorText(item.sectors))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var accessibilityText: String {
        let sectors = formation.sectors
        var parts: [String] = []
        if !sectors.first.isEmpty {
            parts.append(String(localized: "1re classe secteur \(TrainFormation.sectorText(sectors.first))"))
        }
        if !sectors.second.isEmpty {
            parts.append(String(localized: "2e classe secteur \(TrainFormation.sectorText(sectors.second))"))
        }
        if !sectors.restaurant.isEmpty {
            parts.append(String(localized: "restaurant secteur \(TrainFormation.sectorText(sectors.restaurant))"))
        }
        if !sectors.bike.isEmpty {
            parts.append(String(localized: "vélos secteur \(TrainFormation.sectorText(sectors.bike))"))
        }
        if !sectors.wheelchair.isEmpty {
            parts.append(String(localized: "fauteuils roulants secteur \(TrainFormation.sectorText(sectors.wheelchair))"))
        }
        return parts.joined(separator: ", ")
    }
}

private struct CoachView: View {
    let coach: TrainFormation.Coach

    private static let firstClassYellow = Color(red: 0.99, green: 0.8, blue: 0.1)

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: coach.isLocomotive ? 7 : 4, style: .continuous)
                    .fill(coach.isLocomotive ? Color.secondary.opacity(0.35) : Color(.tertiarySystemFill))
                if coach.isFirstClass {
                    Self.firstClassYellow
                        .frame(height: 4)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous))
                }
                label
                    .frame(maxHeight: .infinity)
            }
            .frame(width: coach.isLocomotive ? 18 : 26, height: 22)
            .opacity(coach.closed ? 0.35 : 1)

            HStack(spacing: 1) {
                if coach.o.contains("bike") { Image(systemName: "bicycle") }
                if coach.o.contains("wheelchair") { Image(systemName: "figure.roll") }
            }
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(height: 8)
        }
    }

    @ViewBuilder
    private var label: some View {
        if coach.isLocomotive {
            EmptyView()
        } else if coach.isRestaurant {
            Image(systemName: "fork.knife")
                .font(.system(size: 10, weight: .bold))
        } else if coach.t == "FA" {
            Image(systemName: "figure.2.and.child.holdinghands")
                .font(.system(size: 10, weight: .bold))
        } else {
            Text(coach.t == "12" ? "1·2" : coach.t)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
    }
}

/// A sector letter on the boarding platform: solid where the train stops, faded where it
/// doesn't, with the 1st-class yellow band where 1st class stops.
struct SectorChipView: View {
    let letter: String
    /// nil while the formation isn't known.
    let covered: Bool?
    let firstClass: Bool

    var body: some View {
        Text(letter)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(StationStyle.signBlue)
            .frame(width: 17, height: 17)
            .background(Circle().fill(.white))
            .overlay(alignment: .top) {
                if firstClass {
                    Circle()
                        .trim(from: 0.6, to: 0.9)
                        .stroke(Color(red: 0.99, green: 0.8, blue: 0.1), lineWidth: 3)
                        .frame(width: 17, height: 17)
                }
            }
            .overlay(Circle().stroke(StationStyle.signBlue, lineWidth: 1.2))
            .opacity(covered == false ? 0.4 : 1)
            .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
            .environment(\.colorScheme, .light)
            .accessibilityLabel(Text(String(localized: "Secteur \(letter)")))
    }
}
