//
//  TripsSearchViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 29.04.2025.
//
///  A lot of this code is from `StopsViewModel`

import LuxCom
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
            return String(localized: "Position Actuelle")
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

enum DepartureType: String, CaseIterable, Identifiable {
    case leaveAt = "Partir à"
    case arriveBy = "Arriver à"
    
    var id: String { self.rawValue }
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
    
    @Published var trips: [Itinerary] = []
    @Published var directs: [Itinerary] = []
    @Published var isLoadingTrips = false
    @Published var errorMessage: String? = nil
    @Published var showTripResults = false
    @Published var showSettings = false
    
    @Published var previousPageCursor: String? = nil
    @Published var nextPageCursor: String? = nil
    @Published var isLoadingEarlier = false
    @Published var isLoadingLater = false
    @Published var isChangingContent = false
    @Published var animateIn = false
    private var allTrips: [Itinerary] = []
    private var currentPageIndex = 0
    private let itemsPerPage = 6
    private var hasMoreEarlier = true
    private var hasMoreLater = true
    
    @Published var routeOptions = RouteOptions(
        from: RouteOptions.RouteLocation(coordinates: (0, 0)),
        to: RouteOptions.RouteLocation(coordinates: (0, 0)),
        via: nil,
        viaMinimumStay: [],
        time: nil,
        arriveBy: false,
        maxTransfers: 5,
        minTransferTime: 0,
        pedestrianProfile: .foot,
        transitModes: nil,
        numItineraries: 5,
        pageCursor: nil,
        timetableView: true,
        maxPreTransitTime: nil,
        maxPostTransitTime: nil
    )
    
    @Published var departureType: DepartureType = .leaveAt
    @Published var selectedDate: Date? = nil
    
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
            
