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
                        EmptyStateContent(viewModel: viewModel)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.showMinCharactersMessage)
                .animation(.easeInOut(duration: 0.3), value: viewModel.searchResults.isEmpty)
                .animation(.easeInOut(duration: 0.3), value: viewModel.showTripResults)
                .animation(.easeInOut(duration: 0.3), value: viewModel.trips.isEmpty)
            }
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

// MARK: - Trip Results Content
struct TripResultsContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @State private var appearAnimation = false
    
    var body: some View {
        ZStack {
            if viewModel.isLoadingTrips {
                LoadingView()
                    .transition(.opacity)
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    viewModel.searchTrips()
                }
            } else if viewModel.trips.isEmpty && viewModel.directs.isEmpty {
                NoResultsView()
            } else {
                resultsList
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appearAnimation = true
            }
        }
    }
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel.directs.isEmpty {
                        ForEach(viewModel.directs.indices, id: \.self) { index in
                            let itinerary = viewModel.directs[index]
                            TripResultView(itinerary: itinerary)
                                .id("direct-\(index)")
                                .opacity(appearAnimation ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(Double(viewModel.trips.count + index) * 0.05), value: appearAnimation)
                        }
                        
                        if !viewModel.trips.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                                .padding(.horizontal, 32)
                        }
                    }
                    ForEach(viewModel.trips.indices, id: \.self) { index in
                        let itinerary = viewModel.trips[index]
                        TripResultView(itinerary: itinerary)
                            .id("trip-\(index)")
                            .opacity(appearAnimation ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.05), value: appearAnimation)
                    }
                }
                .padding(.vertical, 20)
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

struct EmptyStateContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @EnvironmentObject var shortcutManager: ShortcutManager
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolEffect(.pulse, options: .repeating, value: isAnimating)
                .padding(.top, 60)
            
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
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(ScaleButtonStyle())
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
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
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
