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
    
    private var sectionTitle: String {
        return isExpanded ? "Masquer les perturbations" : "Perturbations (\(disruptions.count))"
    }
    
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
                        
                        Text(sectionTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.red)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
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
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemGray6))
            )
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color.white)
        )
    }
    private func extractTitleAndDesc(_ disr: String) -> (String, String) {
        if let range = disr.range(of: " - ") {
            let title = String(disr[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let desc = String(disr[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (title, desc)
        } else {
            return ("", disr)
        }
    }
}
