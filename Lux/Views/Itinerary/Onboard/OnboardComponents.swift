//
//  OnboardComponents.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import LuxCom

struct OnboardInstructionBanner: View {
    let session: OnboardSession

    private var tint: Color {
        switch session.phase {
        case .arrived: return Color(red: 0.13, green: 0.6, blue: 0.33)
        case .walking: return session.isOffRoute ? Color(red: 0.85, green: 0.45, blue: 0.05) : Color(red: 0.1, green: 0.42, blue: 0.85)
        case .waiting, .riding:
            guard let leg = session.currentLeg else { return .accentColor }
            if session.phase == .riding && session.stopsRemaining <= 1 { return Color(red: 0.86, green: 0.18, blue: 0.2) }
            return linePill(for: leg).lineColor
        }
    }

    private func linePill(for leg: Leg) -> LinePill {
        LinePill(line: leg.routeShortName ?? "", mode: leg.mode, agency: leg.agencyId)
    }

    private var foreground: Color {
        switch session.phase {
        case .walking, .arrived:
            return .white
        case .waiting, .riding:
            guard let leg = session.currentLeg, !(session.phase == .riding && session.stopsRemaining <= 1) else { return .white }
            return linePill(for: leg).textColorOnLineColor
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                content
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let footer = footerText {
                HStack(spacing: 8) {
                    footer
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.18))
            }
        }
        .foregroundStyle(foreground)
        .background(tint.gradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
        .animation(.spring(duration: 0.4), value: session.phase)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .walking: walkingContent
        case .waiting: waitingContent
        case .riding: ridingContent
        case .arrived: arrivedContent
        }
    }

    @ViewBuilder
    private var walkingContent: some View {
        let maneuver = session.nextManeuver
        Image(systemName: session.isOffRoute ? "arrow.triangle.turn.up.right.diamond.fill" : (maneuver?.symbolName ?? "mappin.and.ellipse"))
            .font(.system(size: 38, weight: .bold))
            .frame(width: 54)
            .contentTransition(.symbolEffect(.replace))

        VStack(alignment: .leading, spacing: 2) {
            if let distance = session.distanceToManeuver {
                Text(formatDistance(distance))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: formatDistance(distance))
            }
            Text(walkingInstruction)
                .font(.system(size: 19, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var walkingInstruction: String {
        if session.isOffRoute { return String(localized: "Recalcul de l'itinéraire…") }
        if let maneuver = session.nextManeuver { return maneuver.instruction }
        if session.isInStation, let walk = session.stationWalk, walk.kind != .leaving, let track = walk.toTrack {
            return String(localized: "Rejoignez \(StationWalk.trackPhrase(track))")
        }
        guard let leg = session.currentLeg else { return "" }
        let isLast = session.legIndex == session.legs.count - 1
        return String(localized: "Marchez jusqu'à \(session.placeName(leg.to, isDestination: isLast))")
    }

    @ViewBuilder
    private var waitingContent: some View {
        if let leg = session.currentLeg {
            lineLabel(for: leg)

            VStack(alignment: .leading, spacing: 3) {
                Text(leg.headsign.map { String(localized: "Direction \($0)") } ?? leg.spokenLineName.capitalizedFirstLetter)
                    .font(.system(size: 19, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(session.placeName(leg.from))
                    .font(.subheadline.weight(.medium))
                    .opacity(0.85)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            // a train that stops a while before leaving: count down to it pulling in first
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let arrival = trainArrival(of: leg), arrival > context.date {
                    countdown(to: arrival, caption: String(localized: "arrivée du train"))
                } else {
                    countdown(to: leg.startTime, caption: String(localized: "départ"))
                }
            }
        }
    }

    /// When the train reaches the platform, if it waits there at least a minute.
    private func trainArrival(of leg: Leg) -> Date? {
        guard let arrival = leg.from.arrival, leg.startTime.timeIntervalSince(arrival) >= 60 else { return nil }
        return arrival
    }

    @ViewBuilder
    private var ridingContent: some View {
        if let leg = session.currentLeg {
            lineLabel(for: leg)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.stopsRemaining <= 1 ? String(localized: "Descendez au prochain arrêt") : String(localized: "Descendez à"))
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.85)
                Text(session.placeName(leg.to))
                    .font(.system(size: 21, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 4)
            VStack(spacing: 0) {
                Text("\(session.stopsRemaining)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: session.stopsRemaining)
                Text(session.stopsRemaining > 1 ? String(localized: "arrêts") : String(localized: "arrêt"))
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
            }
            .symbolEffect(.pulse, isActive: session.stopsRemaining <= 1)
        }
    }

    @ViewBuilder
    private var arrivedContent: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 38, weight: .bold))
            .frame(width: 54)
        VStack(alignment: .leading, spacing: 2) {
            Text("Vous êtes arrivé")
                .font(.system(size: 22, weight: .bold))
            Text(session.destinationName.capitalizedFirstLetter)
                .font(.subheadline.weight(.medium))
                .opacity(0.85)
                .lineLimit(1)
        }
    }

    private func lineLabel(for leg: Leg) -> some View {
        Text(linePill(for: leg).formattedLine)
            .font(.custom("NimbusSansBeckerPBla", size: 30))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(minWidth: 44)
            .accessibilityLabel(Text(leg.spokenLineName))
    }

    private func countdown(to date: Date, caption: String) -> some View {
        VStack(spacing: 0) {
            CountdownText(target: date, showsSeconds: true)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(caption)
                .font(.caption.weight(.semibold))
                .opacity(0.85)
        }
    }

    /// "Voie 3 → Voie 7" on a transfer, "Départ voie 7" on the way in, "Arrivée voie 3" on the way out.
    private func stationTracksText(_ walk: StationWalk) -> String? {
        switch walk.kind {
        case .transfer:
            guard let to = walk.toTrack else { return nil }
            guard let from = walk.fromTrack, from != to else { return getTrackType(to) }
            return "\(getTrackType(from)) → \(getTrackType(to))"
        case .entering:
            return walk.toTrack.map { String(localized: "Départ \(getTrackType($0).lowercased())") }
        case .leaving:
            return walk.fromTrack.map { String(localized: "Arrivée \(getTrackType($0).lowercased())") }
        }
    }

    private var footerText: AnyView? {
        // in a station GPS is usually weak anyway: the tracks matter more
        if session.isInStation, let walk = session.stationWalk, let tracks = stationTracksText(walk) {
            return AnyView(Group {
                Image(systemName: "train.side.front.car")
                Text(tracks)
                if let then = session.followingManeuver {
                    Text("· Puis")
                    Image(systemName: then.symbolName)
                }
            })
        }
        if session.followsTimetable && session.phase == .riding {
            return AnyView(Group {
                Image(systemName: "dot.radiowaves.up.forward")
                Text("Position d'après l'horaire en temps réel")
            })
        }
        if session.hasWeakGPS && session.phase != .arrived && !session.followsTimetable {
            return AnyView(Group {
                Image(systemName: "location.slash.fill")
                Text("Signal GPS faible · position estimée")
            })
        }
        switch session.phase {
        case .walking:
            if let then = session.followingManeuver {
                return AnyView(Group {
                    Text("Puis")
                    Image(systemName: then.symbolName)
                })
            }
            return nil
        case .waiting:
            guard let leg = session.currentLeg else { return nil }
            var parts: [String] = [formatTime(leg.startTime)]
            if let track = leg.from.track, !track.isEmpty { parts.append(getTrackType(track)) }
            if let arrival = trainArrival(of: leg), arrival <= Date(), leg.startTime > Date() {
                parts.append(String(localized: "train en gare"))
            }
            if let distance = session.approachingVehicleDistance {
                parts.append(String(localized: "en direct à \(formatDistance(distance))"))
            }
            return AnyView(Group {
                Image(systemName: session.approachingVehicle != nil ? "dot.radiowaves.up.forward" : "clock")
                Text(parts.joined(separator: " · "))
                if leg.cancelled {
                    DelayBadge(text: String(localized: "Supprimé"), color: .red)
                }
            })
        case .riding:
            guard let leg = session.currentLeg else { return nil }
            let stops = leg.allStops
            let delay = session.currentLegDelayMinutes
            let nextName: String? = session.stopsRemaining > 1 && session.nextStopIndex < stops.count ? stops[session.nextStopIndex].name : nil
            return AnyView(Group {
                if let nextName {
                    Image(systemName: "arrow.down.to.line")
                    Text("Prochain : \(nextName)")
                        .lineLimit(1)
                } else {
                    Image(systemName: "figure.walk.departure")
                    Text("Arrivée à \(formatTime(session.currentLegArrival))")
                }
                Spacer(minLength: 0)
                if delay != 0 {
                    DelayBadge(text: delay > 0 ? "+\(delay) min" : "\(delay) min", color: delay > 0 ? .orange : .cyan)
                }
            })
        case .arrived:
            return nil
        }
    }
}

struct DelayBadge: View {
    let text: String
    let color: Color
    var onTint = true

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(onTint ? color : .white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(onTint ? Color.white : color, in: Capsule())
    }
}

struct CountdownText: View {
    let target: Date
    var showsSeconds = false

    private func text(at now: Date) -> String {
        let seconds = Int(target.timeIntervalSince(now).rounded(.down))
        guard showsSeconds, seconds > 0, seconds < 60 else { return shortCountdown(to: target, now: now) }
        return String(format: "0:%02d", seconds)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let text = text(at: context.date)
            (text.contains(":") ? Text(text).monospacedDigit() : Text(text))
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: text)
        }
    }
}

