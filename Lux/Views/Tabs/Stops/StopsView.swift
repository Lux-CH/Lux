//
//  StopsView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom
import CoreLocation

struct StopsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isLoading = false
    @State private var isSearchMode = false
    
    // Added to prevent flickering during search
    @State private var isSearchingInBackground = false
    
    // Reused from NearbyStopsView for refreshing logic
    @State private var lastFetchedLocation: CLLocation? = nil
    @State private var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var backgroundRefreshTask: Task<Void, Never>? = nil
    
    private let significantDistance: CLLocationDistance = 100.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.black)
                    .ignoresSafeArea()
                    .opacity(0.9)
                
                VStack(spacing: 0) {
                    // Header with search bar
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground).opacity(0.8))
                            .frame(maxHeight: .infinity)
                            .frame(height: 135)
                            .clipShape(
                                .rect(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 40,
                                    bottomTrailingRadius: 40,
                                    topTrailingRadius: 0,
                                    style: .continuous
                                )
                            )
                                                
                        HStack {
                            TextField("Aller à...", text: $searchQuery)
                                .padding(.vertical, 20)
                                .padding(.horizontal, 20)
                                .font(.system(size: 16, weight: .medium))
                                .onChange(of: searchQuery) {
                                    if searchQuery.isEmpty {
                                        isSearchMode = false
                                        loadNearbyStops(showLoading: false)
                                    }
                                    else {
                                        performSearch()
                                    }
                                }
                                .onSubmit {
                                    if !searchQuery.isEmpty {
                                        performSearch()
                                    }
                                }
                            
                            Spacer()
                            
                            
                            Button(action: {
                                if !searchQuery.isEmpty {
                                    performSearch()
                                }
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.accentColor)
                            }
                            .padding(.trailing, 18)
                        }
                        .frame(width: 350, height: 60)
                        .background(Color(.secondarySystemFill).opacity(0.5))
                        .cornerRadius(25)
                        .padding(.top, 55)
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // Content area
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
                        
                        VStack(alignment: .leading) {
                            // Title section with proximity icon
                            HStack {
                                Image(systemName: isSearchMode ? "magnifyingglass" : "location.fill")
                                Text(isSearchMode ? "Résultats de recherche" : "À proximité")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                // Show mini loading indicator for background searches
                                if isSearchingInBackground && !searchResults.isEmpty {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                            .padding(.top, 17)
                            .padding(.horizontal)
                            
                            // Orange line below the title
                            if !isSearchMode {
                                Divider()
                            }
                            
                            // Loading state - only show if there are no current results
                            if isLoading && searchResults.isEmpty {
                                ProgressView(isSearchMode ? "Recherche en cours..." : "Chargement des arrêts à proximité...")
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            // Empty state
                            else if searchResults.isEmpty {
                                Text(isSearchMode ? "Aucun résultat trouvé." : "Aucun arrêt à proximité trouvé.")
                                    .foregroundColor(.gray)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            // Results list
                            else {
                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(searchResults) { stop in
                                            NavigationLink(destination: IndividualStopView(stop: stop)) {
                                                stopRowView(stop: stop)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            if stop.id != searchResults.last?.id {
                                                Divider()
                                                    .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .onAppear {
            if searchResults.isEmpty && !isSearchMode {
                loadNearbyStops(showLoading: true)
            }
        }
        .onChange(of: locationManager.location) {
            if !isSearchMode {
                checkLocationAndRefresh()
            }
        }
        .onReceive(refreshTimer) { _ in
            if !isSearchMode {
                refreshNearbyStopsInBackground()
            }
        }
        .onDisappear {
            backgroundRefreshTask?.cancel()
        }
    }
    
    // MARK: - Stop Row View
    private func stopRowView(stop: SearchResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Stop name with icon
                HStack(spacing: 8) {
                    Image(systemName: "signpost.right")
                        .foregroundColor(.secondary)
                    
                    Text(stop.name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Distance calculation
                if let userLocation = locationManager.location {
                    let distance = calculateDistance(userLat: userLocation.coordinate.latitude,
                                                     userLon: userLocation.coordinate.longitude,
                                                     stopLat: stop.lat,
                                                     stopLon: stop.lon)
                    Text(formatDistance(distance))
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
                
                // Line pills horizontal scroll
                HStack(spacing: 4) {
                    LinePill(line: "80", mode: .bus)
                }
            }
            .padding(.vertical, 12)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    private func calculateDistance(userLat: Double, userLon: Double, stopLat: Double, stopLon: Double) -> Double {
        let userLocation = CLLocation(latitude: userLat, longitude: userLon)
        let stopLocation = CLLocation(latitude: stopLat, longitude: stopLon)
        return userLocation.distance(from: stopLocation)
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            let km = distance / 1000
            return "\(Int(km))km"
        } else {
            return "\(Int(distance))m"
        }
    }
    
    private func performSearch() {
        isSearchMode = true
        
        // Set background search flag but keep previous results visible
        isSearchingInBackground = true
        
        // Only show loading indicator if there are no current results
        if searchResults.isEmpty {
            isLoading = true
        }
        
        backgroundRefreshTask?.cancel()
        
        backgroundRefreshTask = Task {
            do {
                if let coords = locationManager.location?.coordinate {
                    let results = try await geocode(text: searchQuery, type: .stop, place: (coords.latitude, coords.longitude), placeBias: 15)
                    if !Task.isCancelled {
                        await MainActor.run {
                            // Update results only when we have them
                            searchResults = results
                            isLoading = false
                            isSearchingInBackground = false
                            backgroundRefreshTask = nil
                        }
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    print("Search error: \(error)")
                    await MainActor.run {
                        isLoading = false
                        isSearchingInBackground = false
                        backgroundRefreshTask = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Location-based Methods (Reused from NearbyStopsView)
    private func checkLocationAndRefresh() {
        guard let currentLoc = locationManager.location else { return }
        
        if let lastLoc = lastFetchedLocation {
            let distance = currentLoc.distance(from: lastLoc)
            if distance >= significantDistance {
                refreshNearbyStopsInBackground()
            }
        } else {
            refreshNearbyStopsInBackground()
        }
    }
    
    private func loadNearbyStops(showLoading: Bool) {
        if showLoading { isLoading = true }
        backgroundRefreshTask?.cancel()
        
        backgroundRefreshTask = Task {
            guard let loc = locationManager.location?.coordinate else {
                if showLoading {
                    await MainActor.run { isLoading = false }
                }
                print("Location not available for loading stops")
                return
            }
            
            let fetchLocation = locationManager.location
            
            defer {
                if !Task.isCancelled {
                    backgroundRefreshTask = nil
                }
            }
            
            do {
                let results = try await reverseGeocode(
                    place: (loc.latitude, loc.longitude),
                    type: .stop
                )
                if Task.isCancelled { return }
                
                let filteredResults = results.filter { result in
                    return result.lat != 0.0 && result.lon != 0.0
                }
                
                await MainActor.run {
                    searchResults = filteredResults
                    lastFetchedLocation = fetchLocation
                    isLoading = false
                }
            } catch {
                if !(error is CancellationError) {
                    print("Failed to load nearby stops: \(error)")
                    await MainActor.run { isLoading = false }
                }
            }
        }
    }
    
    private func refreshNearbyStopsInBackground() {
        guard backgroundRefreshTask == nil || backgroundRefreshTask?.isCancelled == true else {
            return
        }
        loadNearbyStops(showLoading: false)
    }
}
