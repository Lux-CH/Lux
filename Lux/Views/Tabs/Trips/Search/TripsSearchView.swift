//
//  TripsSearchView.swift
//  Lux
//
//  Created by Constantin Clerc on 29.04.2025.
//

import SwiftUI
import LuxCom

struct TripsSearchView: View {
    @StateObject private var viewModel = TripsSearchViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @FocusState private var isFromFocused: Bool
    @FocusState private var isToFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var dragOffset: CGFloat = 0
    @Namespace private var animation

    var initialSearchResult: SearchResult? = nil
    var initialTargetField: TripsSearchViewModel.SearchField = .to

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                    ? [Color(.systemBackground), Color(.systemBackground).opacity(0.92)]
                    : [Color(.secondarySystemBackground).opacity(0.7), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .gesture(dragGesture)
                
                VStack(spacing: 0) {
                    TripsSearchHeaderView(
                        viewModel: viewModel,
                        isFromFocused: $isFromFocused,
                        isToFocused: $isToFocused,
                        animation: animation
                    )
                    .gesture(dragGesture)
                    
                    TripsSearchContentView(
                        viewModel: viewModel,
                        animation: animation
                    )
                    .offset(y: max(0, dragOffset))
                    .animation(.interactiveSpring(), value: dragOffset)
                    .gesture(dragGesture)
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                RouteOptionsView(routeOptions: viewModel.routeOptions) { newOptions in
                    viewModel.updateRouteOptions(newOptions)
                }
                .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            viewModel.setupLocationManager(locationManager)
            if let result = initialSearchResult {
                Task { @MainActor in
                    viewModel.handleInitialSearchResult(result, targetField: initialTargetField)
                }
            }
        }
        .onChange(of: viewModel.fromQuery) {
            viewModel.onChange(of: viewModel.fromQuery)
        }
        .onChange(of: viewModel.toQuery) {
            viewModel.onChange(of: viewModel.toQuery)
        }
    }
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 200 {
                    dismiss()
                } else {
                    dragOffset = 0
                }
            }
    }
}

// MARK: - Header View
struct TripsSearchHeaderView: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @FocusState.Binding var isFromFocused: Bool
    @FocusState.Binding var isToFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    var animation: Namespace.ID
    
    var body: some View {
        ZStack(alignment: .top) {
            headerBackground
            
            VStack(alignment: .center, spacing: 20) {
                HStack(spacing: 14) {
                    RouteIndicatorView()
                    
                    VStack(spacing: 18) {
                        fromSearchBar
                        
                        toSearchBar
                    }
                    
                    TripsSearchActionButtons(viewModel: viewModel)
                }
            }
            .padding(.top, 50)
            .padding(.horizontal, 20)
        }
        .ignoresSafeArea(edges: .top)
    }
    
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(
                colorScheme == .dark
                    ? Color(.secondarySystemBackground).opacity(0.8)
                    : Color.white
            )
            .frame(height: 205)
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 40,
                    bottomTrailingRadius: 40,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08),
                radius: 15,
                x: 0,
                y: 5
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.departureType)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.showTripResults)
    }
    
    private var fromSearchBar: some View {
        TripSearchBar(
            searchText: $viewModel.fromQuery,
            isFocused: $isFromFocused,
            placeholderText: "Depuis",
            selectedLocation: viewModel.selectedFrom,
            onSearch: { viewModel.performSearch(viewModel.fromQuery) },
            onClear: { viewModel.resetSearch() },
            onRemoveTag: {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.removeFromLocation()
                }
            },
            topPadding: 0,
            iconName: "location.circle.fill"
        )
        .onTapGesture {
            if viewModel.selectedFrom == nil {
                isFromFocused = true
                viewModel.setActiveSearchField(.from)
            }
        }
        .onChange(of: isFromFocused) {
            if isFromFocused {
                viewModel.setActiveSearchField(.from)
            }
        }
    }
    
    private var toSearchBar: some View {
        TripSearchBar(
            searchText: $viewModel.toQuery,
            isFocused: $isToFocused,
            placeholderText: "À",
            selectedLocation: viewModel.selectedTo,
            onSearch: { viewModel.performSearch(viewModel.toQuery) },
            onClear: { viewModel.resetSearch() },
            onRemoveTag: {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.removeToLocation()
                }
            },
            topPadding: 0,
            iconName: "mappin.circle.fill"
        )
        .onTapGesture {
            if viewModel.selectedTo == nil {
                isToFocused = true
                viewModel.setActiveSearchField(.to)
            }
        }
        .onChange(of: isToFocused) {
            if isToFocused {
                viewModel.setActiveSearchField(.to)
            }
        }
    }
}

