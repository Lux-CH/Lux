//
//  OnboardCrowdBack.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import LuxCom

extension ReportAttribute {
    static let ride: [ReportAttribute] = [.crowd, .clean, .heat, .noise]

    var title: String {
        switch self {
        case .crowd: return String(localized: "Affluence")
        case .clean: return String(localized: "Propreté")
        case .heat: return String(localized: "Température")
        case .noise: return String(localized: "Bruit")
        case .smell: return String(localized: "Odeur")
        }
    }

    var symbolName: String {
        switch self {
        case .crowd: return "person.3.fill"
        case .clean: return "sparkles"
        case .heat: return "thermometer.medium"
        case .noise: return "speaker.wave.2.fill"
        case .smell: return "nose.fill"
        }
    }

    func label(for level: Int) -> String {
        let level = max(1, min(5, level))
        switch self {
        case .crowd:
            return [String(localized: "Vide"), String(localized: "Places assises"), String(localized: "Quelques debout"), String(localized: "Debout"), String(localized: "Bondé")][level - 1]
        case .clean:
            return [String(localized: "Très sale"), String(localized: "Sale"), String(localized: "Correct"), String(localized: "Propre"), String(localized: "Impeccable")][level - 1]
        case .heat:
            return [String(localized: "Froid"), String(localized: "Frais"), String(localized: "Agréable"), String(localized: "Chaud"), String(localized: "Étouffant")][level - 1]
        case .noise:
            return [String(localized: "Silencieux"), String(localized: "Calme"), String(localized: "Normal"), String(localized: "Bruyant"), String(localized: "Très bruyant")][level - 1]
        case .smell:
            return [String(localized: "Agréable"), String(localized: "Neutre"), String(localized: "Correct"), String(localized: "Désagréable"), String(localized: "Insupportable")][level - 1]
        }
    }

    func color(for level: Double) -> Color {
        let scale: [Color]
        switch self {
        case .heat:
            scale = [.cyan, .blue, .green, .orange, .red]
        case .clean:
            scale = [.red, .orange, .yellow, .green, .green]
        case .crowd, .noise, .smell:
            scale = [.green, .green, .yellow, .orange, .red]
        }
        return scale[max(0, min(4, Int(level.rounded()) - 1))]
    }
}

extension InfoResponse {
    func communityLevel(for attribute: ReportAttribute) -> (level: Double, isLive: Bool)? {
        if let live = rt?[attribute.rawValue], live.trustLevel >= 2 {
            return (Double(live.level), true)
        }
        if let average = average[attribute.rawValue], average.trustLevel >= 2, average.reportCount > 0 {
            return (average.level, false)
        }
        return nil
    }
}

struct RideCommunityStrip: View {
    let info: InfoResponse

    private var entries: [(ReportAttribute, Double, Bool)] {
        ReportAttribute.ride.compactMap { attribute in
            info.communityLevel(for: attribute).map { (attribute, $0.level, $0.isLive) }
        }
    }

    var body: some View {
        if !entries.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(entries, id: \.0) { attribute, level, isLive in
                        HStack(spacing: 5) {
                            Image(systemName: attribute.symbolName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(attribute.label(for: Int(level.rounded())))
                                .font(.caption.weight(.semibold))
                            if isLive {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .foregroundStyle(attribute.color(for: level))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(attribute.color(for: level).opacity(0.13), in: Capsule())
                    }
                }
            }
            .scrollClipDisabled()
            .accessibilityElement(children: .combine)
        }
    }
}

struct CrowdPromptCard: View {
    let leg: Leg
    let onAnswer: (Int) -> Void
    let onDismiss: () -> Void

    @State private var answered: Int?

    private let answers: [(symbol: String, level: Int)] = [
        ("person", 1),
        ("chair.fill", 2),
        ("figure.stand", 4),
        ("person.3.fill", 5),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let answered {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: answered)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Merci !")
                            .font(.headline)
                        Text("Votre avis aide les autres voyageurs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Il y a du monde à bord ?")
                            .font(.headline)
                        Text("Une touche suffit, c'est anonyme")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Fermer"))
                }

                HStack(spacing: 8) {
                    ForEach(answers, id: \.level) { answer in
                        Button {
                            HapticFeedback.selectionChanged()
                            onAnswer(answer.level)
                            withAnimation(.spring(duration: 0.35)) { answered = answer.level }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: onDismiss)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: answer.symbol)
                                    .font(.system(size: 19, weight: .semibold))
                                Text(ReportAttribute.crowd.label(for: answer.level))
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .foregroundStyle(ReportAttribute.crowd.color(for: Double(answer.level)))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(ReportAttribute.crowd.color(for: Double(answer.level)).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .padding(16)
        .adaptable(ios26: .glassIn(AnyShape(RoundedRectangle(cornerRadius: 24, style: .continuous))), fallback: {
            $0.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        })
    }
}

struct RideRatingSection: View {
    let reports: [ReportAttribute: Int]
    let info: InfoResponse?
    let onRate: (ReportAttribute, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Comment est ce trajet ?")
                    .font(.headline)
                Spacer()
                Text("Anonyme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(ReportAttribute.ride, id: \.self) { attribute in
                RideRatingRow(
                    attribute: attribute,
                    reported: reports[attribute],
                    community: info?.communityLevel(for: attribute)?.level,
                    onRate: { onRate(attribute, $0) }
                )
            }
        }
    }
}

