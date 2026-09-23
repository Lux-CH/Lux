//
//  OnboardIntro.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI

struct OnboardIntroCallout: View {
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nouveau")
                        .font(.caption2.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.accentColor)
                    Text("Laissez Lux vous guider")
                        .font(.subheadline.weight(.bold))
                    Text("Guidage pas à pas, alerte avant votre arrêt et retards en direct.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .frame(width: 210, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .adaptable(ios26: .glassIn(AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous))), fallback: {
                $0.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
            })
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Masquer"))
    }
}