func shortCountdown(to date: Date, now: Date) -> String {
    let seconds = date.timeIntervalSince(now)
    if seconds < 30 { return "0'" }
    let minutes = Int((seconds / 60).rounded(.up))
    if minutes < 60 { return "\(minutes)'" }
    return "\(minutes / 60)h\(String(format: "%02d", minutes % 60))"
}

struct OnboardAlertToast: View {
    let alert: OnboardAlert
    let onDismiss: () -> Void

    private var isCritical: Bool { alert.severity == .critical }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: alert.symbolName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isCritical ? .white : alert.severity.color)
                .frame(width: 30)
                .symbolEffect(.bounce, value: alert.id)

            VStack(alignment: .leading, spacing: 1) {
                Text(alert.title)
                    .font(.subheadline.weight(.bold))
                if let message = alert.message {
                    Text(message)
                        .font(.footnote)
                        .lineLimit(3)
                        .opacity(0.85)
                }
            }
            .foregroundStyle(isCritical ? .white : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isCritical ? .white.opacity(0.8) : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Fermer"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .adaptable(ios26: isCritical
            ? .glassTintedIn(AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous)), .red)
            : .glassIn(AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous))),
        fallback: {
            $0.background {
                if isCritical {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.red.gradient)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(alert.severity.color.opacity(0.35), lineWidth: 1))
                }
            }
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        })
        .onTapGesture(perform: onDismiss)
    }
}