// MARK: - Content View
struct TripsSearchContentView: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    var animation: Namespace.ID
    
    var body: some View {
        ZStack {
            contentBackground
            
            VStack(spacing: 0) {
                Group {
                    if viewModel.showTripResults {
                        TripResultsContent(viewModel: viewModel)
                    } else if viewModel.isSearchActive {
                        SearchResultsContent(viewModel: viewModel, animation: animation)
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
            } else if viewModel.trips.isEmpty {
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
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.trips.indices, id: \.self) { index in
                            let itinerary = viewModel.trips[index]
                            TripResultView(itinerary: itinerary)
                                .id("trip-\(index)")
                                .opacity(appearAnimation ? 1 : 0)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .safeAreaInset(edge: .bottom) {
                    Spacer().frame(height: 80)
                }
                .refreshable {
                    viewModel.searchTrips()
                }
                .onChange(of: viewModel.trips) {
                    if !viewModel.trips.isEmpty && viewModel.animateIn {
                        withAnimation {
                            proxy.scrollTo("trip-0", anchor: .top)
                        }
                    }
                }
            }
            
            if !viewModel.trips.isEmpty {
                VStack {
                    Spacer()
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
    }
}

// MARK: - Search Results Content
struct SearchResultsContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    var animation: Namespace.ID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if (viewModel.activeSearchField != .none && viewModel.fromQuery.isEmpty && viewModel.toQuery.isEmpty) && viewModel.isCurrentPositionAvailable() {
                CurrentLocationOption(viewModel: viewModel)
            } else if viewModel.showMinCharactersMessage {
                MinCharactersView()
            } else if !viewModel.searchResults.isEmpty {
                SearchResultsList(viewModel: viewModel, animation: animation)
            } else {
                EmptySearchView()
            }
        }
    }
}

// MARK: - Empty State Content
struct EmptyStateContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolEffect(.pulse, options: .repeating, value: isAnimating)
                .padding(.top, 60)
            
            Text("Entrez un point de départ et une destination")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .transition(.scale.combined(with: .opacity))
            
            Text("Nous vous aiderons à trouver le meilleur itinéraire")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, -8)
            
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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.15))
                    )
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 16)
            }
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

// MARK: - Helper Views
struct RouteIndicatorView: View {
    var body: some View {
        VStack(spacing: 22) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 14, height: 14)
            
            ForEach(0..<3) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 4, height: 4)
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 14, height: 14)
        }
        .padding(.vertical, 4)
    }
}

struct TripsSearchActionButtons: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showTimePicker = false
    @State private var isSwapping = false
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                    isSwapping = true
                    viewModel.swapLocations()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isSwapping = false
                    }
                }
            }) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(
                                viewModel.selectedFrom == nil && viewModel.selectedTo == nil
                                ? Color.accentColor.opacity(0.4)
                                : Color.accentColor
                            )
                    )
                    .rotationEffect(isSwapping ? Angle(degrees: 180) : .zero)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isSwapping)
            }
            .disabled(viewModel.selectedFrom == nil && viewModel.selectedTo == nil)
            .buttonStyle(SpringButtonStyle())
            
            HStack {
                settingsButton
                
                timeButton
            }
        }
    }
    
    private var settingsButton: some View {
        Button(action: {
            HapticFeedback.lightImpact()
            viewModel.showSettings = true
        }) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                )
        }
        .buttonStyle(SpringButtonStyle())
    }
    
    private var timeButton: some View {
        Button(action: {
            HapticFeedback.lightImpact()
            showTimePicker = true
        }) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                )
        }
        .buttonStyle(SpringButtonStyle())
        .popover(isPresented: $showTimePicker) {
            TripsSearchTimePickerView(
                selectedDate: $viewModel.selectedDate,
                departureType: $viewModel.departureType,
                showDatePicker: $showTimePicker
            ) {
                viewModel.changeDepartureType(viewModel.departureType)
            }
            .presentationCompactAdaptation(.popover)
        }
    }
}

struct LoadingView: View {
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .frame(width: 80, height: 80)
                
