//
//  ShortcutEditorViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import Foundation
import CoreLocation
import Combine
import LuxCom

class ShortcutEditorViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    func useCurrentLocation(locationManager: LocationManager, completion: @escaping (SearchResult?) -> Void) {
        guard let location = locationManager.location else {
            errorMessage = "Impossible d'accéder à votre position"
            completion(nil)
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let results = try await geocode(
                    text: "",
                    place: (location.coordinate.latitude, location.coordinate.longitude),
                    placeBias: 5
                )
                
                await MainActor.run {
                    isLoading = false
                    
                    if let firstResult = results.first {
                        completion(firstResult)
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
                        
                        completion(fallbackResult)
                    }
                }
            } catch {
                print("err geocoding : \(error.localizedDescription)")
                
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Erreur lors de la géolocalisation : \(error.localizedDescription)"
                    
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
                    
                    completion(fallbackResult)
                }
            }
        }
    }
    
    func convertToSearchResult(shortcut: UserShortcut, completion: @escaping (SearchResult?) -> Void) {
        let result = SearchResult(
            type: .place,
            tokens: [[0, shortcut.name.count]],
            name: shortcut.coordinates.locationName,
            id: shortcut.id.uuidString,
            lat: shortcut.coordinates.latitude,
            lon: shortcut.coordinates.longitude,
            areas: [],
            score: 1.0
        )
        
        completion(result)
    }
    
    func formatCoordinates(latitude: Double, longitude: Double) -> String {
        return String(format: "%.6f, %.6f", latitude, longitude)
    }
    
    func getLocationDescription(for searchResult: SearchResult) -> String {
        if !searchResult.areas.isEmpty {
            if let matchedArea = searchResult.areas.first(where: { $0.matched }) {
                return matchedArea.name
            } else if let defaultArea = searchResult.areas.first(where: { $0.default == true }) {
                return defaultArea.name
            } else {
                return searchResult.areas.sorted(by: { $0.adminLevel < $1.adminLevel }).first?.name ?? ""
            }
        }
        
        var addressComponents: [String] = []
        
        if let street = searchResult.street {
            var streetPart = street
            if let number = searchResult.houseNumber {
                streetPart += " " + number
            }
            addressComponents.append(streetPart)
        }
        
        if let zip = searchResult.zip {
            addressComponents.append(zip)
        }
        
        if !addressComponents.isEmpty {
            return addressComponents.joined(separator: ", ")
        }
        
        return formatCoordinates(latitude: searchResult.lat, longitude: searchResult.lon)
    }
    
    /// Clears any error messages
    func clearErrorMessage() {
        errorMessage = nil
    }
}
