//
//  LocationSearchViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import LuxCom
import Foundation
import CoreLocation

@MainActor
class LocationSearchViewModel: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var showMinCharactersMessage = false
    var userLocation: (Double, Double)? = nil
    
    private var searchTask: Task<Void, Never>? = nil
    private let hybridSearchService = HybridLocationSearchService()
    
    func performSearch(_ query: String) {
        searchTask?.cancel()
        
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
        
        showMinCharactersMessage = false
        isLoading = true
        
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            if Task.isCancelled { return }

            let currentUserLocation = userLocation.map {
                CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1)
            }

            let results = await hybridSearchService.search(
                query: query,
                userLocation: currentUserLocation
            )

            if !Task.isCancelled {
                await MainActor.run {
                    self.searchResults = self.filterResults(results)
                    self.isLoading = false
                }
            }
        }
    }

    func resolve(_ result: SearchResult) async -> SearchResult {
        await hybridSearchService.resolve(result)
    }
    
    func useCurrentLocation(locationManager: LocationManager, completion: @escaping (SearchResult?) -> Void) {
        guard let location = locationManager.location else {
            completion(nil)
            return
        }
        
        Task {
            do {
                let results = try await LuxData.reverseGeocode(place: (location.coordinate.latitude, location.coordinate.longitude))
                
                if let firstResult = results.first {
                    await MainActor.run {
                        completion(SearchResult(
                            type: .place,
                            tokens: [],
                            name: firstResult.name,
                            id: firstResult.id,
                            lat: location.coordinate.latitude,
                            lon: location.coordinate.longitude,
                            areas: firstResult.areas,
                            score: 1.0,
                        ))
                    }
                } else {
                    let fallbackResult = SearchResult(
                        type: .place,
                        tokens: [],
                        name: "Ma position actuelle",
                        id: UUID().uuidString,
                        lat: location.coordinate.latitude,
                        lon: location.coordinate.longitude,
                        areas: [],
                        score: 1.0
                    )
                    
                    await MainActor.run {
                        completion(fallbackResult)
                    }
                }
            } catch {
                print("err geocoding : \(error.localizedDescription)")
                await MainActor.run {
                    completion(nil)
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
}
