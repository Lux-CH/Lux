//
//  TripsSearchViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 29.04.2025.
//
///  A lot of this code is from `StopsViewModel`

import LuxCom
import Combine
import Foundation
import SwiftUI

enum SelectedLocation: Equatable {
    case searchResult(SearchResult)
    case currentPosition
    
    var displayName: String {
        switch self {
        case .searchResult(let result):
            return result.name
        case .currentPosition:
            return "Position Actuelle"
        }
    }
    
    var id: String {
        switch self {
        case .searchResult(let result):
            return result.id
        case .currentPosition:
            return "current_position"
        }
    }
    
    var coordinates: (Double, Double)? {
        switch self {
        case .searchResult(let result):
            return (result.lat, result.lon)
        case .currentPosition:
            return nil // This will be resolved with location manager
        }
    }
    
    static func == (lhs: SelectedLocation, rhs: SelectedLocation) -> Bool {
        return lhs.id == rhs.id
    }
}

enum DepartureType: String, CaseIterable, Identifiable {
    case leaveNow = "Partir maintenant"
    case leaveAt = "Partir à"
    case arriveBy = "Arriver à"
    
    var id: String { self.rawValue }
    
    var systemImage: String {
        switch self {
        case .leaveNow: return "arrow.right.circle.fill"
        case .leaveAt: return "clock.fill"
        case .arriveBy: return "flag.fill"
        }
    }
}

class TripsSearchViewModel: ObservableObject {
    // Search fields
    @Published var fromQuery = ""
    @Published var toQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var showMinCharactersMessage = false
    @Published var isLoading = false
    @Published var selectedFrom: SelectedLocation?
    @Published var selectedTo: SelectedLocation?
    @Published var activeSearchField: SearchField = .from
    
    // Trip search related
    @Published var trips: [Itinerary] = []
    @Published var isLoadingTrips = false
    @Published var errorMessage: String? = nil
    @Published var showTripResults = false
    @Published var showSettings = false
    
    // Pagination
    @Published var previousPageCursor: String? = nil
    @Published var nextPageCursor: String? = nil
    @Published var isLoadingEarlier = false
    @Published var isLoadingLater = false
    @Published var isChangingContent = false
    @Published var animateIn = false
    
    // Route options
    @Published var routeOptions = RouteOptions(
        from: (0, 0),
        to: (0, 0),
        via: nil,
        viaMinimumStay: [],
        time: nil,
        arriveBy: false,
        maxTransfers: 2,
        minTransferTime: 120,
        pedestrianProfile: .foot,
        transitModes: nil,
        numItineraries: 5,
        pageCursor: nil,
        timetableView: true,
        maxPreTransitTime: nil,
        maxPostTransitTime: nil
    )
    
    // Departure settings
    @Published var departureType: DepartureType = .leaveNow
    @Published var selectedDate = Date()
    
    enum SearchField {
        case from, to, none
    }
    
    private var backgroundRefreshTask: Task<Void, Never>? = nil
    private var locationManager: LocationManager?
    
    var isSearchActive: Bool {
        return activeSearchField != .none &&
        (fromQuery.count >= 3 || toQuery.count >= 3 ||
         !searchResults.isEmpty || showMinCharactersMessage)
    }
    func resetSearch() {
        isLoading = false
        if activeSearchField == .from {
            fromQuery = ""
        } else if activeSearchField == .to {
            toQuery = ""
        }
        showMinCharactersMessage = false
        searchResults = []
    }
    
    func setActiveSearchField(_ field: SearchField) {
        activeSearchField = field
        if field == .from {
            performSearch(fromQuery)
        } else if field == .to {
            performSearch(toQuery)
        } else {
            searchResults = []
        }
    }
    
    func selectLocation(_ location: SearchResult) {
        if activeSearchField == .from {
            selectedFrom = .searchResult(location)
            fromQuery = ""
            activeSearchField = .to
        } else if activeSearchField == .to {
            selectedTo = .searchResult(location)
            toQuery = ""
            activeSearchField = .none
            
            // Auto search for trips when both locations are set
            searchTrips()
        }
        searchResults = []
    }
    
    func selectCurrentPosition() {
        if activeSearchField == .from {
            selectedFrom = .currentPosition
            fromQuery = ""
            activeSearchField = .to
        } else if activeSearchField == .to {
            selectedTo = .currentPosition
            toQuery = ""
            activeSearchField = .none
            
            // Auto search for trips when both locations are set
            searchTrips()
        }
        searchResults = []
    }
    
    func removeFromLocation() {
        selectedFrom = nil
        activeSearchField = .from
        showTripResults = false
        trips = []
    }
    
    func removeToLocation() {
        selectedTo = nil
        activeSearchField = .to
        showTripResults = false
        trips = []
    }
    
    func swapLocations() {
        let tempFrom = selectedFrom
        selectedFrom = selectedTo
        selectedTo = tempFrom
        
        // If both are set, search again
        if selectedFrom != nil && selectedTo != nil {
            searchTrips()
        } else {
            showTripResults = false
            trips = []
        }
    }
    
