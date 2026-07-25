//
//  TripsSearchContentView.swift
//  Lux
//
//  Created by Constantin Clerc on 26.07.2025.
//

import SwiftUI

struct TripsSearchContentView: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var settings = Settings.shared
    
    var body: some View {
        ZStack {
            contentBackground
            
            VStack(spacing: 0) {
                Group {
                    if viewModel.showTripResults {
                        TripResultsContent(viewModel: viewModel)
                    } else if viewModel.isSearchActive {
                        SearchResultsContent(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        if (viewModel.activeSearchField == .from || viewModel.activeSearchField == .to) &&
                            viewModel.fromQuery.isEmpty && viewModel.toQuery.isEmpty &&
                            viewModel.searchResults.isEmpty && !viewModel.showMinCharactersMessage && settings.showHistory {
                            SearchHistoryContent(viewModel: viewModel)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            EmptyStateContent(viewModel: viewModel)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.showMinCharactersMessage)
                .animation(.easeInOut(duration: 0.3), value: viewModel.searchResults.isEmpty)
                .animation(.easeInOut(duration: 0.3), value: viewModel.showTripResults)
                .animation(.easeInOut(duration: 0.3), value: viewModel.trips.isEmpty)
            }
            .clipShape(
                .rect(
                    topLeadingRadius: 38,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 38,
                    style: .continuous
                )
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var contentBackground: some View {
        RoundedRectangle(cornerRadius: 38, style: .continuous)
            .fill(
                colorScheme == .dark
                    ? Color(.secondarySystemBackground).opacity(0.7)
                    : Color.white
            )
            .clipShape(
                .rect(
                    topLeadingRadius: 38,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 38,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                radius: 12,
                x: 0,
                y: -4
            )
    }
}

struct TripResultsContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel

    var body: some View {
        ZStack {
            if viewModel.isLoadingTrips {
                TripResultsSkeletonView()
                    .transition(.opacity)
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    viewModel.searchTrips()
                }
            } else if viewModel.trips.isEmpty && viewModel.directs.isEmpty {
                NoResultsView()
            } else {
                resultsList
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isLoadingTrips)
    }
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel.directs.isEmpty {
                        ForEach(viewModel.directs.indices, id: \.self) { index in
                            let itinerary = viewModel.directs[index]
                            TripResultView(itinerary: itinerary, destinationName: viewModel.selectedTo?.displayName)
                                .id("direct-\(index)")
                        }
                        
                        if !viewModel.trips.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                                .padding(.horizontal, 32)
                        }
                    }
                    ForEach(viewModel.trips.indices, id: \.self) { index in
                        let itinerary = viewModel.trips[index]
                        TripResultView(itinerary: itinerary, destinationName: viewModel.selectedTo?.displayName)
                            .id("trip-\(index)")
                    }
                }
                .padding(.vertical, 20)
            }
            .safeAreaInset(edge: .bottom) {
                Spacer().frame(height: 80)
            }
            .onChange(of: viewModel.trips) {
                if !viewModel.trips.isEmpty && viewModel.animateIn {
                    withAnimation {
                        proxy.scrollTo("trip-0", anchor: .top)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            PaginationControlsView(
                isLoadingEarlier: $viewModel.isLoadingEarlier,
                isLoadingLater: $viewModel.isLoadingLater,
                isChangingContent: $viewModel.isChangingContent,
                isLoading: viewModel.isLoadingTrips,
                animateIn: $viewModel.animateIn,
                loadEarlier: { viewModel.loadEarlier() },
                loadLater: { viewModel.loadLater() }
            )
        }
    }
}

struct TripResultsSkeletonView: View {
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    TripResultSkeletonCard()
                }
            }
            .padding(.vertical, 20)
        }
        .scrollDisabled(true)
        .opacity(pulse ? 0.55 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityLabel("Recherche d'itinéraires")
    }
}

struct TripResultSkeletonCard: View {
    private let pillWidths: [CGFloat] = [42, 28, 54, 34, 46]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .frame(width: 128, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .frame(width: 66, height: 26)
            }
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .frame(width: 86, height: 14)
            HStack(spacing: 8) {
                ForEach(Array(pillWidths.enumerated()), id: \.offset) { _, width in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .frame(width: width, height: 22)
                }
            }
            .frame(height: 48, alignment: .center)
        }
        .foregroundStyle(.quaternary)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}

struct EmptyStateContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @EnvironmentObject var shortcutManager: ShortcutManager
    @ObservedObject var progress = Progress.shared
    @State private var isAnimating = false
    @State private var showingSuggestion: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            if progress.numOfTimesTripViewWasOpened == 1 {
                HintIndicatorView(icon: "chevron.compact.up",
                                  message: String(localized: "Glissez vers le haut pour retourner sur l'écran d'accueil"),
                                  delay: 1,
                                  duration: 15,
                                  onDismiss: {showingSuggestion = false})
                .onAppear {
                    showingSuggestion = true
                }
                .padding(.top, 20)
                Spacer()
            }
            Image(systemName: "map")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolEffect(.pulse, options: .repeating, value: isAnimating)
                .padding(.top, showingSuggestion ? 5 : 60)
            
            Text("Entrez un point de départ et une destination")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .transition(.scale.combined(with: .opacity))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: 12) {
                if viewModel.isCurrentPositionAvailable() {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            viewModel.selectCurrentPosition()
                            HapticFeedback.lightImpact()
                        }
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("Utiliser ma position actuelle")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accentColor.opacity(0.15))
                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.5)
                        )
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.top, shortcutManager.shortcuts.isEmpty ? 5 : 0)
                }
                
                if !shortcutManager.shortcuts.isEmpty {
                    Text("Raccourcis")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    ScrollView {
                        ForEach(shortcutManager.shortcuts) { shortcut in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.handleInitialSearchResult(shortcut.toSearchResult(), targetField: viewModel.activeSearchField)
                                    HapticFeedback.lightImpact()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: shortcut.symbol)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shortcut.name)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Text(shortcut.coordinates.locationName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.secondary.opacity(0.1))
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                )
                                
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Spacer().frame(height: 15)
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
                }
                else {
                    Spacer()
                }
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}
