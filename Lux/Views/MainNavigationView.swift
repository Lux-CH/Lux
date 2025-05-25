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
    case search

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .stops: return "signpost.right.fill"
        case .search: return ""
        }
    }
    var title: String {
        switch self {
        case .home: return "Home"
        case .stops: return "Stops"
        case .search: return "Search"
        }
    }
}

struct MainNavigationView: View {
    @State private var viewMode: ViewMode = .home
    @State private var headerHeight: CGFloat = 215
    @State private var searchText: String = ""
    @ObservedObject var settings = Settings.shared
    @FocusState private var isSearchBarFocused: Bool

    @State private var showSettings: Bool = false
    @State private var showShortcutsSettings: Bool = false
    @StateObject private var stopsViewModel = StopsViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var shortcutManager: ShortcutManager
    @State private var selectedShortcut: UserShortcut? = nil
    @State private var showTripSearch: Bool = false
    @Namespace private var animation
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var shortcutUpdateTimer: Timer?
    
    @GestureState private var dragTranslation: CGSize = .zero
    
    // Animation configs
    private let ultraSmoothSpring = Animation.interactiveSpring(response: 0.4, dampingFraction: 0.85, blendDuration: 0.1)
    private let contentSpring = Animation.interactiveSpring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.15)
    private let searchTransitionSpring = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.1)
    private let smoothSpring = Animation.spring(response: 0.55, dampingFraction: 0.75, blendDuration: 0.3)
    
    // Enhanced transitions
    private let searchModeTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)).combined(with: .offset(y: -10)),
        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)).combined(with: .offset(y: 10))
    )
    
    private let contentTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.97, anchor: .top)),
        removal: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.97, anchor: .top))
    )
    
    @State private var activeSearchField: TripsSearchViewModel.SearchField = .to
    @State private var fromQuery: String = ""
    @State private var toQuery: String = ""
    @State private var isSearchTransitioning: Bool = false
    @State private var searchViewModel = TripsSearchViewModel()
    @FocusState private var isFromFocused: Bool
    @FocusState private var isToFocused: Bool
    
    @State private var isAnimatingToSearch: Bool = false
    @State private var searchBarOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(
                        colors: colorScheme == .dark
                        ? [Color(.systemBackground), Color(.systemBackground).opacity(0.8)]
                        : [Color(.secondarySystemBackground), Color.white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .animation(ultraSmoothSpring, value: colorScheme)
                    
                    VStack(spacing: viewMode == .stops && settings.reduceSpacerBtwnStopContent ? -47 : 0) {
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
                                .animation(ultraSmoothSpring, value: headerHeight)
                                .animation(ultraSmoothSpring, value: viewMode)
                                .zIndex(0)
                            
                            Group {
                                if viewMode != .search {
                                    VStack {
                                        if viewMode == .home && !isAnimatingToSearch {
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
                                            .sheet(isPresented: $showShortcutsSettings) {
                                                NavigationStack {
                                                    ShortcutsListView()
                                                        .navigationTitle("Raccourcis")
                                                }
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
                                                    withAnimation(ultraSmoothSpring) {
                                                        stopsViewModel.performSearch()
                                                    }
                                                } else if viewMode == .home {
                                                    transitionToSearchMode()
                                                }
                                            },
                                            onClear: {
                                                if viewMode == .stops {
                                                    withAnimation(ultraSmoothSpring) {
                                                        stopsViewModel.resetSearch()
                                                    }
                                                } else {
                                                    searchText = ""
                                                }
                                            },
                                            topPadding: viewMode == .home ? 0 : 55
                                        )
                                        .focused($isSearchBarFocused)
                                        .padding(.top, viewMode == .home ? 0 : 55)
                                        .offset(y: searchBarOffset)
                                        .animation(searchTransitionSpring, value: viewMode)
                                        .animation(ultraSmoothSpring, value: searchBarOffset)
                                    }
                                    .opacity(isAnimatingToSearch ? 0 : 1)
                                    .animation(searchTransitionSpring, value: isAnimatingToSearch)
                                    .zIndex(1)
                                } else {
                                    TripsSearchHeaderView(
                                        viewModel: searchViewModel,
                                        isFromFocused: $isFromFocused,
                                        isToFocused: $isToFocused,
                                        animation: animation
                                    )
                                    .transition(searchModeTransition)
                                    .zIndex(1)
                                }
                            }
                        }
                        .ignoresSafeArea(edges: .top)
                        .zIndex(viewMode == .stops && settings.reduceSpacerBtwnStopContent ? 1 : 0)
                        
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
                                .animation(ultraSmoothSpring, value: viewMode)
                            
                            ZStack {
                                if viewMode == .home {
                                    VStack(alignment: .center) {
                                        NearbyStopsView(onStopTap: switchToStopsMode)
                                            .transition(.scale(scale: 0.97).combined(with: .opacity))
                                        Spacer()
                                    }
                                    .transition(contentTransition)
                                } else if viewMode == .stops {
                                    VStack(spacing: 0) {
                                        VStack(alignment: .leading) {
                                            SectionTitleView(isSearchMode: stopsViewModel.isSearchMode)
                                                .transition(.asymmetric(
                                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)
                                                ))
                                                .animation(ultraSmoothSpring, value: stopsViewModel.isSearchMode)
                                            
                                            Divider()
                                                .animation(ultraSmoothSpring, value: stopsViewModel.isSearchMode)
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
                                    .transition(contentTransition)
                                } else if viewMode == .search {
                                    TripsSearchContentView(
                                        viewModel: searchViewModel,
                                        animation: animation
                                    )
                                    .transition(searchModeTransition)
                                }
                            }
                            .animation(contentSpring, value: viewMode)
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
                    
                    if viewMode != .search {
                        VStack {
                            Spacer()
                            CustomTabBar(selectedTab: $viewMode, onModeChange: { newMode in
                                toggleViewMode(newMode)
                            })
                        }
                        .ignoresSafeArea(.keyboard)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(ultraSmoothSpring, value: viewMode == .search)
                    }
                }
                .overlay(
                    Group {
                        if viewMode == .search {
                            VStack {
                                HStack {
                                    Button(action: exitSearchMode) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                            .padding(10)
                                            .background(
                                                Circle()
                                                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                            )
                                    }
                                    .padding(.leading, 12)
                                    .padding(.top, 5)
                                    
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(.top, 50)
                            .transition(.opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.9)))
                        }
                    }
                )
                .ignoresSafeArea(.keyboard)
                .sheet(isPresented: $searchViewModel.showSettings) {
                    RouteOptionsView(routeOptions: searchViewModel.routeOptions) { newOptions in
                        searchViewModel.updateRouteOptions(newOptions)
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .keyboardToolbarIf(viewMode == .search) {
                ShortcutsKeyboardToolbar(
                    onShortcutSelected: { result in
                        let targetField: TripsSearchViewModel.SearchField = isFromFocused ? .from : .to
                        searchViewModel.handleInitialSearchResult(result, targetField: targetField)
                    },
                    onCurrentPositionSelected: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            searchViewModel.selectCurrentPosition()
                            HapticFeedback.lightImpact()
                        }
                    }
                )
            }
        }
        .onAppear {
            stopsViewModel.setupLocationManager(locationManager)
            searchViewModel.setupLocationManager(locationManager)
            setupShortcutUpdateTimer()
        }
        .onDisappear {
            stopsViewModel.cancelBackgroundTasks()
            stopShortcutUpdateTimer()
        }
        .onChange(of: locationManager.location) {
            if viewMode == .stops && !stopsViewModel.isSearchMode {
                stopsViewModel.checkLocationAndRefresh()
            }
            updateShortcutsWithCurrentLocation()
        }
        .onChange(of: settings.useTimeBasedRelevance) {
            updateShortcutsWithCurrentLocation()
        }
        .onChange(of: isSearchBarFocused) {
            if isSearchBarFocused && viewMode == .home && !isSearchTransitioning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if isSearchBarFocused {
                        transitionToSearchMode()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isSearchBarFocused = false
                        }
                    }
                }
            }
        }
        .onReceive(stopsViewModel.refreshTimer) { _ in
            if viewMode == .stops && !stopsViewModel.isSearchMode {
                stopsViewModel.refreshNearbyStopsInBackground()
            }
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
                    transitionToSearchModeWithShortcut(shortcut)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            
            if shortcutManager.visibleShortcuts.isEmpty {
                Button {
                    showShortcutsSettings = true
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
    
    private func transitionToSearchMode() {
        guard !isSearchTransitioning else { return }
        
        isSearchTransitioning = true
        
        toQuery = searchText
        searchViewModel.toQuery = searchText

        withAnimation(searchTransitionSpring) {
            isAnimatingToSearch = true
            searchBarOffset = -20
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(searchTransitionSpring) {
                viewMode = .search
                headerHeight = 205
            }
            
            searchText = ""
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if locationManager.authorizationStatus == .authorizedWhenInUse {
                withAnimation(ultraSmoothSpring) {
                    searchViewModel.selectCurrentPosition()
                    HapticFeedback.lightImpact()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchViewModel.setActiveSearchField(.to)
                isToFocused = true
                
                withAnimation(ultraSmoothSpring) {
                    isAnimatingToSearch = false
                    searchBarOffset = 0
                    isSearchTransitioning = false
                }
            }
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func transitionToSearchModeWithShortcut(_ shortcut: UserShortcut) {
        guard !isSearchTransitioning else { return }
        
        isSearchTransitioning = true
        
        let searchResult = shortcut.toSearchResult()
        
        withAnimation(searchTransitionSpring) {
            isAnimatingToSearch = true
            searchBarOffset = -15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(searchTransitionSpring) {
                viewMode = .search
                headerHeight = 205
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if locationManager.authorizationStatus == .authorizedWhenInUse {
                withAnimation(ultraSmoothSpring) {
                    searchViewModel.selectCurrentPosition()
                    HapticFeedback.lightImpact()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(ultraSmoothSpring) {
                    searchViewModel.handleInitialSearchResult(searchResult, targetField: .to)
                    
                    if searchViewModel.selectedFrom == nil {
                        isFromFocused = true
                        searchViewModel.setActiveSearchField(.from)
                    }
                    
                    isAnimatingToSearch = false
                    searchBarOffset = 0
                    isSearchTransitioning = false
                }
            }
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
    
    private func exitSearchMode() {
        guard !isSearchTransitioning else { return }
        
        isSearchTransitioning = true
        
        isFromFocused = false
        isToFocused = false
        
        withAnimation(searchTransitionSpring) {
            isAnimatingToSearch = true
            searchBarOffset = 15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(searchTransitionSpring) {
                viewMode = .home
                headerHeight = 215
                searchText = ""
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(ultraSmoothSpring) {
                isAnimatingToSearch = false
                searchBarOffset = 0
                isSearchTransitioning = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            searchViewModel = TripsSearchViewModel()
            searchViewModel.setupLocationManager(locationManager)
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Shortcut Update Methods
    
    private func setupShortcutUpdateTimer() {
        shortcutUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            if settings.useTimeBasedRelevance {
                updateShortcutsWithCurrentLocation()
            }
        }
    }
    
    private func stopShortcutUpdateTimer() {
        shortcutUpdateTimer?.invalidate()
        shortcutUpdateTimer = nil
    }
    
    private func updateShortcutsWithCurrentLocation() {
        guard settings.useTimeBasedRelevance else { return }
        
        withAnimation(ultraSmoothSpring) {
            shortcutManager.updateVisibleShortcuts(with: locationManager.location)
        }
    }
    
    func toggleViewMode(_ newMode: ViewMode) {
        if newMode == .search { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        if newMode == .stops {
            stopsViewModel.isLoading = true
        }
        
        withAnimation(ultraSmoothSpring) {
            viewMode = newMode
            headerHeight = newMode == .home ? 215 : 135
        }
        
        if newMode == .stops {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
        
        withAnimation(ultraSmoothSpring) {
            viewMode = .stops
            headerHeight = 135
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            stopsViewModel.loadNearbyStops(showLoading: false)
        }
    }
}

extension View {
    @ViewBuilder
    func keyboardToolbarIf<Content: View>(_ condition: Bool, @ViewBuilder content: @escaping () -> Content) -> some View {
        if condition {
            self.keyboardToolbar(view: content)
        } else {
            self
        }
    }
}
