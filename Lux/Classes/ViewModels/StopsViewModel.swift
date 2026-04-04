//
//  StopsViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import LuxCom
import LuxComHAFAS
import CoreLocation

class StopsViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var isSearchMode = false
    @Published var showMinCharactersMessage = false
    @ObservedObject var settings = Settings.shared
    
    private var locationManager: LocationManager?
    private var lastFetchedLocation: CLLocation? = nil
    private let significantDistance: CLLocationDistance = 100.0
    
    var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private var backgroundRefreshTask: Task<Void, Never>? = nil
    
    
    func setupLocationManager(_ manager: LocationManager) {
        self.locationManager = manager
    }
    
    func resetSearch() {
        searchQuery = ""
        isSearchMode = false
        showMinCharactersMessage = false
        loadNearbyStops(showLoading: false)
    }
    
    func performSearch() {
        isSearchMode = !searchQuery.isEmpty
        
        if searchQuery.isEmpty {
            searchResults = []
            showMinCharactersMessage = false
            return
        }
        
        if searchQuery.count < 3 {
            searchResults = []
            showMinCharactersMessage = true
            return
        }
        
        showMinCharactersMessage = false
        
        cancelBackgroundTasks()
        
        backgroundRefreshTask = Task {
            do {
                if let coords = locationManager?.location?.coordinate {
                    var results: [SearchResult] = []
                    if settings.dataSource == .luxCom {
                        results = try await geocode(text: searchQuery, type: .stop, place: (coords.latitude, coords.longitude), placeBias: 2)
                    }
                    else {
                        results = try await citaGeocode(text: searchQuery, type: .stop, place: (coords.latitude, coords.longitude), placeBias: 2)
                    }
                    
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
                var results: [SearchResult] = []
                if settings.dataSource == .luxCom {
                    results = try await getMapSearchResults(
                        currentLoc: (loc.latitude, loc.longitude))
                }
                else {
                    results = try await citaReverseGeocode(currentLoc: (loc.latitude, loc.longitude))
                }
                
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
