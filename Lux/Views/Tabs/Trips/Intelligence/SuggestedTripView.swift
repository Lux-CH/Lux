//
//  SuggestedTripView.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import SwiftUI
import LuxCom

struct SuggestedTripView: View {
    let suggestion: TripSuggestion
    let destinationName: String?
    let onCustomize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                IntelligenceHeader(weather: suggestion.weather, onCustomize: onCustomize)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(suggestion.reasons, id: \.self) { reason in
                        HStack(spacing: 8) {
                            Image(systemName: reason.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 18)
                            Text(reason.text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                    if suggestion.minutesLater > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text("\(suggestion.minutesLater) min de plus que le plus rapide")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 14)

            TripResultView(itinerary: suggestion.itinerary, destinationName: destinationName, horizontalInset: 0)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}

struct IntelligenceThinkingView: View {
    let onCustomize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IntelligenceHeader(weather: nil, onCustomize: onCustomize)
            Text("Analyse de la météo, de l'affluence et de vos habitudes…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}

private struct IntelligenceHeader: View {
    let weather: WeatherSnapshot?
    let onCustomize: () -> Void
    @ObservedObject private var store = IntelligenceStore.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, isActive: weather == nil && !store.profile.isConfigured)
            Text("Suggestion")
                .font(.system(size: 15, weight: .bold))

            if let weather {
                HStack(spacing: 4) {
                    Image(systemName: weather.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 12))
                    Text(weather.temperatureText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemFill).opacity(0.6), in: Capsule())
            }

            Spacer()

            Button {
                HapticFeedback.lightImpact()
                onCustomize()
            } label: {
                if store.profile.isConfigured {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                } else {
                    Text("Personnaliser")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(Text("Personnaliser Intelligent"))
        }
    }
}
