//
//  OnboardLiveActivity.swift
//  StopWidget
//
//  Created by Constantin Clerc on 23.09.2026.
//

import ActivityKit
import SwiftUI
import WidgetKit
import LuxCom

private typealias State = OnboardActivityAttributes.ContentState

struct OnboardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OnboardActivityAttributes.self) { context in
            OnboardLockScreenView(state: context.state, destination: context.attributes.destinationName)
                .widgetURL(URL(string: "lux://onboard"))
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(state: state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailing(state: state)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenter(state: state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(state: state, destination: context.attributes.destinationName)
                }
            } compactLeading: {
                CompactLeading(state: state)
            } compactTrailing: {
                CompactTrailing(state: state)
            } minimal: {
                MinimalView(state: state)
            }
            .widgetURL(URL(string: "lux://onboard"))
            .keylineTint(state.accent)
        }
    }
}

private struct OnboardLockScreenView: View {
    let state: State
    let destination: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch state.phase {
            case .riding: riding
            case .waiting: waiting
            case .walking: walking
            case .arrived: arrived
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .foregroundStyle(state.isUrgent ? .white : .primary)
        .background {
            if state.isUrgent {
                LinearGradient(colors: [Color.urgentRed, Color.urgentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    private var riding: some View {
        VStack(alignment: .leading, spacing: 12) {
            LineHeader(state: state)

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.isUrgent ? "Descendez au prochain arrêt" : "Descendez à")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(state.isUrgent ? .white.opacity(0.85) : .secondary)
                    Text(state.title)
                        .font(.system(size: 24, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 8)
                if !state.isUrgent {
                    StopsCounter(state: state, large: true)
                }
            }

            StopTrack(state: state, onRedBackground: true)
                .frame(height: 22)

            HStack {
                if !state.isUrgent {
                    Text(state.fromName ?? "")
                        .lineLimit(1)
                }
                Spacer()
                if let target = state.targetDate {
                    Text("Arrivée \(target, style: .time)")
                        .fontWeight(.semibold)
                        .foregroundStyle(state.isUrgent ? .white : .primary)
                }
            }
            .font(.caption)
            .foregroundStyle(state.isUrgent ? .white.opacity(0.8) : .secondary)
        }
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 12) {
            LineHeader(state: state)

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Départ de \(state.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let target = state.targetDate {
                        Text(target, style: .time)
                            .font(.system(size: 24, weight: .bold))
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 8)
                Countdown(target: state.targetDate, minutes: state.countdownMinutes, size: 34)
                    .foregroundStyle(state.accent)
            }

            HStack(spacing: 8) {
                if !state.subtitle.isEmpty {
                    InfoChip(symbol: "signpost.right.fill", text: state.subtitle, tint: .secondary)
                }
                if state.vehicleIsLive {
                    InfoChip(
                        symbol: "dot.radiowaves.up.forward",
                        text: state.vehicleDistanceMeters.map { String(localized: "En direct · \(formatMeters($0))") } ?? String(localized: "En direct"),
                        tint: state.accent
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var walking: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                ManeuverBadge(symbol: state.symbolName, size: 52)
                VStack(alignment: .leading, spacing: 0) {
                    if let distance = state.distanceMeters {
                        Text(formatMeters(distance))
                            .contentTransition(.numericText(countsDown: true))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    Text(state.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ProgressView(value: state.progress)
                .tint(Color.walkBlue)

            if let line = state.line {
                HStack(spacing: 8) {
                    Text("Ensuite")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    SolidLinePill(line: line, colorHex: state.lineColorHex, mode: state.lineMode, height: 20, fontSize: 11)
                    Text(state.subtitle)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if state.vehicleIsLive {
                        Image(systemName: "dot.radiowaves.up.forward")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(state.accent)
                    }
                    Countdown(target: state.targetDate, minutes: state.countdownMinutes, size: 15)
                        .foregroundStyle(state.accent)
                    DelayChip(minutes: state.delayMinutes)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                    Text(destination).lineLimit(1)
                    Spacer()
                    Text("Arrivée \(state.arrivalDate, style: .time)").fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var arrived: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.green.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text("Vous êtes arrivé")
                    .font(.system(size: 20, weight: .bold))
                Text(destination)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(state.arrivalDate, style: .time)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExpandedLeading: View {
    let state: State

    var body: some View {
        Group {
            if let line = state.line, state.phase == .riding || state.phase == .waiting {
                SolidLinePill(line: line, colorHex: state.lineColorHex, mode: state.lineMode, height: 30, fontSize: 16)
                    .frame(height: state.phase == .riding ? 41 : 31)
            } else {
                ManeuverBadge(symbol: state.symbolName, size: 38)
            }
        }
        .padding(.leading, 6)
        .padding(.top, 4)
    }
}

private struct ExpandedTrailing: View {
    let state: State

    var body: some View {
        Group {
            switch state.phase {
            case .riding:
                StopsCounter(state: state, large: true)
            case .waiting:
                Countdown(target: state.targetDate, minutes: state.countdownMinutes, size: 26)
                    .foregroundStyle(state.accent)
            case .walking:
                if let distance = state.distanceMeters {
                    Text(formatMeters(distance))
                        .contentTransition(.numericText(countsDown: true))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
            case .arrived:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.trailing, 6)
        .padding(.top, 4)
    }
}

private struct ExpandedCenter: View {
    let state: State

    var body: some View {
        VStack(spacing: 0) {
            switch state.phase {
            case .riding:
                Text(state.isUrgent ? "Descendez au prochain arrêt" : "Descendez à")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state.isUrgent ? Color.urgentRed : .secondary)
                Text(state.title)
                    .font(.headline)
            case .waiting:
                Text(state.headsign.map { "→ \($0)" } ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(state.title)
                    .font(.headline)
            case .walking:
                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            case .arrived:
                Text("Vous êtes arrivé")
                    .font(.headline)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.top, 4)
    }
}

private struct ExpandedBottom: View {
    let state: State
    let destination: String

    var body: some View {
        Group {
            switch state.phase {
            case .riding:
                VStack(spacing: 6) {
                    StopTrack(state: state).frame(height: 20)
                    HStack {
                        Text(state.isUrgent ? String(localized: "Préparez-vous à descendre") : state.subtitle).lineLimit(1)
                        Spacer()
                        if let target = state.targetDate {
                            Text(target, style: .time).fontWeight(.semibold)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            case .waiting:
                HStack(spacing: 8) {
                    if !state.subtitle.isEmpty {
                        InfoChip(symbol: "signpost.right.fill", text: state.subtitle, tint: .secondary)
                    }
                    if state.vehicleIsLive {
                        InfoChip(
                            symbol: "dot.radiowaves.up.forward",
                            text: state.vehicleDistanceMeters.map { String(localized: "En direct · \(formatMeters($0))") } ?? String(localized: "En direct"),
                            tint: state.accent
                        )
                    }
                    Spacer(minLength: 0)
                    DelayChip(minutes: state.delayMinutes)
                }
            case .walking:
                if let line = state.line {
                    HStack(spacing: 8) {
                        Text("Ensuite").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        SolidLinePill(line: line, colorHex: state.lineColorHex, mode: state.lineMode, height: 20, fontSize: 11)
                        Text(state.subtitle).font(.caption).lineLimit(1)
                        Spacer(minLength: 4)
                        Countdown(target: state.targetDate, minutes: state.countdownMinutes, size: 14).foregroundStyle(state.accent)
                    }
                } else {
                    ProgressView(value: state.progress).tint(Color.walkBlueOnDark)
                }
            case .arrived:
                Text(destination).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 2)
    }
}

private struct CompactLeading: View {
    let state: State

    var body: some View {
        if let line = state.line, state.phase == .riding || state.phase == .waiting {
            SolidLinePill(line: line, colorHex: state.lineColorHex, mode: state.lineMode, height: 20, fontSize: 11)
        } else if state.phase == .arrived {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Image(systemName: state.symbolName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.walkBlueOnDark)
        }
    }
}

private struct CompactTrailing: View {
    let state: State

    var body: some View {
        switch state.phase {
        case .riding:
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if state.isUrgent {
                    Image(systemName: "figure.walk.departure")
                        .font(.system(size: 12, weight: .bold))
                    Text("Descendez")
                        .font(.system(size: 12, weight: .bold))
                } else {
                    Text("\(state.stopsRemaining ?? 0)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("arr.")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(0.8)
                }
            }
            .foregroundStyle(state.isUrgent ? Color.urgentRed : state.accent)
        case .waiting:
            Countdown(target: state.targetDate, minutes: state.countdownMinutes, size: 14)
                .foregroundStyle(state.accent)
                .frame(maxWidth: 46)
        case .walking:
            Text(state.distanceMeters.map(formatMeters) ?? "")
                .contentTransition(.numericText(countsDown: true))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.walkBlueOnDark)
        case .arrived:
            Text(state.arrivalDate, style: .time)
                .font(.system(size: 13, weight: .semibold))
        }
    }
}

private struct MinimalView: View {
    let state: State

    var body: some View {
        switch state.phase {
        case .riding:
            ZStack {
                Circle().stroke(state.accent.opacity(0.3), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: state.progress)
                    .stroke(state.isUrgent ? Color.urgentRed : state.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(state.stopsRemaining ?? 0)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .padding(1)
        case .waiting:
            Image(systemName: state.symbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(state.accent)
        case .walking:
            Image(systemName: state.symbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.walkBlueOnDark)
        case .arrived:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }
}

private struct SolidLinePill: View {
    let line: String
    let colorHex: String?
    let mode: String?
    var height: CGFloat = 26
    var fontSize: CGFloat = 14

    private var isSquared: Bool {
        let rail = ["RL", "IR", "RE", "IC", "EC", "S", "R"].contains { line.hasPrefix($0) }
        let mode = mode.flatMap(TransportationMode.init(rawValue:))
        return rail || (mode?.isRail ?? false) || mode == .ferry
    }

    var body: some View {
        let color = colorHex.map { Color(hex: $0) } ?? .accentColor
        Text(line.hasPrefix("RL") ? String(line.dropFirst()) : line)
            .font(.custom("NimbusSansBeckerPBla", size: fontSize))
            .foregroundStyle(color.prefersDarkText ? Color.black : Color.white)
            .lineLimit(1)
            .padding(.horizontal, height * 0.32)
            .frame(minWidth: height * 1.45, minHeight: height)
            .background(color, in: RoundedRectangle(cornerRadius: isSquared ? 4 : height / 2, style: .continuous))
            .fixedSize()
    }
}

private struct LineHeader: View {
    let state: State

    var body: some View {
        HStack(spacing: 8) {
            if let line = state.line {
                SolidLinePill(line: line, colorHex: state.lineColorHex, mode: state.lineMode)
            }
            if let headsign = state.headsign {
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(state.isUrgent ? .white.opacity(0.7) : .secondary)
                Text(headsign)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if state.vehicleIsLive && state.phase == .riding {
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(state.isUrgent ? .white : state.accent)
            }
            DelayChip(minutes: state.delayMinutes)
        }
    }
}

private struct StopTrack: View {
    let state: State
    var onRedBackground = false

    var body: some View {
        GeometryReader { proxy in
            let total = max(2, state.totalStops ?? 2)
            let passed = min(total, state.passedStops ?? 0)
            let segment = max(0, min(total - 2, passed - 1))
            let width = proxy.size.width
            let midY = proxy.size.height / 2
            let color = state.isUrgent ? (onRedBackground ? Color.white : Color.urgentRed) : state.accent
            let x: (Int) -> CGFloat = { index in 6 + (width - 12) * CGFloat(index) / CGFloat(total - 1) }
            let showsAllDots = total <= 16

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(color.opacity(0.25))
                    .frame(width: width - 12, height: 5)
                    .position(x: width / 2, y: midY)

                if let start = state.segmentStart, let end = state.segmentEnd, end > start {
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, x(segment) - 6), height: 5)
                        .position(x: 6 + max(0, x(segment) - 6) / 2, y: midY)
                    ProgressView(timerInterval: start...end, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.linear)
                    .tint(color)
                    .frame(width: x(segment + 1) - x(segment))
                    .position(x: (x(segment) + x(segment + 1)) / 2, y: midY)
                } else {
                    let filled = (width - 12) * CGFloat(max(0, min(1, state.progress)))
                    Capsule()
                        .fill(color)
                        .frame(width: filled, height: 5)
                        .position(x: 6 + filled / 2, y: midY)
                }

                ForEach(0..<total, id: \.self) { index in
                    let isLast = index == total - 1
                    if showsAllDots || index == 0 || isLast {
                        Circle()
                            .fill(index < passed ? color : (state.isUrgent && onRedBackground ? Color.clear : Color(.systemBackground)))
                            .overlay(Circle().stroke(color, lineWidth: isLast ? 3 : 1.8))
                            .frame(width: isLast ? 14 : 8, height: isLast ? 14 : 8)
                            .position(x: x(index), y: midY)
                    }
                }
            }
        }
    }
}

private struct StopsCounter: View {
    let state: State
    let large: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: -3) {
            Text("\(state.stopsRemaining ?? 0)")
                .font(.system(size: large ? 34 : 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .foregroundStyle(state.isUrgent ? .white : state.accent)
            Text((state.stopsRemaining ?? 0) > 1 ? "arrêts" : "arrêt")
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(state.isUrgent ? .white.opacity(0.8) : .secondary)
        }
    }
}

private struct Countdown: View {
    let target: Date?
    var minutes: Int? = nil
    let size: CGFloat

    var body: some View {
        if let minutes, minutes > 0, let target, target.timeIntervalSinceNow >= 60 {
            Text("\(minutes)'")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .multilineTextAlignment(.trailing)
        } else if let target, target > .now {
            Text(timerInterval: Date.now...target, countsDown: true, showsHours: false)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .multilineTextAlignment(.trailing)
        } else if target != nil {
            Text("0'")
                .font(.system(size: size, weight: .bold, design: .rounded))
        }
    }
}

private struct DelayChip: View {
    let minutes: Int?

    var body: some View {
        if let minutes, minutes != 0 {
            Text(minutes > 0 ? "+\(minutes)'" : "\(minutes)'")
                .font(.caption.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(minutes > 0 ? Color.orange : Color.cyan, in: Capsule())
        }
    }
}

private struct InfoChip: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct ManeuverBadge: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Color.walkBlue.gradient))
    }
}

private func formatMeters(_ meters: Double) -> String {
    if meters >= 1000 {
        return String(format: "%.1f km", meters / 1000)
    }
    let step: Double = meters > 300 ? 50 : 10
    return "\(Int((meters / step).rounded() * step)) m"
}

private extension Color {
    static let walkBlue = Color(red: 0.1, green: 0.42, blue: 0.85)
    static let walkBlueOnDark = Color(red: 0.35, green: 0.63, blue: 1)
    static let urgentRed = Color(red: 1, green: 0.27, blue: 0.23)
    static let urgentDeep = Color(red: 0.72, green: 0.07, blue: 0.1)

    var prefersDarkText: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue > 0.62
    }
}

private extension State {
    var accent: Color {
        switch phase {
        case .arrived: return .green
        case .walking: return lineColorHex.map { Color(hex: $0) } ?? .walkBlue
        case .waiting, .riding: return lineColorHex.map { Color(hex: $0) } ?? .accentColor
        }
    }
}

#if DEBUG
extension OnboardActivityAttributes.ContentState {
    static let previewRiding = Self(
        phase: .riding, title: "Augustins", subtitle: "Prochain arrêt : Plainpalais", symbolName: "tram",
        line: "12", lineMode: "TRAM", lineAgency: "881", lineColorHex: "F29400", headsign: "Palettes",
        targetDate: .now.addingTimeInterval(420), arrivalDate: .now.addingTimeInterval(900), delayMinutes: 2,
        stopsRemaining: 3, totalStops: 7, passedStops: 4, fromName: "Bel-Air", toName: "Augustins", progress: 0.52, segmentStart: .now.addingTimeInterval(-50), segmentEnd: .now.addingTimeInterval(70),
        vehicleIsLive: true, isUrgent: false
    )
    static let previewUrgent = Self(
        phase: .riding, title: "Augustins", subtitle: "Descendez au prochain arrêt", symbolName: "tram",
        line: "12", lineMode: "TRAM", lineAgency: "881", lineColorHex: "F29400", headsign: "Palettes",
        targetDate: .now.addingTimeInterval(60), arrivalDate: .now.addingTimeInterval(540), delayMinutes: 2,
        stopsRemaining: 1, totalStops: 7, passedStops: 6, fromName: "Bel-Air", toName: "Augustins", progress: 0.9, segmentStart: .now.addingTimeInterval(-50), segmentEnd: .now.addingTimeInterval(70),
        vehicleIsLive: true, isUrgent: true
    )
    static let previewWaiting = Self(
        phase: .waiting, title: "Cornavin", subtitle: "Quai C", symbolName: "bus",
        line: "8", lineMode: "BUS", lineAgency: "881", lineColorHex: "8A2BE2", headsign: "OMS",
        targetDate: .now.addingTimeInterval(272), countdownMinutes: 5, arrivalDate: .now.addingTimeInterval(1500), delayMinutes: 3,
        progress: 0, vehicleIsLive: true, vehicleDistanceMeters: 640, isUrgent: false
    )
    static let previewWalking = Self(
        phase: .walking, title: "Tournez à gauche sur Rue de la Corraterie", subtitle: "Bel-Air", symbolName: "arrow.turn.up.left",
        line: "12", lineMode: "TRAM", lineAgency: "881", lineColorHex: "F29400", headsign: "Palettes",
        targetDate: .now.addingTimeInterval(372), countdownMinutes: 7, arrivalDate: .now.addingTimeInterval(1100), delayMinutes: 2,
        progress: 0.35, distanceMeters: 40, vehicleIsLive: false, isUrgent: false
    )
    static let previewTrain = Self(
        phase: .riding, title: "Lausanne", subtitle: "Prochain arrêt : Nyon", symbolName: "tram.tunnel",
        line: "IR90", lineMode: "REGIONAL_FAST_RAIL", lineAgency: "11", lineColorHex: "EB0000", headsign: "Brig",
        targetDate: .now.addingTimeInterval(1860), arrivalDate: .now.addingTimeInterval(2400), delayMinutes: 0,
        stopsRemaining: 2, totalStops: 4, passedStops: 2, fromName: "Genève", toName: "Lausanne", progress: 0.4, segmentStart: .now.addingTimeInterval(-50), segmentEnd: .now.addingTimeInterval(70),
        vehicleIsLive: false, isUrgent: false
    )
    static let previewArrived = Self(
        phase: .arrived, title: "Vous êtes arrivé", subtitle: "Hôpital cantonal", symbolName: "checkmark",
        arrivalDate: .now, progress: 1, vehicleIsLive: false, isUrgent: false
    )
}

#Preview("Onboard", as: .content, using: OnboardActivityAttributes(destinationName: "Hôpital cantonal")) {
    OnboardLiveActivity()
} contentStates: {
    OnboardActivityAttributes.ContentState.previewRiding
    OnboardActivityAttributes.ContentState.previewUrgent
    OnboardActivityAttributes.ContentState.previewWaiting
    OnboardActivityAttributes.ContentState.previewWalking
    OnboardActivityAttributes.ContentState.previewTrain
    OnboardActivityAttributes.ContentState.previewArrived
}

#Preview("Island", as: .dynamicIsland(.expanded), using: OnboardActivityAttributes(destinationName: "Genève")) {
    OnboardLiveActivity()
} contentStates: {
    OnboardActivityAttributes.ContentState.previewTrain
    OnboardActivityAttributes.ContentState.previewWaiting
}
#endif