struct OnboardBottomPanel: View {
    let session: OnboardSession
    @ObservedObject var itineraryViewModel: ItineraryViewModel
    let isExpanded: Bool
    let onEnd: () -> Void
    var onOpenDetail: () -> Void = {}
    let onCompactHeightChange: (CGFloat) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    summaryRow
                        .padding(.horizontal, 22)
                    contextRow
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                    if !session.legDisruptions.isEmpty {
                        DisruptionsRow(groups: session.disruptionGroups, action: onOpenDetail)
                            .padding(.horizontal, 22)
                            .padding(.top, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, session.endsWithButton ? 2 : 6)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { onCompactHeightChange($0) }

                if session.phase != .arrived {
                    VStack(spacing: 0) {
                        Divider()
                            .padding(.horizontal, 22)
                        expandedContent
                            .padding(.bottom, 24)
                    }
                    .opacity(isExpanded ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: isExpanded)
                    .allowsHitTesting(isExpanded)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatTime(session.arrivalDate))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(arrivalColor)
                        .contentTransition(.numericText())
                    Text("arrivée")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                TimelineView(.periodic(from: .now, by: 10)) { context in
                    Text(remainingText(at: context.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer()

            if session.phase == .arrived {
                Button(action: onEnd) {
                    Text("Terminer")
                        .font(.headline)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(Color.green.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onEnd) {
                    Text("Quitter")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(Color.red.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Quitte le mode À bord"))
            }
        }
    }

    private var arrivalColor: Color {
        guard let last = session.legs.last(where: \.isTransit), last.realTime else { return .primary }
        let delay = last.arrivalDelayMinutes
        if delay >= 2 { return .orange }
        return .green
    }

    private func remainingText(at now: Date) -> String {
        let minutes = max(0, Int((session.arrivalDate.timeIntervalSince(now) / 60).rounded(.up)))
        let time = minutes >= 60 ? "\(minutes / 60) h \(String(format: "%02d", minutes % 60))" : "\(minutes) min"
        return session.phase == .arrived ? String(localized: "Trajet terminé") : "\(time) · \(formatDistance(session.remainingDistance))"
    }

    @ViewBuilder
    private var contextRow: some View {
        switch session.phase {
        case .walking:
            if let (_, next) = session.nextTransitLeg {
                VStack(alignment: .leading, spacing: 10) {
                    nextTransitRow(next)
                    // on the way to the platform, where to stand is worth knowing already
                    if session.isInStation, let formation = session.formation {
                        TrainFormationView(formation: formation, platformSectors: session.formationPlatformSectors)
                    }
                }
            }
        case .waiting:
            VStack(alignment: .leading, spacing: 10) {
                if let formation = session.formation {
                    TrainFormationView(formation: formation, platformSectors: session.formationPlatformSectors)
                        .padding(.bottom, 2)
                        .transition(.opacity)
                }
                if let info = session.rideInfo {
                    RideCommunityStrip(info: info)
                }
                Button {
                    session.confirmBoarded()
                } label: {
                    Label("Je suis à bord", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(.white)
                        .background(Color.accentColor.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        case .riding:
            VStack(alignment: .leading, spacing: 8) {
                rideProgress
                if let info = session.rideInfo {
                    RideCommunityStrip(info: info)
                }
                crowdRow
            }
        case .arrived:
            EmptyView()
        }
    }

    private func nextTransitRow(_ leg: Leg) -> some View {
        HStack(spacing: 10) {
            Text("Ensuite")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            LinePill(line: leg.routeShortName ?? "", mode: leg.mode, agency: leg.agencyId, width: 38, height: 24, fontSize: 13)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("\(formatTime(leg.startTime)) ·")
                    CountdownText(target: leg.startTime, showsSeconds: true)
                }
                .font(.subheadline.weight(.semibold))
                Text(session.placeName(leg.from))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            riskBadge
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var riskBadge: some View {
        switch session.connectionRisk {
        case .comfortable:
            EmptyView()
        case .tight:
            Label("Serré", systemImage: "hare.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
        case .missed:
            Label("Compromis", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
        }
    }

    private var rideProgress: some View {
        let stops = session.currentStops
        let color = session.currentLeg.map { getLegColor($0, brightIt: true) } ?? .accentColor
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                let count = max(stops.count, 2)
                let spacing = proxy.size.width / CGFloat(count - 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 4)
                    Capsule().fill(color).frame(width: max(0, proxy.size.width * session.stopProgress), height: 4)
                    ForEach(0..<stops.count, id: \.self) { index in
                        let passed = index < session.nextStopIndex
                        let isEnd = index == stops.count - 1
                        Circle()
                            .fill(passed ? color : Color(.systemBackground))
                            .frame(width: isEnd ? 12 : 7, height: isEnd ? 12 : 7)
                            .overlay(Circle().stroke(color, lineWidth: isEnd ? 3 : 1.5))
                            .offset(x: CGFloat(index) * spacing - (isEnd ? 6 : 3.5))
                    }
                }
                .frame(height: 12)
            }
            .frame(height: 12)

            HStack {
                Text(stops.first.map { session.placeName($0) } ?? "")
                    .lineLimit(1)
                Spacer()
                Text(stops.last.map { session.placeName($0) } ?? "")
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .animation(.linear(duration: 1), value: session.stopProgress)
    }

    @ViewBuilder
    private var crowdRow: some View {
        if session.followsTimetable {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Train suivi avec le temps réel officiel")
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            sharingRow
        }
    }

    private var sharingRow: some View {
        HStack(spacing: 8) {
            Image(systemName: session.isSharingPosition ? "dot.radiowaves.up.forward" : "antenna.radiowaves.left.and.right.slash")
                .foregroundStyle(session.isSharingPosition ? Color.accentColor : .secondary)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: session.isSharingPosition)
            Group {
                if !session.isSharingPosition {
                    Text("Position du véhicule non partagée")
                } else {
                    switch session.crowdStatus?.state {
                    case .contributing(let riders, _) where riders > 1:
                        Text("Position du véhicule partagée avec \(riders - 1) autre(s) voyageur(s)")
                    case .contributing:
                        Text("Vous partagez la position du véhicule")
                    case .unverified:
                        Text("Véhicule non confirmé, rien n'est partagé")
                    case .learning, nil:
                        Text("Partage de la position du véhicule…")
                    }
                }
            }
            .lineLimit(2)
            Spacer(minLength: 4)
            Toggle("", isOn: Binding(get: { session.isSharingPosition }, set: { session.setSharing($0) }))
                .labelsHidden()
                .controlSize(.mini)
                .accessibilityLabel(Text("Partager la position du véhicule"))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
                if (session.phase == .riding || session.phase == .waiting), let leg = session.currentLeg {
                    ItinerarySheetDetailStopsContentView(
                        viewModel: itineraryViewModel,
                        stops: session.upcomingStops,
                        legColor: getLegColor(leg, brightIt: true),
                        fromStop: leg.from,
                        toStop: leg.to,
                        duration: leg.duration,
                        isMultipleLeg: false,
                        isRealTime: leg.realTime,
                        isCancelled: leg.cancelled
                    )
                    if session.canReportRide {
                        Divider()
                            .padding(.vertical, 16)
                        RideRatingSection(reports: session.rideReports, info: session.rideInfo) { attribute, level in
                            session.reportRide(attribute, level: level)
                        }
                    }
                } else {
                    ForEach(Array(remainingLegs.enumerated()), id: \.offset) { _, leg in
                        legRow(leg)
                    }
                }

                if session.phase != .arrived, isExpanded {
                    Button {
                        session.skipToNextStep()
                    } label: {
                        Label("Passer à l'étape suivante", systemImage: "forward.end.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.top, 14)
                }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    private var remainingLegs: [Leg] {
        guard session.legIndex + 1 < session.legs.count else { return [] }
        return Array(session.legs[(session.legIndex + 1)...])
    }

    private func legRow(_ leg: Leg) -> some View {
        HStack(spacing: 12) {
            if leg.isTransit {
                LinePill(line: leg.routeShortName ?? "", mode: leg.mode, agency: leg.agencyId, width: 38, height: 24, fontSize: 13)
                Text(leg.headsign.map { String(localized: "Direction \($0)") } ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
            } else {
                Image(systemName: "figure.walk")
                    .frame(width: 38)
                    .foregroundStyle(.blue)
                Text("Marchez \(max(1, leg.duration / 60)) min")
                    .font(.subheadline)
            }
            Spacer()
            Text(formatTime(leg.startTime))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 7)
    }
}
