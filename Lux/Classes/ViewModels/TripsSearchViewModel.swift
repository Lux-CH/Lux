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
    
    static func == (lhs: SelectedLocation, rhs: SelectedLocation) -> Bool {
        return lhs.id == rhs.id
    }
}

class TripsSearchViewModel: ObservableObject {
    @Published var fromQuery = ""
    @Published var toQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var showMinCharactersMessage = false
    @Published var isLoading = false
    @Published var selectedFrom: SelectedLocation?
    @Published var selectedTo: SelectedLocation?
    @Published var activeSearchField: SearchField = .from
    
    enum SearchField {
        case from, to, none
    }
    
    private var backgroundRefreshTask: Task<Void, Never>? = nil
    private var locationManager: LocationManager?
    
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
        }
        searchResults = []
    }
    
    func removeFromLocation() {
        selectedFrom = nil
        activeSearchField = .from
    }
    
    func removeToLocation() {
        selectedTo = nil
        activeSearchField = .to
    }
    
    func swapLocations() {
        let tempFrom = selectedFrom
        selectedFrom = selectedTo
        selectedTo = tempFrom
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
}
