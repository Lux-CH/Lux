//
//  ShortcutEditorViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import Foundation
import CoreLocation
import LuxCom

class ShortcutEditorViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
        
    func useCurrentLocation(locationManager: LocationManager, completion: @escaping (SearchResult?) -> Void) {
        guard let location = locationManager.location else {
            errorMessage = "Impossible d'accéder à votre position"
            completion(nil)
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let results = try await LuxData.reverseGeocode(place: (location.coordinate.latitude, location.coordinate.longitude))
                
                await MainActor.run {
                    isLoading = false
                    
                    if let firstResult = results.first {
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
        let result = shortcut.toSearchResult()
        completion(result)
    }
}
