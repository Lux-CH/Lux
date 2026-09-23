//
//  OnboardConsentSheet.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI

struct OnboardConsentSheet: View {
    let onAnswer: (_ shares: Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            illustration
                .padding(.top, 34)

            Text("Aidez les autres voyageurs")
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            Text("Pendant que vous êtes à bord, Lux peut partager anonymement la position du véhicule.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 18) {
                point(
                    "location.fill", .blue,
                    title: String(localized: "La position du véhicule, pas la vôtre"),
                    text: String(localized: "Uniquement à bord, recalée sur le tracé de la ligne. Aucun identifiant, rien n'est conservé.")
                )
                point(
                    "clock.badge.checkmark.fill", .green,
                    title: String(localized: "Des retards pour tous"),
                    text: String(localized: "Des retards justes, mesurés depuis le véhicule, même quand il n'y a pas de temps réel.")
                )
                point(
                    "dot.radiowaves.up.forward", .orange,
                    title: String(localized: "Le véhicule en direct"),
                    text: String(localized: "Ceux qui l'attendent voient où il se trouve sur la carte.")
                )
                point(
                    "hand.raised.fill", .purple,
                    title: String(localized: "Vous gardez la main"),
                    text: String(localized: "S'arrête dès que vous descendez. Désactivable à tout moment, ici ou dans les réglages.")
                )
            }
            .padding(.top, 26)
            .padding(.horizontal, 6)

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                Button {
                    HapticFeedback.notification(type: .success)
                    onAnswer(true)
                } label: {
                    Text("Partager anonymement")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.accentColor.gradient, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    HapticFeedback.lightImpact()
                    onAnswer(false)
                } label: {
                    Text("Pas maintenant")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .interactiveDismissDisabled()
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 112, height: 112)
            Circle()
                .fill(Color.accentColor.gradient)
                .frame(width: 80, height: 80)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 12, y: 6)
            Image(systemName: "tram.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(.systemBackground)))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .offset(x: 38, y: -34)
                .symbolEffect(.variableColor.iterative, options: .repeating)
        }
    }

    private func point(_ symbol: String, _ color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        OnboardConsentSheet { _ in }
    }
}
