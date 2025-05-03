//
//  LocationSearchViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import LuxCom
import Foundation

@MainActor
class LocationSearchViewModel: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var showMinCharactersMessage = false
    var userLocation: (Double, Double)? = nil
    
    private var searchTask: Task<Void, Never>? = nil
    
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
            do {
                var results: [SearchResult]
                
                if let location = userLocation {
                    results = try await geocode(
                        text: query,
                        place: location,
                        placeBias: 3
                    )
                } else {
                    results = try await geocode(text: query)
                }
                
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchResults = self.filterUniqueResults(results)
                        self.isLoading = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("searcghh error \(error.localizedDescription)")
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    func useCurrentLocation(locationManager: LocationManager, completion: @escaping (SearchResult?) -> Void) {
        guard let location = locationManager.location else {
            completion(nil)
            return
        }
        
        Task {
            do {
                let results = try await geocode(
                    text: "",
                    place: (location.coordinate.latitude, location.coordinate.longitude),
                    placeBias: 5
                )
                
                if let firstResult = results.first {
                    await MainActor.run {
                        completion(firstResult)
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
    
    private func filterUniqueResults(_ results: [SearchResult]) -> [SearchResult] {
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
}
