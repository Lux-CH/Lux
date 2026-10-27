//
//  BikeLegView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.10.2026.
//

import SwiftUI
import CoreLocation
import LuxCom

struct BikeLegView: View {
    let leg: Leg
    let isLast: Bool
    let destinationName: String?
    @State private var isExpanded = false
    @Environment(\.openURL) private var openURL

    private struct Turn: Identifiable {
        let id: Int
        let maneuver: WalkManeuver
        let distance: Double
    }

    private var turns: [Turn] {
        let path = RoutePath(
            encoded: leg.legGeometry.points,
            fallback: [
                CLLocationCoordinate2D(latitude: leg.from.lat, longitude: leg.from.lon),
                CLLocationCoordinate2D(latitude: leg.to.lat, longitude: leg.to.lon)
            ]
        )
        let maneuvers = WalkManeuverBuilder.maneuvers(for: leg.steps ?? [], on: path)
        return maneuvers.enumerated().map { index, maneuver in
            let next = index + 1 < maneuvers.count ? maneuvers[index + 1].along : path.length
            return Turn(id: index, maneuver: maneuver, distance: max(0, next - maneuver.along))
        }
    }

    private var networkName: String {
        leg.rental?.systemName ?? leg.rental?.providerId ?? String(localized: "partagé")
    }

    private var networkColor: Color {
        leg.rental?.color.map { Color(hex: $0) } ?? .bikeLeg
    }

    private var pickupName: String? {
        guard let rental = leg.rental else { return nil }
        let name = rental.fromStationName ?? leg.from.name
        return name.isEmpty || name == rental.systemName ? nil : name
    }

    private var destination: String {
        if isLast, leg.to.name == "END" || leg.to.name.isEmpty {
            return destinationName ?? String(localized: "votre destination")
        }
        return leg.to.name
    }

    private var returnStation: String? {
        guard let rental = leg.rental, rental.returnsToStation else { return nil }
        let name = rental.toStationName ?? leg.to.name
        return name.isEmpty || name == "END" ? nil : name
    }

    private var title: Text {
        if leg.rental != nil {
            if let pickupName {
                return Text("Prenez un vélo \(networkName) à \(Image(systemName: "signpost.right")) \(pickupName)")
            }
            return Text("Prenez un vélo \(networkName) à proximité")
        }
        return Text("Pédalez jusqu'à \(Image(systemName: "signpost.right")) \(destination)")
    }

    private var appURL: URL? {
        guard let rental = leg.rental else { return nil }
        return [rental.rentalUriIOS, rental.rentalUriWeb, rental.url]
            .compactMap { $0 }
            .first { !$0.isEmpty }
            .flatMap(URL.init(string:))
    }

    var body: some View {
        let turns = turns
        VStack(spacing: 0) {
            Button {
                guard !turns.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.bikeLeg.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: leg.bikeSymbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.bikeLeg)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        title
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 4) {
                            Text(formatDistance(leg.distance ?? 0))
                            Text("•").foregroundColor(.gray)
                            Text("\(max(1, leg.duration / 60)) min")
                            if leg.rental?.isElectric == true {
                                Text("•").foregroundColor(.gray)
                                Label("Électrique", systemImage: "bolt.fill")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundStyle(Color.bikeLeg)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !turns.isEmpty {
                        HStack(spacing: 4) {
                            Text("Détails")
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .regular))
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .foregroundColor(.bikeLeg)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .allowsHitTesting(!turns.isEmpty)

            if let rental = leg.rental {
                rentalCard(rental)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }

            if isExpanded && !turns.isEmpty {
                turnList(turns)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }

            Divider()
                .padding(.horizontal, 20)
        }
    }

    private func rentalCard(_ rental: Rental) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: rental.returnsToStation ? "parkingsign.circle.fill" : "mappin.and.ellipse")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bikeLeg)
                    .frame(width: 24)

                Group {
                    if let station = returnStation {
                        Text("Rendez-le à \(Image(systemName: "signpost.right")) \(station)")
                    } else {
                        Text("Garez-le dans la zone \(networkName)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

                Spacer(minLength: 0)
            }

            if let appURL {
                Button {
                    HapticFeedback.lightImpact()
                    openURL(appURL)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(networkColor)
                            .frame(width: 8, height: 8)
                        Text("Ouvrir \(networkName)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.bikeLeg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.bikeLeg.opacity(0.14))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bikeLeg.opacity(0.06))
        )
    }

    private func turnList(_ turns: [Turn]) -> some View {
        VStack(spacing: 0) {
            ForEach(turns) { turn in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: turn.maneuver.symbolName)
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 24, height: 24)
                        .background(Color.bikeLeg)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(turn.maneuver.instruction)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)

                        if turn.distance >= 10 {
                            Text(formatDistance(turn.distance))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 20)

                if turn.id < turns.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                        .padding(.trailing, 20)
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.bikeLeg.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}
