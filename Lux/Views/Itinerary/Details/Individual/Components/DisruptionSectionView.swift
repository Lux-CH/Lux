//
//  DisruptionSectionView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.05.2025.
//

import SwiftUI
import LuxCom

struct DisruptionGroup: Identifiable {
    let id: String
    let leg: Leg?
    let disruptions: [Disruption]
}

private struct OpenDisruptionsKey: EnvironmentKey {
    static let defaultValue: (([DisruptionGroup]) -> Void)? = nil
}

extension EnvironmentValues {
    var openDisruptions: (([DisruptionGroup]) -> Void)? {
        get { self[OpenDisruptionsKey.self] }
        set { self[OpenDisruptionsKey.self] = newValue }
    }
}

struct DisruptionSectionView: View {
    let disruptions: [Disruption]

    var body: some View {
        DisruptionsRow(groups: [DisruptionGroup(id: "leg", leg: nil, disruptions: disruptions)])
    }
}

struct DisruptionsRow: View {
    let groups: [DisruptionGroup]
    var action: (() -> Void)?
    @Environment(\.openDisruptions) private var openDisruptions

    private var all: [Disruption] { groups.flatMap(\.disruptions) }

    var body: some View {
        if !all.isEmpty {
            if action != nil || openDisruptions != nil {
                Button {
                    HapticFeedback.lightImpact()
                    if let action { action() } else { openDisruptions?(groups) }
                } label: {
                    label
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    DisruptionsListView(groups: groups)
                } label: {
                    label
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { HapticFeedback.lightImpact() })
            }
        }
    }

    private var label: some View {
        let count = all.count
        return HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.orange)
            Text(count == 1 ? String(localized: "1 perturbation") : String(localized: "\(count) perturbations"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct DisruptionsListView: View {
    let groups: [DisruptionGroup]
    @Environment(\.dismiss) private var dismiss

    private struct Entry: Identifiable {
        let id: String
        let leg: Leg?
        let disruption: Disruption
    }

    private struct Category: Identifiable {
        let id: String
        let entries: [Entry]

        var symbol: String {
            let name = id.lowercased()
            if name.contains("travaux") || name.contains("chantier") { return "wrench.and.screwdriver.fill" }
            if name.contains("manifestation") || name.contains("événement") { return "flag.fill" }
            if name.contains("dévi") { return "arrow.triangle.turn.up.right.diamond.fill" }
            if name.contains("information") || name.contains("info") { return "info.circle.fill" }
            return "exclamationmark.triangle.fill"
        }

        var color: Color {
            let name = id.lowercased()
            if name.contains("manifestation") || name.contains("événement") { return .purple }
            if name.contains("information") || name.contains("info") || name.contains("dévi") { return .blue }
            if name.contains("travaux") || name.contains("chantier") { return .orange }
            return .red
        }
    }

    private var showsLines: Bool { groups.count > 1 }

    private var categories: [Category] {
        var order: [String] = []
        var entries: [String: [Entry]] = [:]
        for group in groups {
            for disruption in group.disruptions {
                let name = disruption.shortTitle.prefix(1).uppercased() + disruption.shortTitle.dropFirst()
                if entries[name] == nil { order.append(name) }
                entries[name, default: []].append(Entry(id: "\(group.id)-\(disruption.id)", leg: group.leg, disruption: disruption))
            }
        }
        return order.map { Category(id: $0, entries: entries[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            Image(systemName: category.symbol)
                                .foregroundStyle(category.color)
                            Text(category.id)
                            Text("\(category.entries.count)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.leading, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(category.entries.enumerated()), id: \.element.id) { index, entry in
                                row(entry)
                                if index < category.entries.count - 1 {
                                    Divider().padding(.leading, showsLines ? 58 : 14)
                                }
                            }
                        }
                        .adaptable(ios26: .glassTintedIn(AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous)), Color(.systemBackground).opacity(0.35)), fallback: {
                            $0.background(Color(.tertiarySystemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        })
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .toolbar(.hidden, for: .navigationBar)
        .modifier(ClearNavigationBackground())
    }

    private var header: some View {
        ZStack {
            Text("Perturbations")
                .font(.headline)
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .adaptable(ios26: .glassButton, fallback: {
                            $0.background(Color(.secondarySystemFill), in: Circle())
                        })
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Retour"))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func row(_ entry: Entry) -> some View {
        let title = entry.disruption.displayTitle
        let headline = title.count > 28 ? title : nil
        return HStack(alignment: .top, spacing: 10) {
            if showsLines, let leg = entry.leg {
                LinePill(line: leg.routeShortName ?? "", mode: leg.mode, agency: leg.agencyId, width: 34, height: 20, fontSize: 11)
            }
            VStack(alignment: .leading, spacing: 3) {
                if let headline {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                }
                Text(entry.disruption.displayText)
                    .font(headline == nil ? .subheadline : .footnote)
                    .foregroundStyle(headline == nil ? .primary : .secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct ClearNavigationBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.containerBackground(.clear, for: .navigation)
        } else {
            content
        }
    }
}

extension Disruption {
    var displayTitle: String {
        if text != nil { return (title ?? "").decodingHTMLEntities() }
        let raw = lineDisruption.decodingHTMLEntities()
        guard let range = raw.range(of: " - ") else { return "" }
        return String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
    }

    var displayText: String {
        if let text { return text.decodingHTMLEntities() }
        let raw = lineDisruption.decodingHTMLEntities()
        guard let range = raw.range(of: " - ") else { return raw }
        return String(raw[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    var shortTitle: String {
        let title = displayTitle
        return title.isEmpty || title.count > 28 ? String(localized: "Perturbation") : title
    }

    var summary: String {
        let title = displayTitle
        return title.count > 28 ? title : displayText
    }
}

private extension String {
    static let namedHTMLEntities: [String: Character] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00A0}", "eacute": "é", "egrave": "è", "ecirc": "ê", "euml": "ë",
        "agrave": "à", "acirc": "â", "ccedil": "ç", "ocirc": "ô", "ouml": "ö",
        "ugrave": "ù", "ucirc": "û", "uuml": "ü", "icirc": "î", "iuml": "ï",
        "Eacute": "É", "Egrave": "È", "Agrave": "À", "Ccedil": "Ç",
        "oelig": "œ", "OElig": "Œ", "deg": "°", "laquo": "«", "raquo": "»",
        "rsquo": "\u{2019}", "lsquo": "\u{2018}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        "hellip": "\u{2026}", "ndash": "\u{2013}", "mdash": "\u{2014}"
    ]

    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }
        var result = ""
        result.reserveCapacity(count)
        var index = startIndex
        while index < endIndex {
            let char = self[index]
            guard char == "&",
                  let semicolon = self[index...].prefix(10).firstIndex(of: ";"),
                  semicolon > self.index(after: index) else {
                result.append(char)
                index = self.index(after: index)
                continue
            }
            let entity = self[self.index(after: index)..<semicolon]
            var decoded: Character?
            if entity.first == "#" {
                let numeric = entity.dropFirst()
                let scalar: UInt32?
                if numeric.first == "x" || numeric.first == "X" {
                    scalar = UInt32(numeric.dropFirst(), radix: 16)
                } else {
                    scalar = UInt32(numeric)
                }
                if let scalar, let unicode = Unicode.Scalar(scalar) {
                    decoded = Character(unicode)
                }
            } else {
                decoded = Self.namedHTMLEntities[String(entity)]
            }
            if let decoded {
                result.append(decoded)
                index = self.index(after: semicolon)
            } else {
                result.append(char)
                index = self.index(after: index)
            }
        }
        return result
    }
}
