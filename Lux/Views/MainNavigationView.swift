//
//  MainNavigationView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import LuxCom

enum ViewMode: CaseIterable {
    case home
    case stops

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .stops: return "signpost.right.fill"
        }
    }
    var title: String {
        switch self {
        case .home: return "Home"
        case .stops: return "Stops"
        }
    }
}

struct MainNavigationView: View {
    @State private var viewMode: ViewMode = .home
    @State private var headerHeight: CGFloat = 215
    @State private var searchText: String = ""
    @StateObject private var stopsViewModel = StopsViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @Namespace private var animation
    
    // Animation configs
    private let contentExitTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.96))),
        removal: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.96)))
    )
    
    private let contentEntryTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96))),
        removal: .opacity.combined(with: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96)))
    )
    
    // curves
    private let quickSpring = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)
    private let smoothSpring = Animation.spring(response: 0.55, dampingFraction: 0.75, blendDuration: 0.3)
    private let contentTransition = Animation.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0.3)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .opacity(0.9)
                
                VStack(spacing: 0) {
                    // Header
                    ZStack(alignment: .top) {
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
                        
                        VStack {
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
                                            .cornerRadius(20)
                                    }
                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                                }
                                .padding(.top, 65)
                                .padding(.bottom, 5)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
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
                    
                    // Content
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
                            
                            if viewMode == .stops {
                                VStack(spacing: 0) {
                                    VStack(alignment: .leading) {
                                        SectionTitleView(isSearchMode: stopsViewModel.isSearchMode)
                                            .transition(.asymmetric(
                                                insertion: .move(edge: .leading).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)
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
                
                // Mode switcher
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $viewMode)
                        .onChange(of: viewMode) {
                            toggleViewMode()
                        }
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(smoothSpring) {
            if viewMode == .home {
                viewMode = .stops
                headerHeight = 135
            } else {
                viewMode = .home
                headerHeight = 215
                stopsViewModel.resetSearch()
            }
        }
        
        if viewMode == .stops {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !stopsViewModel.isSearchMode {
                    stopsViewModel.loadNearbyStops(showLoading: false)
                }
            }
        }
    }
    
    func switchToStopsMode() {
        stopsViewModel.isLoading = true
        
        withAnimation(smoothSpring) {
            viewMode = .stops
            headerHeight = 135
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !stopsViewModel.isSearchMode {
                stopsViewModel.loadNearbyStops(showLoading: false)
            }
        }
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