            Text("Recherche d'itinéraires...")
                .font(.headline)
                .foregroundColor(.secondary)
                .opacity(pulseAnimation ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                .onAppear {
                    pulseAnimation = true
                }
        }
        .padding(.top, 40)
        .transition(.opacity)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    @State private var isAnimatingIcon = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 46))
                .foregroundColor(.orange)
                .symbolEffect(.pulse, options: .repeating.speed(0.7), value: isAnimatingIcon)
                .onAppear {
                    isAnimatingIcon = true
                }
                
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
            Button("Réessayer") {
                HapticFeedback.mediumImpact()
                retryAction()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 10)
        }
        .padding(.top, 40)
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

struct NoResultsView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 46))
                .foregroundColor(.secondary)
                .symbolEffect(.bounce.up, options: .repeating.speed(0.5), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
                
            Text("Aucun itinéraire trouvé")
                .font(.headline)
                .foregroundColor(.secondary)
                
            Text("Essayez de modifier vos critères de recherche ou l'heure de départ.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 40)
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

struct CurrentLocationOption: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Localisation")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 22)
                .padding(.bottom, 12)
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    viewModel.selectCurrentPosition()
                    HapticFeedback.lightImpact()
                }
            }) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: "location.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                            .scaleEffect(isHovering ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isHovering)
                    }
                    
                    Text("Position Actuelle")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(isHovering ? 1 : 0.6)
                        .offset(x: isHovering ? 4 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isHovering)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ?
                              Color(.systemBackground).opacity(0.8) :
                              Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                )
                .padding(.horizontal)
                .onHover { hovering in
                    isHovering = hovering
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct MinCharactersView: View {
    @State private var isAnimatingText = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "character.cursor.ibeam")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 40)
            
            Text("Entrez au moins 3 caractères pour rechercher")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(isAnimatingText ? 1 : 0.7)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimatingText)
                .onAppear {
                    isAnimatingText = true
                }
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
        
        Spacer()
    }
}

struct SearchResultsList: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    var animation: Namespace.ID
    @State private var appearAnimation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Résultats")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 22)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                viewModel.selectLocation(result)
                                HapticFeedback.lightImpact()
                            }
                        }) {
                            SearchResultRow(result: result)
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
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(y: appearAnimation ? 0 : 10)
                                .animation(
                                    .spring(response: 0.3, dampingFraction: 0.75)
                                    .delay(Double(index) * 0.05),
                                    value: appearAnimation
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    appearAnimation = true
                }
            }
        }
        .onDisappear {
            appearAnimation = false
        }
    }
}

struct EmptySearchView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 40)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
            
            Text("Recherchez un lieu ou une adresse")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
        
        Spacer()
    }
}

// MARK: - Button Styles
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
            .background(isEnabled ? Color.accentColor : Color.accentColor.opacity(0.5))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: isEnabled ? Color.accentColor.opacity(0.4) : Color.clear, radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Haptic Feedback
struct HapticFeedback {
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    static func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

struct TripsSearchTimePickerView: View {
    @Binding var selectedDate: Date
    @Binding var departureType: DepartureType
    @Binding var showDatePicker: Bool
    var onApply: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var localDate: Date
    
    init(selectedDate: Binding<Date>, departureType: Binding<DepartureType>, showDatePicker: Binding<Bool>, onApply: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self._departureType = departureType
        self._showDatePicker = showDatePicker
        self.onApply = onApply
        self._localDate = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Picker("Type", selection: $departureType) {
                Text("Départ").tag(DepartureType.leaveAt)
                Text("Arrivée").tag(DepartureType.arriveBy)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .onAppear {
                if departureType != .leaveAt && departureType != .arriveBy {
                    departureType = .leaveAt
                }
            }
            
            DatePicker(
                "Sélectionner",
                selection: $localDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(.horizontal)
            .onChange(of: localDate) {
                HapticFeedback.selectionChanged()
            }
            
            if departureType == .leaveAt {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        localDate = Date()
                        HapticFeedback.lightImpact()
                    }
                } label: {
                    Label("Maintenant", systemImage: "clock.arrow.circlepath")
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                                .background(Color.accentColor.opacity(0.1).cornerRadius(8))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 4)
            }
            Divider()
                .padding(.horizontal)
            
            HStack {
                Button("Annuler") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showDatePicker = false
                        HapticFeedback.lightImpact()
                    }
                }
                .foregroundColor(.secondary)
                .buttonStyle(ScaleButtonStyle())
                
                Spacer()
                
                Button("Appliquer") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDate = localDate
                        showDatePicker = false
                        HapticFeedback.mediumImpact()
                        onApply()
                    }
                }
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(width: 300)
        .background(
            colorScheme == .dark ?
            Color(.secondarySystemBackground) :
                Color(.systemBackground)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}
