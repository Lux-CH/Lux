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
    @ObservedObject var settings = Settings.shared

    @State private var showSettings: Bool = false
    @StateObject private var stopsViewModel = StopsViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var shortcutManager: ShortcutManager
    @State private var selectedShortcut: UserShortcut? = nil
    @State private var showTripSearch: Bool = false
    @Namespace private var animation
    @Environment(\.colorScheme) private var colorScheme
    
    // Gesture state for drag/swipe
    @GestureState private var dragTranslation: CGSize = .zero
    
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
                LinearGradient(
                    colors: colorScheme == .dark
                    ? [Color(.systemBackground), Color(.systemBackground).opacity(0.8)]
                    : [Color(.secondarySystemBackground), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: viewMode == .stops && settings.reduceSpacerBtwnStopContent ? -47 : 0) {
                    // Header
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(colorScheme == .dark
                                  ? Color(.secondarySystemBackground).opacity(0.7)
                                  : Color.white)
                            .frame(height: headerHeight)
                            .clipShape(
                                .rect(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: viewMode == .stops && settings.reduceSpacerBtwnStopContent ? 0 : 40,
                                    bottomTrailingRadius: viewMode == .stops && settings.reduceSpacerBtwnStopContent ? 0 : 40,
                                    topTrailingRadius: 0,
                                    style: .continuous
                                )
                            )
                            .shadow(
                                color: Color.black.opacity(viewMode == .stops && settings.reduceSpacerBtwnStopContent ? 0.0 : 0.05),
                                radius: viewMode == .stops && settings.reduceSpacerBtwnStopContent ? 0 : 10,
                                x: 0,
                                y: viewMode == .stops ? 0 : 5
                            )
                            .animation(smoothSpring, value: headerHeight)
                        
                        VStack {
                            if viewMode == .home {
                                HStack {
                                    shortcutsRow
                                    
                                    Button {
                                        showSettings.toggle()
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
                                .sheet(isPresented: $showSettings) {
                                    SettingsView()
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
                                        print("should be searching for geocoding..")
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
                    .zIndex(viewMode == .stops && settings.reduceSpacerBtwnStopContent ? 1 : 0)
                    
                    // Content
                    ZStack {
                        Rectangle()
                            .fill(colorScheme == .dark
                                  ? Color(.secondarySystemBackground).opacity(0.7)
                                  : Color.white)
                            .frame(maxHeight: .infinity)
                            .clipShape(
                                .rect(
                                    topLeadingRadius: viewMode == .stops && settings.reduceSpacerBtwnStopContent ? 0 : 38,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: viewMode == .stops && settings.reduceSpacerBtwnStopContent ? 0 : 38,
                                    style: .continuous
                                )
                            )
                            .shadow(
                                color: Color.black.opacity(viewMode == .stops ? 0.0 : 0.05),
                                radius: viewMode == .stops ? 0 : 8,
                                x: 0,
                                y: viewMode == .stops ? 0 : -4
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
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .local)
                            .updating($dragTranslation) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                let vertical = value.translation.height
                                if viewMode == .home && vertical < -50 {
                                    switchToStopsMode()
                                } else if viewMode == .stops && vertical > 150 {
                                    toggleViewMode(.home)
                                }
                            }
                    )
                }
                
                // Mode switcher
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $viewMode, onModeChange: { newMode in
                        toggleViewMode(newMode)
                    })
                }
                .ignoresSafeArea(.keyboard)
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
        .fullScreenCover(isPresented: $showTripSearch) {
            if let shortcut = selectedShortcut {
                TripsSearchView(
                    initialSearchResult: shortcut.toSearchResult(),
                    initialTargetField: .to
                )
            } else {
                TripsSearchView()
            }
        }
    }
    
    private var shortcutsRow: some View {
        HStack {
            ForEach(Array(shortcutManager.visibleShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                ShortcutButton(
                    symbol: shortcut.symbol,
                    coords: (shortcut.coordinates.latitude, shortcut.coordinates.longitude),
                    name: shortcut.name
                ) {
                    selectedShortcut = shortcut
                    showTripSearch = true
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            
            if shortcutManager.visibleShortcuts.isEmpty {
                Button {
                    showSettings = true
                } label: {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(Color.accentColor.opacity(0.5))
                                .font(.system(size: 20))
                            Text("Ajouter des raccourcis")
                                .foregroundColor(Color.accentColor.opacity(0.5))
                        }
                    }
                    .frame(width: 275, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.secondary.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 2, dash: [6])
                                   )
                            .background(
                                Color(.secondarySystemFill)
                                    .opacity(0.3)
                                    .cornerRadius(20)
                            )
                    )
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            else if shortcutManager.visibleShortcuts.count < 2 {
                ForEach(0..<(2 - shortcutManager.visibleShortcuts.count), id: \.self) { _ in
                    ShortcutButton(
                        symbol: "plus",
                        name: "Ajouter",
                        isPlaceholder: true
                    ) {
                        showSettings = true
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
    }
    
    func toggleViewMode(_ newMode: ViewMode) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        if newMode == .stops {
            stopsViewModel.isLoading = true
        }
        
        withAnimation(smoothSpring) {
            viewMode = newMode
            headerHeight = newMode == .home ? 215 : 135
        }
        
        if newMode == .stops {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if !stopsViewModel.isSearchMode {
                    stopsViewModel.loadNearbyStops(showLoading: false)
                }
            }
        } else {
            stopsViewModel.resetSearch()
        }
    }
    
    func switchToStopsMode() {
        stopsViewModel.isLoading = true
        
        withAnimation(smoothSpring) {
            viewMode = .stops
            headerHeight = 135
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            stopsViewModel.loadNearbyStops(showLoading: false)
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
