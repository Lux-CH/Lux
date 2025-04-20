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
    
    // Animation configuration
    private let animation = Animation.spring(response: 0.5, dampingFraction: 0.7)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .opacity(0.9)
                
                VStack(spacing: 0) {
                    // Header section (animates height)
                    ZStack(alignment: .top) {
                        // Background shape
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
                        
                        // Header content
                        VStack {
                            // Show shortcuts only in home mode
                            if viewMode == .home {
                                HStack {
                                    ShortcutButton(symbol: "house", coords: (0.0, 0.0))
                                    ShortcutButton(symbol: "suitcase", coords: (0.0, 0.0))
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
                                }
                                .padding(.top, 65)
                                .padding(.bottom, 5)
                                .opacity(viewMode == .home ? 1 : 0)
                                .animation(animation, value: viewMode)
                            }
                            
                            // Animated unified search bar
                            AnimatedSearchBar(
                                searchText: viewMode == .home ? $searchText : $stopsViewModel.searchQuery,
                                placeholderText: viewMode == .home ? "Aller à..." : "Rechercher un arrêt...",
                                onSearch: {
                                    if viewMode == .stops {
                                        stopsViewModel.performSearch()
                                    } else {
                                        switchToStopsMode()
                                    }
                                },
                                onClear: {
                                    if viewMode == .stops {
                                        stopsViewModel.resetSearch()
                                    } else {
                                        searchText = ""
                                    }
                                },
                                topPadding: viewMode == .home ? 0 : 55
                            )
                            .padding(.top, viewMode == .home ? 0 : 55)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // Content section
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
                        
                        // Content - switches between home and stops content
                        if viewMode == .home {
                            VStack(alignment: .center) {
                                NearbyStopsView(onStopTap: switchToStopsMode)
                                Spacer()
                            }
                            .opacity(viewMode == .home ? 1 : 0)
                            .animation(animation.delay(0.1), value: viewMode)
                        } else {
                            StopsContentView(
                                isSearchMode: stopsViewModel.isSearchMode,
                                isLoading: stopsViewModel.isLoading,
                                searchResults: stopsViewModel.searchResults,
                                showMinCharactersMessage: stopsViewModel.showMinCharactersMessage,
                                locationManager: locationManager
                            )
                            .opacity(viewMode == .stops ? 1 : 0)
                            .animation(animation.delay(0.1), value: viewMode)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
                
                // Mode switch button
                VStack {
                    Spacer()
                    Button(action: toggleViewMode) {
                        Image(systemName: viewMode == .home ? "bus.fill" : "house.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 16)
                    .transition(.scale)
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
        withAnimation(animation) {
            if viewMode == .home {
                viewMode = .stops
                headerHeight = 135 // Stops header height
                if !stopsViewModel.isSearchMode {
                    stopsViewModel.loadNearbyStops(showLoading: true)
                }
            } else {
                viewMode = .home
                headerHeight = 215 // Home header height
                stopsViewModel.resetSearch()
            }
        }
    }
    
    func switchToStopsMode() {
        withAnimation(animation) {
            viewMode = .stops
            headerHeight = 135
        }
    }
}