            if selectedTo != nil {
                searchTrips()
            }
        } else if activeSearchField == .to {
            selectedTo = .searchResult(location)
            toQuery = ""
            activeSearchField = .none
            
            searchTrips()
        }
        searchResults = []
    }
    
    func selectCurrentPosition() {
        if activeSearchField == .from {
            selectedFrom = .currentPosition
            fromQuery = ""
            activeSearchField = .to
            
            if selectedTo != nil {
                searchTrips()
            }
        } else if activeSearchField == .to {
            selectedTo = .currentPosition
            toQuery = ""
            activeSearchField = .none
            
            searchTrips()
        }
        searchResults = []
    }
    
    func removeFromLocation() {
        selectedFrom = nil
        activeSearchField = .from
        showTripResults = false
        trips = []
        directs = []
    }
    
    func removeToLocation() {
        selectedTo = nil
        activeSearchField = .to
        showTripResults = false
        trips = []
        directs = []
    }
    
    func swapLocations() {
        let tempFrom = selectedFrom
        selectedFrom = selectedTo
        selectedTo = tempFrom
        
        if selectedFrom != nil && selectedTo != nil {
            searchTrips()
        } else {
            showTripResults = false
            trips = []
            directs = []
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
                    let results = try await geocode(text: query, place: (coords.latitude, coords.longitude), placeBias: 2)
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.searchResults = self.filterResults(results)
                            self.isLoading = false
                            self.backgroundRefreshTask = nil
                        }
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    print("search error : \(error)")
                    await MainActor.run {
                        self.isLoading = false
                        self.backgroundRefreshTask = nil
                    }
                }
            }
        }
    }
    
    private func filterResults(_ results: [SearchResult]) -> [SearchResult] {
        var seenIDs = Set<String>()
        
        var stopResults: [SearchResult] = []
        var nonStopResults: [SearchResult] = []
        
        for result in results {
            if !seenIDs.contains(result.id) {
                seenIDs.insert(result.id)
                
                if result.type == .stop {
                    stopResults.append(result)
                } else {
                    nonStopResults.append(result)
                }
            }
        }
        
        return stopResults + nonStopResults
    }
    
    func cancelBackgroundTasks() {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = nil
    }
    
    func setupLocationManager(_ manager: LocationManager) {
        self.locationManager = manager
        
        if manager.location != nil && selectedFrom == nil {
            selectedFrom = .currentPosition
        }
    }
        
    func searchTrips(pageCursor: String? = nil) {
        guard let fromLocation = getRouteLocation(for: selectedFrom),
              let toLocation = getRouteLocation(for: selectedTo) else {
            errorMessage = "Impossible d'obtenir les coordonnées"
            return
        }
        
        if pageCursor == nil {
            isLoadingTrips = true
            allTrips = []
            currentPageIndex = 0
            hasMoreEarlier = true
            hasMoreLater = true
        }
        
        showTripResults = true
        
        let timeForRequest = selectedDate ?? Date()
        
        let options = RouteOptions(
            from: fromLocation,
            to: toLocation,
            via: routeOptions.via,
            viaMinimumStay: routeOptions.viaMinimumStay,
            time: timeForRequest,
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
                    if isLoadingEarlier {
                        allTrips.insert(contentsOf: result.itineraries, at: 0)
                        currentPageIndex += result.itineraries.count / itemsPerPage
                    } else if isLoadingLater {
                        allTrips.append(contentsOf: result.itineraries)
                    } else {
                        allTrips = result.itineraries
                        
                        if departureType == .arriveBy && !allTrips.isEmpty {
                            currentPageIndex = (allTrips.count - 1) / itemsPerPage
                        } else {
                            currentPageIndex = 0
                        }
                    }
                    
                    self.directs = result.direct
                    self.previousPageCursor = result.previousPageCursor
                    self.nextPageCursor = result.nextPageCursor
                    
                    self.hasMoreEarlier = !(result.previousPageCursor.isEmpty)
                    self.hasMoreLater = !(result.nextPageCursor.isEmpty)
                    
                    self.updateDisplayedTrips()
                    
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
    
    private func updateDisplayedTrips() {
        let startIndex = currentPageIndex * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, allTrips.count)
        
        if startIndex < allTrips.count {
            self.trips = Array(allTrips[startIndex..<endIndex])
        } else {
            self.trips = []
        }
    }
    
    func loadEarlier() {
        isChangingContent = true
        
        if currentPageIndex > 0 {
            isLoadingEarlier = true
            currentPageIndex -= 1
            updateDisplayedTrips()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isLoadingEarlier = false
                self.isChangingContent = false
                self.animateIn = true
            }
        }
        else if hasMoreEarlier && !(previousPageCursor?.isEmpty ?? true) {
            isLoadingEarlier = true
            searchTrips(pageCursor: previousPageCursor)
        } else {
            isChangingContent = false
        }
    }
    
    func loadLater() {
        isChangingContent = true
        
        let maxPageIndex = max(0, (allTrips.count - 1) / itemsPerPage)
        
        if currentPageIndex < maxPageIndex {
            isLoadingLater = true
            currentPageIndex += 1
            updateDisplayedTrips()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isLoadingLater = false
                self.isChangingContent = false
                self.animateIn = true
            }
        }
        else if hasMoreLater && !(nextPageCursor?.isEmpty ?? true) {
            isLoadingLater = true
            searchTrips(pageCursor: nextPageCursor)
        } else {
            isChangingContent = false
        }
    }
    
    private func getRouteLocation(for location: SelectedLocation?) -> RouteOptions.RouteLocation? {
        guard let location = location else { return nil }
        
        switch location {
        case .searchResult(let result):
            if result.type == .stop {
                return RouteOptions.RouteLocation(stopId: result.id)
            } else {
                return RouteOptions.RouteLocation(coordinates: (result.lat, result.lon))
            }
        case .currentPosition:
            if let coords = locationManager?.location?.coordinate {
                return RouteOptions.RouteLocation(coordinates: (coords.latitude, coords.longitude))
            }
            return nil
        }
    }
    
    func updateRouteOptions(_ options: RouteOptions) {
        self.routeOptions = options
        if selectedFrom != nil && selectedTo != nil {
            searchTrips()
        }
    }
    
    func changeDepartureType(_ type: DepartureType) {
        self.departureType = type
        if selectedFrom != nil && selectedTo != nil {
            searchTrips()
        }
    }
    @MainActor
    func handleInitialSearchResult(_ result: SearchResult, targetField: SearchField) {
        if (targetField == .from && selectedFrom != nil) || (targetField == .to && selectedTo != nil) {
            return
        }
        
        if targetField == .from {
            selectedFrom = .searchResult(result)
            fromQuery = ""
            if selectedTo != nil {
                activeSearchField = .none
                searchTrips()
            } else {
                activeSearchField = .to
            }
        } else {
            selectedTo = .searchResult(result)
            toQuery = ""
            if selectedFrom != nil {
                activeSearchField = .none
                searchTrips()
            } else {
                activeSearchField = .from
            }
        }
        searchResults = []
        showMinCharactersMessage = false
        isLoading = false
    }
}
