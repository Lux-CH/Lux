//
//  StopsViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import LuxCom
import CoreLocation

// MARK: - ViewModel
class StopsViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var isSearchMode = false
    @Published var showMinCharactersMessage = false
    
    // Location management
    private var locationManager: LocationManager?
    private var lastFetchedLocation: CLLocation? = nil
    private let significantDistance: CLLocationDistance = 100.0
    
    // Refresh management
    var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private var backgroundRefreshTask: Task<Void, Never>? = nil
    
    init() {
        setupSearchQueryObserver()
    }
    
    private func setupSearchQueryObserver() {
        // We'd use Combine here in a real implementation but for simplicity:
        // This would monitor searchQuery changes
    }
    
    func setupLocationManager(_ manager: LocationManager) {
        self.locationManager = manager
    }
    
    func resetSearch() {
        searchQuery = ""
        isSearchMode = false
        showMinCharactersMessage = false
        loadNearbyStops(showLoading: false)
    }
    
    func onChange(of newSearchQuery: String) {
        if newSearchQuery.isEmpty {
            resetSearch()
        }
        else if newSearchQuery.count < 3 {
            isSearchMode = true
            showMinCharactersMessage = true
            searchResults = []
        }
        else {
            showMinCharactersMessage = false
            performSearch()
        }
    }
    
    func performSearch() {
        guard searchQuery.count >= 3 else { return }
        
        isSearchMode = true
        
        // Only show loading indicator if there are no current results
        if searchResults.isEmpty {
            isLoading = true
        }
        
        cancelBackgroundTasks()
        
        backgroundRefreshTask = Task {
            do {
                if let coords = locationManager?.location?.coordinate {
                    let results = try await geocode(text: searchQuery, type: .stop, place: (coords.latitude, coords.longitude))
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.searchResults = results
                            self.isLoading = false
                            self.backgroundRefreshTask = nil
                        }
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    print("Search error: \(error)")
                    await MainActor.run {
                        self.isLoading = false
                        self.backgroundRefreshTask = nil
                    }
                }
            }
        }
    }
    
    func checkLocationAndRefresh() {
        guard let currentLoc = locationManager?.location else { return }
        
        if let lastLoc = lastFetchedLocation {
            let distance = currentLoc.distance(from: lastLoc)
            if distance >= significantDistance {
                refreshNearbyStopsInBackground()
            }
        } else {
            refreshNearbyStopsInBackground()
        }
    }
    
    func loadNearbyStops(showLoading: Bool) {
        if showLoading { isLoading = true }
        cancelBackgroundTasks()
        
        backgroundRefreshTask = Task {
            guard let loc = locationManager?.location?.coordinate else {
                if showLoading {
                    await MainActor.run { self.isLoading = false }
                }
                print("Location not available for loading stops")
                return
            }
            
            let fetchLocation = locationManager?.location
            
            defer {
                if !Task.isCancelled {
                    self.backgroundRefreshTask = nil
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
                    self.searchResults = filteredResults
                    self.lastFetchedLocation = fetchLocation
                    self.isLoading = false
                }
            } catch {
                if !(error is CancellationError) {
                    print("Failed to load nearby stops: \(error)")
                    await MainActor.run { self.isLoading = false }
                }
            }
        }
    }
    
    func refreshNearbyStopsInBackground() {
        guard backgroundRefreshTask == nil || backgroundRefreshTask?.isCancelled == true else {
            return
        }
        loadNearbyStops(showLoading: false)
    }
    
    func cancelBackgroundTasks() {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = nil
    }
}
