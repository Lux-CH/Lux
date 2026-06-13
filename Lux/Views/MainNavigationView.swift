//
//  MainNavigationView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import Combine
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
        case .home: return String(localized: "Accueil")
        case .stops: return String(localized: "Arrêts")
        case .search: return "Search"
        }
    }
}

struct MainNavigationView: View {
    @State private var viewMode: ViewMode = .home
    @State private var headerHeight: CGFloat = 215
    @State private var searchText: String = ""
    @ObservedObject var settings = Settings.shared
    @ObservedObject var progress = Progress.shared
    @FocusState private var isSearchBarFocused: Bool

    @State private var showSettings: Bool = false
    @State private var showShortcutsSettings: Bool = false
    @State private var showLuxPass: Bool = false
    @StateObject private var stopsViewModel = StopsViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var shortcutManager: ShortcutManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var lastLocationUpdateTime: Date = Date.distantPast
    
    @State private var initialScreenSize: CGSize = .zero
    @State private var hasInitializedScreenSize = false
    
    private let ultraSmoothSpring = Animation.interactiveSpring(response: 0.4, dampingFraction: 0.85, blendDuration: 0.1)
    private let contentSpring = Animation.interactiveSpring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.15)
    private let searchTransitionSpring = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.1)
    
    private let searchModeTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)).combined(with: .offset(y: -10)),
        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)).combined(with: .offset(y: 10))
    )
    
    private let contentTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.97, anchor: .top)),
        removal: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.97, anchor: .top))
    )
    
    @State private var isSearchTransitioning: Bool = false
    @State private var searchViewModel = TripsSearchViewModel()
    @FocusState private var isFromFocused: Bool
    @FocusState private var isToFocused: Bool
    
    @State private var isAnimatingToSearch: Bool = false
    @State private var searchBarOffset: CGFloat = 0
    
    @State private var searchDragOffset: CGFloat = 0
    @State private var upcomingSavedItinerary: SavedItineraryRecord?
    
    private let itineraryRefreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private static let itineraryTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
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
                    .gesture(viewMode == .search ? searchModeDragGesture : nil) // replacing nil by mainNavGesture doesnt seem to work and the compiler can't figure it out
                    .simultaneousGesture(mainNavGesture)
                    
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
                                        bottomLeadingRadius: viewMode == .stops && settings.reduceSpacerBtwnStopContentView ? 0 : 40,
                                        bottomTrailingRadius: viewMode == .stops && settings.reduceSpacerBtwnStopContentView ? 0 : 40,
                                        topTrailingRadius: 0,
                                        style: .continuous
                                    )
                                )
                                .shadow(
                                    color: Color.black.opacity(viewMode == .stops && settings.reduceSpacerBtwnStopContentView ? 0.0 : 0.05),
                                    radius: viewMode == .stops && settings.reduceSpacerBtwnStopContentView ? 0 : 10,
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
                                            GlassEffectGroup(spacing: 6) {
                                                HStack {
                                                    shortcutsRow
                                                    
                                                    Button {
                                                        showSettings.toggle()
                                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                                    } label: {
                                                        Image(systemName: "gearshape")
                                                            .foregroundColor(Color.primary.opacity(0.6))
                                                            .font(.system(size: 20))
                                                            .frame(width: 61, height: 52.5)
                                                            .accessibilityLabel("Paramètres")
                                                            .accessibilityHint("Double-tapez pour ouvrir les paramètres de l'application")
                                                    }
                                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                                                    .cornerRadius(35)
                                                    .adaptable(ios26: .glassButtonClear, fallback: {
                                                        $0.background(
                                                            Color(.secondarySystemFill).opacity(0.5),
                                                            in: Capsule(style: .continuous)
                                                        ).overlay(
                                                            Capsule(style: .continuous)
                                                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                                        )
                                                    })
                                                }
                                                .padding(.horizontal, 20)
                                                .sheet(isPresented: $showSettings) {
                                                    SettingsView()
                                                        .environmentObject(shortcutManager)
                                                        .presentationCornerRadius(36)
                                                }
                                                .sheet(isPresented: $showShortcutsSettings) {
                                                    NavigationStack {
                                                        ShortcutsListView()
                                                            .navigationTitle("Raccourcis")
                                                            .presentationCornerRadius(36)
                                                    }
                                                }
                                                .sheet(isPresented: $showLuxPass) {
                                                    LuxPassView(showSwisspassOnHome: $settings.swisspassOnHome, isFromHome: true)
                                                        .presentationDetents([.medium])
                                                        .presentationCornerRadius(36)
                                                }
                                                .padding(.top, 65)
                                                .padding(.bottom, 5)
                                            }
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                        
                                        GlassEffectGroup(spacing: 6) {
                                            AnimatedSearchBar(
                                                searchText: viewMode == .home ? $searchText : $stopsViewModel.searchQuery,
                                                placeholderText: viewMode == .home ?
                                                (progress.numOfTimesTripViewWasOpened <= 1 ?
                                                    String(localized: "Où souhaitez-vous aller ?") :
                                                    String(localized: "Aller à...")) :
                                                String(localized: "Rechercher un arrêt..."),
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
                                                },
                                                isTextFieldDisabled: viewMode == .home
                                            )
                                            .focused($isSearchBarFocused)
                                            .simultaneousGesture(
                                                TapGesture().onEnded {
                                                    if viewMode == .home {
                                                        transitionToSearchMode()
                                                    }
                                                }
                                            )
                                            .accessibilityAction(.default) {
                                                if viewMode == .home {
                                                    transitionToSearchMode()
                                                }
                                            }
                                            .accessibilityLabel(viewMode == .home ? "Recherche de destination" : "")
                                            .accessibilityHint(viewMode == .home ? "Double-tapez pour ouvrir la recherche d'itinéraires" : "")
                                            .accessibilityAddTraits(viewMode == .home ? .isSearchField : [])
                                            .padding(.top, viewMode == .home ? 0 : topSafeAreaInset + 5)
                                            .padding(.leading, 17.5)
                                            // trailing pulled in slightly less than leading: the search bar's
                                            // large corner radius visually recedes vs. the tight gear button,
                                            // so its right edge needs to extend a touch further to *look* aligned.
                                            .padding(.trailing, 15.5)
                                            .offset(y: searchBarOffset)
                                            .animation(searchTransitionSpring, value: viewMode)
                                            .animation(ultraSmoothSpring, value: searchBarOffset)
                                        }
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
                        .zIndex(viewMode == .stops && settings.reduceSpacerBtwnStopContentView ? 1 : 0)
                        
                        ZStack {
                            Rectangle()
                                .fill(viewMode == .search ? Color.clear : (colorScheme == .dark
                                      ? Color(.secondarySystemBackground).opacity(0.7)
                                      : Color.white))
                                .frame(maxHeight: .infinity)
                                .clipShape(
                                    .rect(
                                        topLeadingRadius: viewMode == .stops && settings.reduceSpacerBtwnStopContentView ? 0 : 38,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: viewMode == .stops && settings.reduceSpacerBtwnStopContentView ? 0 : 38,
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
                                        .animation(.interactiveSpring(), value: searchDragOffset)
                                        .gesture(searchModeDragGesture)
                                        .transition(searchModeTransition)
                                }
                            }
                            .animation(contentSpring, value: viewMode)
                        }
                        .offset(y: max(0, -(searchDragOffset)))
                        .ignoresSafeArea(edges: .bottom)
                        .simultaneousGesture(mainNavGesture)
                    }
                    
                    if viewMode != .search {
                        VStack {
                            Spacer()
                            CustomTabBar(selectedTab: $viewMode, onModeChange: { newMode in
                                toggleViewMode(newMode)
                            })
                            .overlay {
                                OfflineModeBadge()
                                    .background {
                                        if viewMode == .stops {
                                            ZStack {
                                                Capsule(style: .continuous)
                                                    .fill(
                                                        Color(.secondarySystemBackground)
                                                    )
                                                    .shadow(
                                                        color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15),
                                                        radius: 7.5,
                                                        x: 0,
                                                        y: 5
                                                    )
                                                Capsule(style: .continuous)
                                                    .fill(
                                                        colorScheme == .dark
                                                        ? Color(.secondarySystemBackground).opacity(0.7)
                                                        : Color.white
                                                    )
                                                    .stroke(
                                                        colorScheme == .dark
                                                        ? Color.primary.opacity(0.1)
                                                        : Color.gray.opacity(0.1),
                                                        lineWidth: 0.75
                                                    )
                                            }
                                            .frame(width: 350, height: 65)
                                        }
                                    }
                            }
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
            locationManager.startMonitoring()
            stopsViewModel.setupLocationManager(locationManager)
            searchViewModel.setupLocationManager(locationManager)
            refreshUpcomingSavedItinerary()
        }
        .onDisappear {
            locationManager.stopMonitoring()
            stopsViewModel.cancelBackgroundTasks()
        }
        .onChange(of: locationManager.location) {
            let now = Date()
            
            if now.timeIntervalSince(lastLocationUpdateTime) >= 2.5 {
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
        .onReceive(itineraryRefreshTimer) { _ in
            if scenePhase == .active && viewMode == .home {
                refreshUpcomingSavedItinerary()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .savedItinerariesDidChange)) { _ in
            refreshUpcomingSavedItinerary()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadNearbyStops"))) { _ in
            if viewMode == .stops && !stopsViewModel.isSearchMode {
                stopsViewModel.loadNearbyStops(showLoading: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            locationManager.resumeUpdates()
            refreshUpcomingSavedItinerary()
            if viewMode == .stops && !stopsViewModel.isSearchMode {
                if stopsViewModel.searchResults.isEmpty {
                    stopsViewModel.loadNearbyStops(showLoading: true)
                } else {
                    stopsViewModel.refreshNearbyStopsInBackground()
                }
            }
        }
    }
    
    private var searchModeDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 1.0)) {
                    searchDragOffset = min(0, value.translation.height)
                }
            }
            .onEnded { value in
                if value.translation.height < -50 {
                    exitSearchMode()
                } else {
                    searchDragOffset = 0
                }
            }
    }
    
    private var mainNavGesture: some Gesture {
        viewMode != .search ?
        DragGesture(minimumDistance: 5, coordinateSpace: .local)
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
    }
    
    private var shortcutsRow: some View {
        HStack {
            if upcomingSavedItinerary == nil && shortcutManager.visibleShortcuts.isEmpty && !settings.swisspassOnHome {
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .adaptable(ios26: .glassButtonClear, fallback: {
                        $0
                            .background(
                                Color(.secondarySystemFill).opacity(0.3),
                                in: Capsule(style: .continuous)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        Color.secondary.opacity(0.3),
                                        style: StrokeStyle(lineWidth: 2, dash: [6])
                                    )
                            )
                    })
                    .overlay{
                        if #available(iOS 26, *) {
                            Capsule(style: .continuous)
                                .stroke(Color.secondary.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 2, dash: [6])
                                )
                        }
                    }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                if let savedItinerary = upcomingSavedItinerary {
                    savedItineraryShortcutButton(for: savedItinerary)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .accessibilityLabel("Itinéraire enregistré")
                        .accessibilityAddTraits(.isButton)
                } else if let firstShortcut = shortcutManager.visibleShortcuts.first {
                    ShortcutButton(
                        symbol: firstShortcut.symbol,
                        name: firstShortcut.name
                    ) {
                        transitionToSearchModeWithShortcut(firstShortcut)
                    }
                    .accessibilityLabel("Raccourcis \(firstShortcut.name)")
                    .accessibilityAddTraits(.isButton)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    ShortcutButton(
                        symbol: "plus",
                        name: "Ajouter",
                        isPlaceholder: true
                    ) {
                        showShortcutsSettings = true
                    }
                    .accessibilityLabel("Ajouter un raccourci")
                    .accessibilityAddTraits(.isButton)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                
                if settings.swisspassOnHome {
                    Button {
                        showLuxPass = true
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "person.text.rectangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 20))
                                if settings.showShortcutLabel {
                                    Text("LuxPass")
                                        .foregroundColor(.red)
                                        .font(.system(size: 15))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52.5)
                        .adaptable(ios26: .glassButtonClear, fallback: {
                            $0
                                .background(
                                    Color(.secondarySystemFill).opacity(0.5),
                                    in: Capsule(style: .continuous)
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(
                                            Color.primary.opacity(0.1),
                                            style: StrokeStyle(lineWidth: 0.5)
                                        )
                                )
                        })
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .accessibilityLabel("Raccourcis SwissPass")
                } else {
                    let secondShortcutIndex = upcomingSavedItinerary == nil ? 1 : 0
                    if shortcutManager.visibleShortcuts.indices.contains(secondShortcutIndex) {
                        let secondShortcut = shortcutManager.visibleShortcuts[secondShortcutIndex]
                        ShortcutButton(
                            symbol: secondShortcut.symbol,
                            name: secondShortcut.name
                        ) {
                            transitionToSearchModeWithShortcut(secondShortcut)
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .accessibilityLabel("Raccourcis \(secondShortcut.name)")
                        .accessibilityAddTraits(.isButton)
                    } else {
                        ShortcutButton(
                            symbol: "plus",
                            name: "Ajouter",
                            isPlaceholder: true
                        ) {
                            showShortcutsSettings = true
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .accessibilityLabel("Ajouter un raccourci")
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
    }

    private func savedItineraryShortcutButton(for savedItinerary: SavedItineraryRecord) -> some View {
        NavigationLink(destination: savedItineraryDestinationView(for: savedItinerary)) {
            itineraryShortcutLabel(for: savedItinerary)
        }
        .simultaneousGesture(TapGesture().onEnded {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        })
    }

    @ViewBuilder
    private func savedItineraryDestinationView(for savedItinerary: SavedItineraryRecord) -> some View {
        if let itinerary = SavedItineraryStorage.shared.loadItinerary(from: savedItinerary.fileURL) {
            ItineraryView(itinerary: itinerary, fromNearby: false)
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Itinéraire indisponible")
                    .font(.headline)
                Text("Ce trajet n'est plus disponible.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                refreshUpcomingSavedItinerary()
            }
        }
    }

    private func itineraryShortcutLabel(for savedItinerary: SavedItineraryRecord) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Color.green.opacity(0.85))
                    .font(.system(size: 20))

                if settings.showShortcutLabel {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Itinéraire")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.green.opacity(0.85))

                        Text(itineraryTimeLabel(for: savedItinerary.itinerary))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.green.opacity(0.7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52.5)
        .adaptable(ios26: .glassButtonClearTinted(Color.green.opacity(0.25)), fallback: {
            $0
                .background(
                    Color.green.opacity(0.16),
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            Color.green.opacity(0.35),
                            style: StrokeStyle(lineWidth: 0.8)
                        )
                )
        })
    }

    private func itineraryTimeLabel(for itinerary: Itinerary) -> String {
        let formatter = MainNavigationView.itineraryTimeFormatter
        let departure = formatter.string(from: itinerary.startTime)
        let arrival = formatter.string(from: itinerary.endTime)
        return "\(departure) → \(arrival)"
    }

    private func refreshUpcomingSavedItinerary(referenceDate: Date = Date()) {
        withAnimation(ultraSmoothSpring) {
            upcomingSavedItinerary = SavedItineraryStorage.shared.loadUpcomingItinerary(referenceDate: referenceDate)
        }
    }
    
    private func transitionToSearchMode() {
        guard !isSearchTransitioning else { return }
        
        isSearchTransitioning = true
        
        searchViewModel.toQuery = searchText

        withAnimation(searchTransitionSpring) {
            isAnimatingToSearch = true
            searchBarOffset = -20
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
            withAnimation(searchTransitionSpring) {
                viewMode = .search
                headerHeight = 225
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
        progress.numOfTimesTripViewWasOpened+=1 // only here because shortcuts are not considered purely "intentionals"
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
                headerHeight = 225
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
            headerHeight = newMode == .home ? 215 : max(135, topSafeAreaInset + 75)
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
            headerHeight = max(135, topSafeAreaInset + 75)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            stopsViewModel.loadNearbyStops(showLoading: false)
        }
        progress.numOfTimesStopViewWasOpened += 1
    }
    
    private var topSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 44
    }

    // doing cas par cas is a really ugly solution
    private func compactSize() -> CGFloat {
        if viewMode == .search {
            return -10
        } else if viewMode == .stops && settings.reduceSpacerBtwnStopContentView {
            /*
             from 30min of simulator testing:
             model, height, padding
             16 pm ; 860: -62
             16 plus, 15pm, 15 plus, 14 pro max; 839: -59
             16 pro, 14 pro ; 778: -62
             16, 15 pro, 15; 759: -59
             13, 16e, 14, 13 pro, 12, 12 pro; 763: -47
             14 plus, 13 pm, 12pm; 845: -47
             13mini, 12mini; 728: -50
             Se (2/3); 647: -20

             11, XR; 814: -48
             11 pm, XSMax; 818: -44
             11 pro, XS; 734: -44
             */
            let height = initialScreenSize.height
            switch height {
            case 860, 778:
                return -62
            case 839, 759:
                return -59
            case 728:
                return -50
            case 814:
                return -48
            case 763, 845:
                return -47
            case 818, 734:
                return -44
            case 647:
                return -20
            default:
                return -50
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