    func isCurrentPositionAvailable() -> Bool {
        return locationManager?.location != nil
    }
    
    func onChange(of newSearchQuery: String) {
        if newSearchQuery.isEmpty {
            searchResults = []
            showMinCharactersMessage = false
        }
        else if newSearchQuery.count < 3 {
            showMinCharactersMessage = true
            searchResults = []
        }
        else {
            showMinCharactersMessage = false
            performSearch(newSearchQuery)
        }
    }
    
    func performSearch(_ query: String) {
        if query.isEmpty {
            searchResults = []
            showMinCharactersMessage = false
            return
        }
        
        if query.count < 3 {
            searchResults = []
            showMinCharactersMessage = true
            return
        }
        isLoading = true
        showMinCharactersMessage = false
        
        cancelBackgroundTasks()
        
        backgroundRefreshTask = Task {
            do {
                if let coords = locationManager?.location?.coordinate {
                    let results = try await geocode(text: query, place: (coords.latitude, coords.longitude), placeBias: 9)
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.searchResults = self.filterResultsForUniqueId(results)
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
    
    private func filterResultsForUniqueId(_ results: [SearchResult]) -> [SearchResult] {
        var uniqueResults = [SearchResult]()
        var seenIDs = Set<String>()
        
        for result in results {
            if !seenIDs.contains(result.id) {
                seenIDs.insert(result.id)
                uniqueResults.append(result)
            }
        }
        
        return uniqueResults
    }
    
    func cancelBackgroundTasks() {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = nil
    }
    
    func setupLocationManager(_ manager: LocationManager) {
        self.locationManager = manager
        
        // Set current position as default for "from" location
        if manager.location != nil && selectedFrom == nil {
            selectedFrom = .currentPosition
        }
    }
    
    // MARK: - Trip Search Functions
    
    func searchTrips(pageCursor: String? = nil) {
        guard let fromCoordinates = getCoordinates(for: selectedFrom),
              let toCoordinates = getCoordinates(for: selectedTo) else {
            errorMessage = "Impossible d'obtenir les coordonnées"
            return
        }
        
        if pageCursor == nil {
            isLoadingTrips = true
        }
        
        showTripResults = true
        
        // Configure route options
        let options = RouteOptions(
            from: fromCoordinates,
            to: toCoordinates,
            via: routeOptions.via,
            viaMinimumStay: routeOptions.viaMinimumStay,
            time: getSearchTime(),
            arriveBy: departureType == .arriveBy,
            maxTransfers: routeOptions.maxTransfers,
            minTransferTime: routeOptions.minTransferTime,
            pedestrianProfile: routeOptions.pedestrianProfile,
            transitModes: routeOptions.transitModes,
            numItineraries: 5,
            pageCursor: pageCursor,
            timetableView: true,
            maxPreTransitTime: routeOptions.maxPreTransitTime,
            maxPostTransitTime: routeOptions.maxPostTransitTime
        )
        
        Task {
            do {
                let result = try await getRoute(options)
                
                await MainActor.run {
                    self.trips = result.itineraries
                    self.previousPageCursor = result.previousPageCursor
                    self.nextPageCursor = result.nextPageCursor
                    self.isLoadingTrips = false
                    self.isLoadingEarlier = false
                    self.isLoadingLater = false
                    self.isChangingContent = false
                    self.animateIn = true
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Erreur: \(error.localizedDescription)"
                    self.isLoadingTrips = false
                    self.isLoadingEarlier = false
                    self.isLoadingLater = false
                    self.isChangingContent = false
                }
                print("Trip search error: \(error)")
            }
        }
    }
    
    func loadEarlier() {
        guard let cursor = previousPageCursor, !cursor.isEmpty else { return }
        
        isLoadingEarlier = true
        isChangingContent = true
        searchTrips(pageCursor: cursor)
    }
    
    func loadLater() {
        guard let cursor = nextPageCursor, !cursor.isEmpty else { return }
        
        isLoadingLater = true
        isChangingContent = true
        searchTrips(pageCursor: cursor)
    }
    
    private func getCoordinates(for location: SelectedLocation?) -> (Double, Double)? {
        guard let location = location else { return nil }
        
        switch location {
        case .searchResult(let result):
            return (result.lat, result.lon)
        case .currentPosition:
            if let coords = locationManager?.location?.coordinate {
                return (coords.latitude, coords.longitude)
            }
            return nil
        }
    }
    
    private func getSearchTime() -> Date? {
        switch departureType {
        case .leaveNow:
            return Date()
        case .leaveAt, .arriveBy:
            return selectedDate
        }
    }
    
    func updateRouteOptions(_ options: RouteOptions) {
        self.routeOptions = options
        // If we have both locations, search with new options
        if selectedFrom != nil && selectedTo != nil {
            searchTrips()
        }
    }
    
    func changeDepartureType(_ type: DepartureType) {
        self.departureType = type
        // If we have both locations, search with new departure type
        if selectedFrom != nil && selectedTo != nil {
            searchTrips()
        }
    }
}
