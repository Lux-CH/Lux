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
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(viewModel.searchHistory.enumerated()), id: \.element.id) { index, result in
                            historyRow(for: result)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(colorScheme == .dark ?
                                              Color(.systemBackground).opacity(0.8) :
                                              Color(.systemBackground))
                                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                                )
                                .contentShape(Rectangle())
                                .padding(.horizontal)
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(y: appearAnimation ? 0 : 10)
                                .animation(
                                    .spring(response: 0.3, dampingFraction: 0.75)
                                        .delay(Double(index) * 0.05),
                                    value: appearAnimation
                                )
                        }
                    }
                    .padding(.bottom, 16)
                }
                .safeAreaInset(edge: .bottom) {
                    Spacer().frame(height: 12)
                }
                .mask(
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black, Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                    }
                )
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { appearAnimation = true }
                    }
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text(String(localized: "Historique"))
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            Button {
                HapticFeedback.lightImpact()
                showClearHistoryAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                    Text(String(localized: "Effacer"))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.5)
                        )
                )
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
        .padding(.horizontal)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private func historyRow(for result: SearchResult) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                viewModel.selectLocation(result)
                HapticFeedback.lightImpact()
            }
        }) {
            HStack(spacing: 12) {
                let (iconName, iconColor) = shortcutSymbol(for: result).map { ($0, Color.accentColor) } ?? getIconForType(result.type)
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                        .symbolRenderingMode(.hierarchical)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let area = relevantArea(result) {
                        Text(area)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .contentShape(Circle())
                    .onTapGesture {
                        HapticFeedback.mediumImpact()
                        withAnimation { viewModel.removeFromHistory(id: result.id) }
                    }
                    .accessibilityLabel(Text(String(localized: "Supprimer de l'historique")))
                    .accessibilityAddTraits(.isButton)
            }
        }
        .buttonStyle(ScaleButtonStyle())
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
    
    private func getIconForType(_ type: LocationType) -> (String, Color) {
        switch type {
        case .adress:
            return ("mappin.circle.fill", .red)
        case .place:
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

struct EmptyHistoryView: View {
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.top, 40)
                Text(String(localized: "Vos recherches récentes apparaîtront ici"))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity)
            Spacer()
        }
    }
}
