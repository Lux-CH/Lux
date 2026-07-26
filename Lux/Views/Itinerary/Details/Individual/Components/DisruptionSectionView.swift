//
//  DisruptionSectionView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.05.2025.
//

import SwiftUI
import LuxCom

struct DisruptionSectionView: View {
    let disruptions: [Disruption]
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if !disruptions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    HapticFeedback.lightImpact()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text("Perturbations (\(disruptions.count))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.red)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(disruptions.enumerated()), id: \.element.id) { index, disruption in
                        DisruptionCardView(disruption: disruption)
                            .opacity(isExpanded ? 1 : 0)
                            .scaleEffect(isExpanded ? 1 : 0.95, anchor: .top)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.05),
                                value: isExpanded
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, isExpanded ? 12 : 0)
                .frame(maxHeight: isExpanded ? .infinity : 0)
                .clipped()
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
            }
            .adaptable(ios26: .glassIn(AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous))), fallback: {
                $0.background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemGray6))
                )
            })
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

struct DisruptionCardView: View {
    let disruption: Disruption
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            let (title, description) = extractTitleAndDesc(disruption.lineDisruption)
            VStack(alignment: .leading, spacing: 4) {
                if !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(12)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .adaptable(ios26: .glassTintedIn(AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous)), colorScheme == .dark ? Color(.tertiarySystemBackground) : Color.white), fallback: {
            $0.background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color.white)
            )
        })
    }
    private func extractTitleAndDesc(_ raw: String) -> (String, String) {
        let disr = raw.decodingHTMLEntities()
        if let range = disr.range(of: " - ") {
            let title = String(disr[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let desc = String(disr[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (title, desc)
        } else {
            return ("", disr)
        }
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