private struct RideRatingRow: View {
    let attribute: ReportAttribute
    let reported: Int?
    let community: Double?
    let onRate: (Int) -> Void

    private var shownLevel: Int? { reported ?? community.map { Int($0.rounded()) } }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attribute.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(shownLevel.map { attribute.color(for: Double($0)) } ?? .secondary)
                .frame(width: 34, height: 34)
                .background((shownLevel.map { attribute.color(for: Double($0)) } ?? .secondary).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(attribute.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let reported {
                        Text(attribute.label(for: reported))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(attribute.color(for: Double(reported)))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if let community {
                        Text(attribute.label(for: Int(community.rounded())))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { level in
                        Button {
                            HapticFeedback.selectionChanged()
                            onRate(level)
                        } label: {
                            Capsule()
                                .fill(fill(for: level))
                                .frame(height: 10)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(attribute.label(for: level)))
                    }
                }
                .animation(.snappy, value: reported)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(attribute.title))
    }

    private func fill(for level: Int) -> Color {
        if let reported {
            return level <= reported ? attribute.color(for: Double(reported)) : Color.secondary.opacity(0.15)
        }
        if let community, level <= Int(community.rounded()) {
            return attribute.color(for: community).opacity(0.35)
        }
        return Color.secondary.opacity(0.15)
    }
}

struct ReplanCard: View {
    let session: OnboardSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let proposal = session.replan {
                header(for: proposal.reason)
                proposalRow(proposal)
                HStack(spacing: 10) {
                    Button {
                        HapticFeedback.lightImpact()
                        session.declineReplan()
                    } label: {
                        Text("Garder l'actuel")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        session.acceptReplan()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Utiliser")
                            if let autoApplyAt = proposal.autoApplyAt {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    let seconds = max(0, Int(autoApplyAt.timeIntervalSince(context.date).rounded(.up)))
                                    Text("\(seconds)s")
                                        .monospacedDigit()
                                        .opacity(0.75)
                                        .contentTransition(.numericText(countsDown: true))
                                        .animation(.snappy, value: seconds)
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.accentColor.gradient, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Recherche d'une alternative…")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
            }
        }
        .padding(16)
        .adaptable(ios26: .glassIn(AnyShape(RoundedRectangle(cornerRadius: 24, style: .continuous))), fallback: {
            $0.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        })
    }

    private func header(for reason: OnboardSession.ReplanReason) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol(for: reason))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint(for: reason).gradient))
            VStack(alignment: .leading, spacing: 1) {
                Text(title(for: reason))
                    .font(.headline)
                Text("Nouvel itinéraire trouvé")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func title(for reason: OnboardSession.ReplanReason) -> String {
        switch reason {
        case .connection: return String(localized: "Correspondance compromise")
        case .missedDeparture: return String(localized: "Départ manqué")
        case .cancelled: return String(localized: "Véhicule supprimé")
        case .earlier: return String(localized: "Départ plus tôt possible")
        }
    }

    private func symbol(for reason: OnboardSession.ReplanReason) -> String {
        switch reason {
        case .cancelled: return "xmark.octagon.fill"
        case .earlier: return "hare.fill"
        default: return "arrow.triangle.branch"
        }
    }

    private func tint(for reason: OnboardSession.ReplanReason) -> Color {
        switch reason {
        case .cancelled: return .red
        case .earlier: return .green
        default: return .orange
        }
    }

    private func proposalRow(_ proposal: OnboardSession.ReplanProposal) -> some View {
        HStack(spacing: 10) {
            if let transit = proposal.firstTransit {
                LinePill(line: transit.routeShortName ?? "", mode: transit.mode, agency: transit.agencyId, width: 42, height: 26, fontSize: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(formatTime(transit.startTime)) · \(session.placeName(transit.from))")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(transit.headsign.map { String(localized: "Direction \($0)") } ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "figure.walk")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 42)
                Text("À pied jusqu'à destination")
                    .font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                Text(formatTime(proposal.arrival))
                    .font(.headline)
                    .monospacedDigit()
                let minutes = Int((proposal.lateBy / 60).rounded())
                if minutes != 0 {
                    Text(minutes > 0 ? "+\(minutes) min" : "\(minutes) min")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(minutes > 0 ? .orange : .green)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
