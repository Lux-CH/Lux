//
//  MainNavigationView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import LuxCom

enum ViewMode {
    case home
    case stops
}

struct MainNavigationView: View {
    @State private var viewMode: ViewMode = .home
    @State private var headerHeight: CGFloat = 215 // Home header default height
    @State private var searchText: String = ""
    @StateObject private var stopsViewModel = StopsViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @Namespace private var animation
    
    // Improved animation configurations
    private let contentExitTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.96))),
        removal: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.96)))
    )
    
    private let contentEntryTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.96))),
        removal: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.96)))
    )
    
    // Standard animation curves
    private let quickSpring = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)
    private let smoothSpring = Animation.spring(response: 0.55, dampingFraction: 0.7, blendDuration: 0.3)
    private let contentTransition = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .opacity(0.9)
                
                VStack(spacing: 0) {
                    // Header section (animates height) - Keeping this exactly as is per feedback
                    ZStack(alignment: .top) {
                        // Background shape with smoother animation
                        Rectangle()
                            .fill(Color(.secondarySystemBackground).opacity(0.8))
                            .frame(height: headerHeight)
                            .clipShape(
                                .rect(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 40,
                                    bottomTrailingRadius: 40,
                                    topTrailingRadius: 0,
                                    style: .continuous
                                )
                            )
                            .animation(smoothSpring, value: headerHeight)
                        
                        // Header content
                        VStack {
                            // Show shortcuts with improved animation
                            if viewMode == .home {
                                HStack {
                                    ShortcutButton(symbol: "house", coords: (0.0, 0.0))
                                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                                    ShortcutButton(symbol: "suitcase", coords: (0.0, 0.0))
                                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                                    Button {
                                        print("show settings")
                                    } label: {
                                        Image(systemName: "gearshape")
                                            .foregroundColor(Color.primary.opacity(0.6))
                                            .font(.system(size: 20))
                                            .frame(width: 61, height: 52.5)
                                            .background(Color(.secondarySystemFill).opacity(0.5))
                                            .cornerRadius(25)
                                    }
                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                                }
                                .padding(.top, 65)
                                .padding(.bottom, 5)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            // Animated unified search bar with improved animations
                            AnimatedSearchBar(
                                searchText: viewMode == .home ? $searchText : $stopsViewModel.searchQuery,
                                placeholderText: viewMode == .home ? "Aller à..." : "Rechercher un arrêt...",
                                onSearch: {
                                    if viewMode == .stops {
                                        withAnimation(quickSpring) {
                                            stopsViewModel.performSearch()
                                        }
                                    } else {
                                        switchToStopsMode()
                                    }
                                },
                                onClear: {
                                    if viewMode == .stops {
                                        withAnimation(quickSpring) {
                                            stopsViewModel.resetSearch()
                                        }
                                    } else {
                                        searchText = ""
                                    }
                                },
                                topPadding: viewMode == .home ? 0 : 55
                            )
                            .padding(.top, viewMode == .home ? 0 : 55)
                            .animation(smoothSpring, value: viewMode)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // Content section with improved transitions
                    ZStack {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground).opacity(0.8))
                            .frame(maxHeight: .infinity)
                            .clipShape(
                                .rect(
                                    topLeadingRadius: 38,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 38,
                                    style: .continuous
                                )
                            )
                        
                        ZStack {
                            if viewMode == .home {
                                VStack(alignment: .center) {
                                    NearbyStopsView(onStopTap: switchToStopsMode)
                                        .transition(.scale(scale: 0.97).combined(with: .opacity))
                                    Spacer()
                                }
                                .transition(contentExitTransition)
                            }
                            
                            // Stops content with improved transitions
                            if viewMode == .stops {
                                VStack(spacing: 0) {
                                    // Inverted transition for SectionTitleView - coming from bottom
                                    VStack(alignment: .leading) {
                                        SectionTitleView(isSearchMode: stopsViewModel.isSearchMode)
                                            .transition(.asymmetric(
                                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                                removal: .move(edge: .bottom).combined(with: .opacity)
                                            ))
                                            .animation(quickSpring, value: stopsViewModel.isSearchMode)
                                        
                                        Divider()
                                            .animation(quickSpring, value: stopsViewModel.isSearchMode)
                                    }
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .bottom).combined(with: .opacity)
                                    ))
                                    
                                    StopsContentView(
                                        isSearchMode: stopsViewModel.isSearchMode,
                                        isLoading: stopsViewModel.isLoading,
                                        searchResults: stopsViewModel.searchResults,
                                        showMinCharactersMessage: stopsViewModel.showMinCharactersMessage,
                                        locationManager: locationManager
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.97)),
                                        removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.97))
                                    ))
                                }
                                .transition(contentEntryTransition)
                            }
                        }
                        .animation(contentTransition, value: viewMode)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
                
                // Mode switch button with improved animation
                VStack {
                    Spacer()
                    Button(action: toggleViewMode) {
                        Image(systemName: viewMode == .home ? "bus.fill" : "house.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .scaleEffect(1.0)
                            .contentTransition(.symbolEffect(.replace.downUp))
                    }
                    .padding(.bottom, 16)
                    .buttonStyle(BouncyButtonStyle())
                }
            }
        }
        .onAppear {
            stopsViewModel.setupLocationManager(locationManager)
        }
        .onChange(of: locationManager.location) {
            if viewMode == .stops && !stopsViewModel.isSearchMode {
                stopsViewModel.checkLocationAndRefresh()
            }
        }
        .onReceive(stopsViewModel.refreshTimer) { _ in
            if viewMode == .stops && !stopsViewModel.isSearchMode {
                stopsViewModel.refreshNearbyStopsInBackground()
            }
        }
        .onDisappear {
            stopsViewModel.cancelBackgroundTasks()
        }
    }
    
    func toggleViewMode() {
        withAnimation(smoothSpring) {
            if viewMode == .home {
                viewMode = .stops
                headerHeight = 135
                if !stopsViewModel.isSearchMode {
                    stopsViewModel.loadNearbyStops(showLoading: true)
                }
            } else {
                viewMode = .home
                headerHeight = 215
                stopsViewModel.resetSearch()
            }
        }
    }
    
    func switchToStopsMode() {
        withAnimation(smoothSpring) {
            viewMode = .stops
            headerHeight = 135
        }
    }
}

// Custom button style for a bouncy effect
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
