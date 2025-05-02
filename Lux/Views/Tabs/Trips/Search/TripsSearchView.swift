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
    @Namespace private var animation
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(.systemBackground), Color(.systemBackground).opacity(0.92)]
                        : [Color(.secondarySystemBackground).opacity(0.7), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header section with search bars
                    TripsSearchHeaderView(
                        viewModel: viewModel,
                        isFromFocused: $isFromFocused,
                        isToFocused: $isToFocused,
                        animation: animation
                    )
                    
                    // Content area
                    TripsSearchContentView(
                        viewModel: viewModel,
                        animation: animation
                    )
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
        }
        .onChange(of: viewModel.fromQuery) {
            viewModel.onChange(of: viewModel.fromQuery)
        }
        .onChange(of: viewModel.toQuery) {
            viewModel.onChange(of: viewModel.toQuery)
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
            // Header background with dynamic height
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color(.secondarySystemBackground).opacity(0.8)
                        : Color.white
                )
                .frame(height: viewModel.departureType != .leaveNow && viewModel.showTripResults ? 255 : 205)
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
            
            VStack(alignment: .center, spacing: 20) {
                HStack(spacing: 14) {
                    // Route indicator dots and line
                    RouteIndicatorView()
                    
                    VStack(spacing: 18) {
                        // From search bar
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
                        
                        // To search bar
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
                    
                    // Action buttons
                    TripsSearchActionButtons(viewModel: viewModel)
                }
            }
            .padding(.top, 50)
            .padding(.horizontal, 20)
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Content View
struct TripsSearchContentView: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    var animation: Namespace.ID
    
    var body: some View {
        ZStack {
            // Content background
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
            
            VStack(spacing: 0) {
                Group {
                    if viewModel.showTripResults {
                        TripResultsContent(viewModel: viewModel)
                    } else if viewModel.isSearchActive {
                        SearchResultsContent(viewModel: viewModel, animation: animation)
                    } else {
                        EmptyStateContent(viewModel: viewModel)
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
}

// MARK: - Trip Results Content
struct TripResultsContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    
    var body: some View {
        ZStack {
            if viewModel.isLoadingTrips {
                // Loading state
                LoadingView()
            } else if let error = viewModel.errorMessage {
                // Error state
                ErrorView(message: error) {
                    viewModel.searchTrips()
                }
            } else if viewModel.trips.isEmpty {
                // No results state
                NoResultsView()
            } else {
                // Results list with pagination
                ZStack {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.trips, id: \.startTime) { itinerary in
                                TripResultView(itinerary: itinerary)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .center)))
                            }
                            .padding(.bottom, 70) // Add space for the pagination controls
                        }
                        .padding(.vertical, 20)
                    }
                    .refreshable {
                        viewModel.searchTrips()
                    }
                    
                    // Floating pagination controls
                    VStack {
                        Spacer()
                        
                        if !viewModel.trips.isEmpty {
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
    }
}

// MARK: - Search Results Content
struct SearchResultsContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    var animation: Namespace.ID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if (viewModel.activeSearchField != .none && viewModel.fromQuery.isEmpty && viewModel.toQuery.isEmpty) && viewModel.isCurrentPositionAvailable() {
                // Current location option
                CurrentLocationOption(viewModel: viewModel)
            } else if viewModel.showMinCharactersMessage {
                // Min characters message
                MinCharactersView()
            } else if !viewModel.searchResults.isEmpty {
                // Search results list
                SearchResultsList(viewModel: viewModel, animation: animation)
            } else {
                // Empty search prompt
                EmptySearchView()
            }
        }
    }
}

// MARK: - Empty State Content
struct EmptyStateContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolEffect(.pulse, options: .repeating, value: true)
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
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
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
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                    viewModel.swapLocations()
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
                            .shadow(
                                color: Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.4),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                    .symbolEffect(.bounce, value: viewModel.selectedFrom != nil || viewModel.selectedTo != nil)
            }
            .disabled(viewModel.selectedFrom == nil && viewModel.selectedTo == nil)
            .buttonStyle(SpringButtonStyle())
            
            HStack {
                // Settings button
                Button(action: {
                    viewModel.showSettings = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.accentColor)
                                .shadow(
                                    color: Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.4),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                }
                .buttonStyle(SpringButtonStyle())
                
                // Time selector button
                Button(action: {
                    showTimePicker = true
                }) {
                    Image(systemName: "clock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.accentColor)
                                .shadow(
                                    color: Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.4),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                }
                .buttonStyle(SpringButtonStyle())
                .popover(isPresented: $showTimePicker, attachmentAnchor: .point(.bottom)) {
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
        .offset(y: 15)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            LottieLoadingView()
                .frame(width: 80, height: 80)
                
            Text("Recherche d'itinéraires...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
        .transition(.opacity)
    }
}

struct LottieLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 5)
                .frame(width: 60, height: 60)
            
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 60, height: 60)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
        }
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 46))
                .foregroundColor(.orange)
                .symbolEffect(.pulse, options: .repeating.speed(0.7), value: true)
                
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
    }
}

struct NoResultsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 46))
                .foregroundColor(.secondary)
                
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
    }
}

struct CurrentLocationOption: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    
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
                    }
                    
                    Text("Position Actuelle")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Résultats")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 22)
                .padding(.bottom, 8)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.searchResults, id: \.id) { result in
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
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 40)
            
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: Color.accentColor.opacity(0.4), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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
}

struct TripsSearchTimePickerView: View {
    @Binding var selectedDate: Date
    @Binding var departureType: DepartureType
    @Binding var showDatePicker: Bool
    var onApply: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Type selector (Departure/Arrival)
            Picker("Type", selection: $departureType) {
                Text("Départ").tag(DepartureType.leaveAt)
                Text("Arrivée").tag(DepartureType.arriveBy)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Date and time picker
            if departureType != .leaveNow {
                DatePicker(
                    "Sélectionner",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal)
            }
            
            // "Now" button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    departureType = .leaveNow
                    selectedDate = Date()
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
            .padding(.top, 4)
            
            Divider()
                .padding(.horizontal)
            
            // Action buttons
            HStack {
                Button("Annuler") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showDatePicker = false
                    }
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Appliquer") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showDatePicker = false
                    }
                    onApply()
                }
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(width: 300)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
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
