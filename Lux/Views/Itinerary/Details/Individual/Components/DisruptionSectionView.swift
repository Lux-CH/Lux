//
//  DisruptionSectionView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.05.2025.
//

import SwiftUI
import LuxCom

struct DisruptionSectionView: View {
    let leg: Leg
    let disruptions: [Disruption]
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var hasDisruptions: Bool {
        !disruptions.isEmpty
    }
    
    private var disruptionCount: Int {
        disruptions.count
    }
    
    private var sectionTitle: String {
        if hasDisruptions {
            return isExpanded ? "Masquer les perturbations" : "Perturbations (\(disruptionCount))"
        } else {
            return "Aucune perturbation"
        }
    }
    
    private var titleColor: Color {
        hasDisruptions ? .red : .secondary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                if hasDisruptions {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }
            }) {
                HStack {
                    Circle()
                        .fill(hasDisruptions ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text(sectionTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(titleColor)
                    
                    Spacer()
                    
                    if hasDisruptions {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(titleColor)
                            .rotationEffect(.degrees(isExpanded ? 0 : 0))
                    }
                }
            }
            .disabled(!hasDisruptions)
            
            if isExpanded && hasDisruptions {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(disruptions) { disruption in
                        DisruptionCardView(disruption: disruption)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemGray6))
        )
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color.white)
        )
    }
    private func extractTitleAndDesc(_ disr: String) -> (String, String) {
        let parts = disr.components(separatedBy: " - ")

        if parts.count >= 2 {
            let title = parts[0].trimmingCharacters(in: .whitespaces)
            let desc = parts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)

            return(title, desc)
        } else {
            return ("", disr)
        }
    }
}
