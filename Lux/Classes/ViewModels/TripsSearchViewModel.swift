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
import CoreLocation

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
    @AppStorage("tripSearchHistory") private var storedSearchHistory: Data = Data()
    @Published var searchHistory: [SearchResult] = []
    private let maxHistoryItems: Int = 20
    
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
    @ObservedObject var settings = Settings.shared
    @ObservedObject var progress = Progress.shared
    private var allTrips: [Itinerary] = []
    private var currentPageIndex = 0
    private let itemsPerPage = 6
    private var hasMoreEarlier: Bool {
        !(previousPageCursor?.isEmpty ?? true)
    }
    private var hasMoreLater: Bool {
        !(nextPageCursor?.isEmpty ?? true)
    }
    
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
        pedestrianSpeed: nil,
        transitModes: nil,
        numItineraries: 5,
        pageCursor: nil,
        timetableView: true,
        maxPreTransitTime: nil,
        maxPostTransitTime: nil
    )
    
    @Published var departureType: DepartureType = .leaveAt
    @Published var selectedDate: Date? = nil
    
    @Published var hasCustomSettings = false
    
    enum SearchField {
        case from, to, none
    }
    
    private var backgroundRefreshTask: Task<Void, Never>? = nil
    private var locationManager: LocationManager?
    private let hybridSearchService = HybridLocationSearchService()
    
    private let defaultMaxTransfers = 5
    private let defaultMinTransferTime = 0
    private let defaultPedestrianProfile = PedestrianProfile.foot
    private let defaultMaxWalkingTime = 900
    private let defaultPedestrianSpeed: Double = 1.2
    
    @AppStorage("routeOptionsMaxTransfers") private var storedMaxTransfers: Int = 5
    @AppStorage("routeOptionsMinTransferTime") private var storedMinTransferTime: Int = 0
    @AppStorage("routeOptionsPedestrianProfile") private var storedPedestrianProfile: String = PedestrianProfile.foot.rawValue
    @AppStorage("routeOptionsTransportModes") private var storedTransportModes: Data = Data()
    @AppStorage("routeOptionsMaxWalkingTime") private var storedMaxWalkingTime: Int = 900
    @AppStorage("routeOptionsPedestrianSpeed") private var storedPedestrianSpeed: Double = 1.2
    
    init() {
        fetchRouteOptionsPreferences()
        loadSearchHistory()
    }
    
    private func loadSearchHistory() {
        if storedSearchHistory.isEmpty {
            searchHistory = []
            return
        }
        if let decoded = try? JSONDecoder().decode([SearchResult].self, from: storedSearchHistory) {
            searchHistory = decoded
        } else {
            searchHistory = []
        }
    }
    
    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            storedSearchHistory = data
        }
    }
    
    func addToHistory(_ result: SearchResult) {
        // do not store duplicates, move to front
        if let idx = searchHistory.firstIndex(where: { $0.id == result.id }) {
            searchHistory.remove(at: idx)
        }
        searchHistory.insert(result, at: 0)
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        saveSearchHistory()
    }
    
    func removeFromHistory(id: String) {
        searchHistory.removeAll { $0.id == id }
        saveSearchHistory()
    }
    
    func clearHistory() {
        searchHistory = []
        storedSearchHistory = Data()
    }
    
    var isSearchActive: Bool {
        return activeSearchField != .none &&
        (fromQuery.count >= 3 || toQuery.count >= 3 ||
         !searchResults.isEmpty || showMinCharactersMessage)
    }
    
    func fetchRouteOptionsPreferences() {
        let maxTransfers = storedMaxTransfers
        let minTransferTime = storedMinTransferTime
        let maxWalkingTime = storedMaxWalkingTime
        let pedestrianSpeed = storedPedestrianSpeed
        
        var pedestrianProfile = PedestrianProfile.foot
        if let profile = PedestrianProfile(rawValue: storedPedestrianProfile) {
            pedestrianProfile = profile
        }
        
        var transportModes: [TransportationMode]? = nil
        if let decodedModes = try? JSONDecoder().decode(Set<TransportationMode>.self, from: storedTransportModes),
           !decodedModes.isEmpty {
            transportModes = Array(decodedModes)
        }
        
        routeOptions = RouteOptions(
            from: routeOptions.from,
            to: routeOptions.to,
            via: routeOptions.via,
            viaMinimumStay: routeOptions.viaMinimumStay,
            time: routeOptions.time,
            arriveBy: routeOptions.arriveBy,
            maxTransfers: maxTransfers,
            minTransferTime: minTransferTime,
            pedestrianProfile: pedestrianProfile,
            pedestrianSpeed: pedestrianSpeed == defaultPedestrianSpeed ? nil : pedestrianSpeed,
            transitModes: transportModes,
            numItineraries: routeOptions.numItineraries,
            pageCursor: routeOptions.pageCursor,
            timetableView: routeOptions.timetableView,
            maxPreTransitTime: maxWalkingTime == defaultMaxWalkingTime ? nil : maxWalkingTime,
            maxPostTransitTime: maxWalkingTime == defaultMaxWalkingTime ? nil : maxWalkingTime
        )
        
        checkIfSettingsDifferFromDefaults()
    }
    
    private func checkIfSettingsDifferFromDefaults() {
        let transportModesSet = Set(routeOptions.transitModes ?? [])
        let maxWalkingTime = routeOptions.maxPreTransitTime ?? defaultMaxWalkingTime
        let pedestrianSpeed = routeOptions.pedestrianSpeed ?? defaultPedestrianSpeed
        
        hasCustomSettings = routeOptions.maxTransfers != defaultMaxTransfers ||
                           routeOptions.minTransferTime != defaultMinTransferTime ||
                           routeOptions.pedestrianProfile != defaultPedestrianProfile ||
                           !transportModesSet.isEmpty ||
                           maxWalkingTime != defaultMaxWalkingTime ||
                           pedestrianSpeed != defaultPedestrianSpeed
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
        addToHistory(location)
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
            let userCoordinate = self.locationManager?.location?.coordinate
            let results = await self.hybridSearchService.search(
                query: query,
                userLocation: userCoordinate
            )
            
            if !Task.isCancelled {
                await MainActor.run {
                    self.searchResults = self.filterResults(results)
                    self.isLoading = false
                    self.backgroundRefreshTask = nil
                }
            }
        }
    }
    
    private func filterResults(_ results: [SearchResult]) -> [SearchResult] {
        var seenIDs = Set<String>()
        var dedupedResults: [SearchResult] = []

        for result in results {
            if !seenIDs.contains(result.id) {
                seenIDs.insert(result.id)
                dedupedResults.append(result)
            }
        }

        return dedupedResults
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
            pedestrianSpeed: routeOptions.pedestrianSpeed,
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
                    let loadingEarlier = self.isLoadingEarlier
                    let loadingLater = self.isLoadingLater
                    
                    if loadingEarlier {
                        self.allTrips.insert(contentsOf: result.itineraries, at: 0)
                        // After fetching previous results, immediately show that earlier page.
                        self.currentPageIndex = 0
                    } else if loadingLater {
                        let oldMaxPageIndex = max(0, (self.allTrips.count - 1) / self.itemsPerPage)
                        self.allTrips.append(contentsOf: result.itineraries)
                        // Move to the first page that includes newly loaded later results.
                        let newMaxPageIndex = max(0, (self.allTrips.count - 1) / self.itemsPerPage)
                        self.currentPageIndex = min(oldMaxPageIndex + 1, newMaxPageIndex)
                    } else {
                        self.allTrips = result.itineraries
                        
                        if self.departureType == .arriveBy && !self.allTrips.isEmpty {
                            self.currentPageIndex = (self.allTrips.count - 1) / self.itemsPerPage
                        } else {
                            self.currentPageIndex = 0
                        }
                    }
                    
                    self.directs = result.direct
                    
                    if loadingEarlier {
                        self.previousPageCursor = result.previousPageCursor
                    } else if loadingLater {
                        self.nextPageCursor = result.nextPageCursor
                    } else {
                        self.previousPageCursor = result.previousPageCursor
                        self.nextPageCursor = result.nextPageCursor
                    }
                    
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
        else if hasMoreEarlier, let previousPageCursor {
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
        else if hasMoreLater, let nextPageCursor {
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
            guard let coords = locationManager?.location?.coordinate else { return nil }
            
            if settings.dataSource == .luxCom {
                let nearbyStop = progress.searchResults.first { stop in
                    guard stop.lat != 0.0 && stop.lon != 0.0 else { return false }
                    let stopLocation = CLLocation(latitude: stop.lat, longitude: stop.lon)
                    let userLocation = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
                    return userLocation.distance(from: stopLocation) <= 15.0
                }
                
                if let stop = nearbyStop {
                    return RouteOptions.RouteLocation(stopId: stop.id)
                }
            }
            
            return RouteOptions.RouteLocation(coordinates: (coords.latitude, coords.longitude))
        }
    }
    
    func updateRouteOptions(_ options: RouteOptions) {
        self.routeOptions = options
        
        savePreferencesToStorage(options)
        
        checkIfSettingsDifferFromDefaults()
        if selectedFrom != nil && selectedTo != nil {
            searchTrips()
        }
    }
    
    private func savePreferencesToStorage(_ options: RouteOptions) {
        storedMaxTransfers = options.maxTransfers
        storedMinTransferTime = options.minTransferTime
        storedPedestrianProfile = options.pedestrianProfile.rawValue
        
        let walkingTime = options.maxPreTransitTime ?? defaultMaxWalkingTime
        storedMaxWalkingTime = walkingTime
        
        let pedestrianSpeed = options.pedestrianSpeed ?? defaultPedestrianSpeed
        storedPedestrianSpeed = pedestrianSpeed
        
        if let transportModes = options.transitModes, !transportModes.isEmpty {
            let transportModesSet = Set(transportModes)
            if let encodedModes = try? JSONEncoder().encode(transportModesSet) {
                storedTransportModes = encodedModes
            }
        } else {
            storedTransportModes = Data()
        }
    }
    
    func changeDepartureType(_ type: DepartureType) {
        self.departureType = type
//        if selectedFrom != nil && selectedTo != nil {
//            searchTrips()
//        }
    }
    @MainActor
    func handleInitialSearchResult(_ result: SearchResult, targetField: SearchField) {
        addToHistory(result)
        let location = SelectedLocation.searchResult(result)
        
        if selectedFrom == nil && selectedTo != nil {
            selectedFrom = location
        } else if selectedTo == nil && selectedFrom != nil {
            selectedTo = location
        } else {
            if targetField == .to {
                selectedTo = location
            } else {
                selectedFrom = location
            }
        }
        
        fromQuery = ""
        toQuery = ""
        searchResults = []
        showMinCharactersMessage = false
        isLoading = false
        
        if selectedFrom != nil && selectedTo != nil {
            activeSearchField = .none
            searchTrips()
        } else {
            activeSearchField = selectedFrom == nil ? .from : .to
        }
    }
}
