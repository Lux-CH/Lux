//
//  LiveShareViews.swift
//  Lux
//
//  Created by Constantin Clerc on 14.10.2026.
//

import SwiftUI
import LuxCom

struct LiveShareOverlay: View {
    let follower: LiveShareFollower
    @ObservedObject var viewModel: ItineraryViewModel
    let onFocus: () -> Void
    @State private var hasFocused = false

    var body: some View {
        LiveShareBanner(
            state: follower.state,
            waitedOut: follower.waitedOut,
            legs: viewModel.itinerary?.legs ?? [],
            destinationName: viewModel.destinationName
        )
        .onTapGesture {
            HapticFeedback.lightImpact()
            onFocus()
        }
        .animation(.snappy, value: follower.state)
        .onChange(of: follower.coordinate != nil, initial: true) { _, hasFix in
            guard hasFix, !hasFocused else { return }
            hasFocused = true
            onFocus()
        }
    }
}

struct LiveShareBanner: View {
    let state: LiveShareState?
    let waitedOut: Bool
    let legs: [Leg]
    let destinationName: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            VStack(alignment: .leading, spacing: 5) {
                header(at: context.date)
                content(at: context.date)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .adaptable(ios26: .glassIn(AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous))), fallback: {
                $0.background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            })
        }
    }

    private func header(at date: Date) -> some View {
        let stale = state?.isLive == true && state?.isStale(at: date) == true
        let color: Color = state?.isLive == true ? (stale ? .orange : .red) : .secondary
        return HStack(spacing: 6) {
            LiveDot(color: color, blinks: state?.isLive == true && !stale)
            Text(label(stale: stale))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(color)
            Spacer(minLength: 4)
            if let fix = state?.fixDate, state?.isLive == true {
                Text(age(of: fix, at: date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func label(stale: Bool) -> String {
        guard let state else { return String(localized: "En direct") }
        if state.isLive { return stale ? String(localized: "Signal faible") : String(localized: "En direct") }
        return state.hasArrived ? String(localized: "Arrivée") : String(localized: "Terminé")
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        if let state {
            if state.isLive {
                liveContent(state, at: date)
            } else {
                endedContent(state)
            }
        } else {
            Text(waitedOut ? "Partage terminé ou indisponible." : "Connexion…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func endedContent(_ state: LiveShareState) -> some View {
        let time = state.endedDate.map(formatTime)
        if state.hasArrived {
            Text(time.map { String(localized: "Arrivée à \($0)") } ?? String(localized: "Arrivée"))
                .font(.subheadline.weight(.semibold))
        } else if state.status == "lost" {
            Text(time.map { String(localized: "Signal perdu à \($0)") } ?? String(localized: "Signal perdu"))
                .font(.subheadline.weight(.semibold))
        } else {
            Text("Partage terminé")
                .font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private func liveContent(_ state: LiveShareState, at date: Date) -> some View {
        if let index = state.leg, legs.indices.contains(index) {
            let leg = legs[index]
            let isLast = index == legs.count - 1
            switch state.onboardPhase {
            case .arrived:
                Text("À destination")
                    .font(.subheadline.weight(.semibold))
            case .walking:
                Label {
                    Text("Vers \(placeName(leg.to, isLast: isLast))")
                } icon: {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.blue)
                }
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                if let next = legs[(index + 1)...].firstIndex(where: \.isTransit) {
                    let start = state.legTimes(next)?.start ?? legs[next].startTime
                    HStack(spacing: 6) {
                        Text("Puis")
                        pill(legs[next])
                        Text("à \(formatTime(start))")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            case .waiting:
                HStack(spacing: 7) {
                    pill(leg)
                    Text("Attend à \(placeName(leg.from, isLast: false))")
                        .lineLimit(2)
                }
                .font(.subheadline.weight(.semibold))
                let start = state.legTimes(index)?.start ?? leg.startTime
                Text("Départ à \(formatTime(start))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            default:
                HStack(spacing: 7) {
                    pill(leg)
                    if let headsign = leg.headsign {
                        Text("→ \(headsign)")
                            .lineLimit(1)
                    }
                }
                .font(.subheadline.weight(.semibold))
                let stops = leg.allStops
                let next = max(1, min(stops.count - 1, state.next ?? 1))
                Group {
                    if next < stops.count - 1 {
                        Text("Prochain arrêt : \(stops[next].name)")
                    } else {
                        Text("Descend à \(placeName(leg.to, isLast: isLast))")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
        }
        if let eta = state.etaDate, state.onboardPhase != .arrived {
            HStack(spacing: 6) {
                Text("Arrivée")
                    .foregroundStyle(.secondary)
                Text(formatTime(eta))
                    .fontWeight(.bold)
                if let delay = state.delay, abs(delay) >= 60 {
                    Text(delay > 0 ? "+\(delay / 60) min" : "−\(abs(delay) / 60) min")
                        .fontWeight(.semibold)
                        .foregroundStyle(delay > 0 ? .red : .green)
                }
            }
            .font(.footnote)
            .padding(.top, 2)
        }
    }

    private func pill(_ leg: Leg) -> some View {
        LinePill(line: leg.routeShortName ?? "", mode: leg.mode, agency: leg.agencyId, width: 32, height: 20, fontSize: 11)
    }

    private func placeName(_ place: Place, isLast: Bool) -> String {
        if place.name == "END" || (isLast && place.name.isEmpty) {
            return state?.dest ?? destinationName ?? String(localized: "Destination")
        }
        if place.name == "START" { return String(localized: "Départ") }
        return place.name
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func age(of fix: Date, at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(fix)))
        if seconds < 10 { return String(localized: "à l'instant") }
        if seconds < 60 { return String(localized: "il y a \(seconds) s") }
        let minutes = seconds / 60
        if minutes < 60 { return String(localized: "il y a \(minutes) min") }
        return String(localized: "depuis \(formatTime(fix))")
    }
}

struct LiveDot: View {
    let color: Color
    let blinks: Bool
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .opacity(blinks && dimmed ? 0.3 : 1)
            .animation(blinks ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: dimmed)
            .onAppear { dimmed = true }
    }
}

struct LiveSharePuck: View {
    let fixDate: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            LiveSharePuckBody(isStale: fixDate.map { context.date.timeIntervalSince($0) > 120 } ?? false)
        }
    }
}

private struct LiveSharePuckBody: View {
    let isStale: Bool
    @State private var pulses = false

    var body: some View {
        ZStack {
            if !isStale {
                Circle()
                    .stroke(Color.luxAccent, lineWidth: 2.5)
                    .frame(width: 22, height: 22)
                    .scaleEffect(pulses ? 2.4 : 1)
                    .opacity(pulses ? 0 : 0.7)
                    .animation(.easeOut(duration: 2).repeatForever(autoreverses: false), value: pulses)
            }
            Circle()
                .fill(isStale ? Color.gray : Color.luxAccent)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
        }
        .frame(width: 54, height: 54)
        .onAppear { pulses = true }
    }
}
