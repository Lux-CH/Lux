//
//  SearchHistoryContent.swift
//  Lux
//
//  Created by Constantin Clerc on 08.01.2026.
//

import SwiftUI
import LuxCom

struct SearchHistoryContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @ObservedObject private var visualStyleStore = SearchResultVisualStyleStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var shortcutManager: ShortcutManager
    @State private var appearAnimation = false
    @State private var showClearHistoryAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.searchHistory.isEmpty {
                EmptyStateContent(viewModel: viewModel)
            } else {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 11)

                ScrollView {
                    historyList
                        .padding(.horizontal, 16)
                    Spacer().frame(height: 40)
                }
                .scrollClipDisabled()
                .mask(
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black, Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 28)
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation { appearAnimation = true }
            }
        }
        .onDisappear { appearAnimation = false }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Historique")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()

            GlassEffectGroup(spacing: 6) {
                HStack(spacing: 6) {
                    if viewModel.isCurrentPositionAvailable() {
                        Button {
                            HapticFeedback.lightImpact()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                viewModel.selectCurrentPosition()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.accentColor)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 24)
                            .contentShape(Capsule(style: .continuous))
                            .clipShape(Capsule(style: .continuous))
                            .adaptable(ios26: .glassButtonTinted(Color.accentColor.opacity(0.12)), fallback: {
                                $0.background(
                                    Capsule(style: .continuous)
                                        .fill(Color.accentColor.opacity(0.12))
                                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.5)
                                )
                            })
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    Button {
                        HapticFeedback.lightImpact()
                        showClearHistoryAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.vertical, 5.5)
                        .padding(.horizontal, 24)
                        .foregroundColor(.red)
                        .contentShape(Capsule(style: .continuous))
                        .clipShape(Capsule(style: .continuous))
                        .adaptable(ios26: .glassButtonClear, fallback: {
                            $0.background(
                                Capsule(style: .continuous)
                                    .fill(Color(.secondarySystemFill).opacity(0.5))
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                        })
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .alert(String(localized: "Effacer l'historique ?"), isPresented: $showClearHistoryAlert) {
                        Button(String(localized: "Annuler"), role: .cancel) { }
                        Button(String(localized: "Effacer"), role: .destructive) {
                            HapticFeedback.mediumImpact()
                            withAnimation { viewModel.clearHistory() }
                        }
                    } message: {
                        Text(String(localized: "Cette action supprimera tous les éléments de l'historique."))
                    }
                }
            }
        }
    }

    private var historyList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.searchHistory.enumerated()), id: \.element.id) { index, result in
                historyRow(for: result, index: index)

                if index < viewModel.searchHistory.count - 1 {
                    Divider()
                        .padding(.leading, 68)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark
                    ? Color(.tertiarySystemBackground)
                    : Color(.secondarySystemBackground))
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.1),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func historyRow(for result: SearchResult, index: Int) -> some View {
        let defaultIcon: (String, Color) = visualStyleStore.style(for: result.id).map { ($0.symbolName, $0.color) }
            ?? getIconForType(result.type, id: result.id)
        let (iconName, iconColor) = shortcutSymbol(for: result).map { ($0, Color.accentColor) } ?? defaultIcon

        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let area = relevantArea(result) {
                    Text(area)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button {
                HapticFeedback.mediumImpact()
                withAnimation(.spring(response: 0.4)) {
                    viewModel.removeFromHistory(id: result.id)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(.tertiaryLabel))
                    .frame(width: 24, height: 24)
                    .background(Color(.quaternarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(localized: "Supprimer de l'historique")))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 8)
        .animation(
            .spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * 0.04),
            value: appearAnimation
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                viewModel.selectLocation(result)
                HapticFeedback.lightImpact()
            }
        }
    }

    private func relevantArea(_ result: SearchResult) -> String? {
        if let matchedArea = result.areas.first(where: { $0.matched }) {
            return matchedArea.name
        } else if let defaultArea = result.areas.first(where: { $0.default == true }) {
            return defaultArea.name
        } else if !result.areas.isEmpty {
            return result.areas.sorted(by: { $0.adminLevel < $1.adminLevel }).first?.name
        }
        return nil
    }

    private func getIconForType(_ type: LocationType, id: String = "") -> (String, Color) {
        switch type {
        case .adress:
            return ("mappin", .red)
        case .place:
            if id == "citaStop" {
                return ("signpost.right.fill", .accentColor)
            }
            return ("building.fill", .blue)
        case .stop:
            return ("signpost.right.fill", .accentColor)
        }
    }

    private func shortcutSymbol(for result: SearchResult) -> String? {
        if let matchByStop = shortcutManager.shortcuts.first(where: { $0.stopId == result.id }) {
            return matchByStop.symbol
        }
        if let matchByName = shortcutManager.shortcuts.first(where: { $0.name.localizedCaseInsensitiveCompare(result.name) == .orderedSame }) {
            return matchByName.symbol
        }
        return nil
    }
}
