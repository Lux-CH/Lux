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
        case .home: return "Accueil"
        case .stops: return "Arrêts"
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
    @Environment(\.colorScheme) private var colorScheme
        
    @GestureState private var dragTranslation: CGSize = .zero
    
    @State private var lastLocationUpdateTime: Date = Date.distantPast
    private let locationUpdateThrottleInterval: TimeInterval = 2.5
    
    @State private var initialScreenSize: CGSize = .zero
    @State private var hasInitializedScreenSize = false
    
    // Animation configs
    private let ultraSmoothSpring = Animation.interactiveSpring(response: 0.4, dampingFraction: 0.85, blendDuration: 0.1)
    private let contentSpring = Animation.interactiveSpring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.15)
    private let searchTransitionSpring = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.1)
    
    // Enhanced transitions
    private let searchModeTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)).combined(with: .offset(y: -10)),
        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)).combined(with: .offset(y: 10))
    )
    
    private let contentTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.97, anchor: .top)),
        removal: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.97, anchor: .top))
    )
    
    @State private var toQuery: String = ""
    @State private var isSearchTransitioning: Bool = false
    @State private var searchViewModel = TripsSearchViewModel()
    @FocusState private var isFromFocused: Bool
    @FocusState private var isToFocused: Bool
    
    @State private var isAnimatingToSearch: Bool = false
    @State private var searchBarOffset: CGFloat = 0
    
    @State private var searchDragOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let screenSize = geometry.size
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
                    .gesture(viewMode == .search ? searchModeDragGesture : nil)
                    
                    VStack(spacing: compactSize()) {
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
                                                        .cornerRadius(35)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 35)
                                                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                                        )
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
                                            }
                                        )
                                        .focused($isSearchBarFocused)
                                        .disabled(viewMode == .home)
                                        .onTapGesture {
                                            if viewMode == .home {
                                                transitionToSearchMode()
                                            }
                                        }
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
                                        onBack: {exitSearchMode()}
                                    )
                                    .transition(searchModeTransition)
                                    .gesture(searchModeDragGesture)
                                    .zIndex(1)
                                }
                            }
                        }
                        .ignoresSafeArea(edges: .top)
                        .zIndex(viewMode == .stops && settings.reduceSpacerBtwnStopContent ? 1 : 0)
                        
                        ZStack {
                            Rectangle()
                                .fill(viewMode == .search ? Color.clear : (colorScheme == .dark
                                      ? Color(.secondarySystemBackground).opacity(0.7)
                                      : Color.white))
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
                                    color: viewMode == .search ? Color.clear.opacity(0) : Color.black.opacity(viewMode == .stops ? 0.0 : 0.05),
                                    radius: viewMode == .search ? 0 : (viewMode == .stops ? 0 : 8),
                                    x: 0,
                                    y: viewMode == .search ? 0 : (viewMode == .stops ? 0 : -4)
                                )
                                .animation(ultraSmoothSpring, value: viewMode)
                            
                            ZStack {
                                if viewMode == .home {
                                    VStack(alignment: .center) {
                                        NearbyStopsView()
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
                                        .onAppear {
                                            if !hasInitializedScreenSize {
                                                initialScreenSize = screenSize
                                                hasInitializedScreenSize = true
                                            }
                                        }
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.97)),
                                            removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.97))
                                        ))
                                    }
                                    .transition(contentTransition)
                                } else if viewMode == .search {
                                    TripsSearchContentView(viewModel: searchViewModel)
                                        .offset(y: max(0, searchDragOffset))
                                        .animation(.interactiveSpring(), value: searchDragOffset)
                                        .gesture(searchModeDragGesture)
                                        .transition(searchModeTransition)
                                }
                            }
                            .animation(contentSpring, value: viewMode)
                        }
                        .ignoresSafeArea(edges: .bottom)
                        .simultaneousGesture(
                            viewMode != .search ?
                            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                                .updating($dragTranslation) { value, state, _ in
                                    state = value.translation
                                }
                                .onEnded { value in
                                    let vertical = value.translation.height
                                    let horizontal = abs(value.translation.width)
                                    
                                    if horizontal < 100 {
                                        if viewMode == .home && vertical < -50 {
                                            switchToStopsMode()
                                        } else if viewMode == .home && vertical > 100 {
                                            transitionToSearchMode()
                                        } else if viewMode == .stops && vertical > 150 {
                                            toggleViewMode(.home)
                                        }
                                    }
                                }
                            : nil
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
                .ignoresSafeArea(.keyboard)
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
        }
        .onDisappear {
            stopsViewModel.cancelBackgroundTasks()
        }
        .onChange(of: locationManager.location) {
            let now = Date()
            
            if now.timeIntervalSince(lastLocationUpdateTime) >= locationUpdateThrottleInterval {
                lastLocationUpdateTime = now
                updateShortcutsWithCurrentLocation()
            }
            
            if viewMode == .stops && !stopsViewModel.isSearchMode {
                stopsViewModel.checkLocationAndRefresh()
            }
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
    
    // MARK: - Search Mode Drag Gestures
    private var searchModeDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                searchDragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 200 {
                    exitSearchMode()
                } else {
                    searchDragOffset = 0
                }
            }
    }
    
    private var shortcutsRow: some View {
        HStack {
            ForEach(Array(shortcutManager.visibleShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                ShortcutButton(
                    symbol: shortcut.symbol,
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
                        RoundedRectangle(cornerRadius: 35)
                            .stroke(Color.secondary.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 2, dash: [6])
                                   )
                            .background(
                                Color(.secondarySystemFill)
                                    .opacity(0.3)
                                    .cornerRadius(35)
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
                        showShortcutsSettings = true
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
            withAnimation(searchTransitionSpring) {
                viewMode = .search
                headerHeight = 205
            }
            
            searchText = ""
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if locationManager.authorizationStatus == .authorizedWhenInUse {
                withAnimation(ultraSmoothSpring) {
                    searchViewModel.selectCurrentPosition()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchViewModel.setActiveSearchField(.to)
                isToFocused = true
                
                withAnimation(ultraSmoothSpring) {
                    isAnimatingToSearch = false
                    searchBarOffset = 0
                    isSearchTransitioning = false
                }
                HapticFeedback.lightImpact()
            }
        }
        
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    
    private func transitionToSearchModeWithShortcut(_ shortcut: UserShortcut) {
        guard !isSearchTransitioning else { return }
        
        isSearchTransitioning = true
        
        let searchResult = shortcut.toSearchResult()
        
        withAnimation(searchTransitionSpring) {
            isAnimatingToSearch = true
            searchBarOffset = -15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
            withAnimation(searchTransitionSpring) {
                viewMode = .search
                headerHeight = 205
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if locationManager.authorizationStatus == .authorizedWhenInUse {
                withAnimation(ultraSmoothSpring) {
                    searchViewModel.selectCurrentPosition()
                    HapticFeedback.lightImpact()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 ) {
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
                searchDragOffset = 0
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
    private func updateShortcutsWithCurrentLocation() {
        guard settings.useTimeBasedRelevance else { return }
        
        withAnimation(ultraSmoothSpring) {
            shortcutManager.updateVisibleShortcuts(userLocation: locationManager.location)
        }
    }
    
    func toggleViewMode(_ newMode: ViewMode) {
        if newMode == .search { return }
        
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        
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
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        stopsViewModel.isLoading = true
        
        withAnimation(ultraSmoothSpring) {
            viewMode = .stops
            headerHeight = 135
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            stopsViewModel.loadNearbyStops(showLoading: false)
        }
    }
    
    // doing cas par cas is a really ugly solution
    private func compactSize() -> CGFloat {
        if viewMode == .stops && settings.reduceSpacerBtwnStopContent {
            let height = initialScreenSize.height
            if height >= 840 {
                return -62
            }
            else if height <= 728 {
                return -50
            } else if height == 778 {
                return -62
            } else {
                return -47
            }
        }
        return 0
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
