//
//  UserShortcut.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import Foundation
import LuxCom

struct UserShortcut: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var symbol: String
    var coordinates: Coordinates
    var createdAt: Date
    
    struct Coordinates: Codable, Equatable {
        var latitude: Double
        var longitude: Double
        var locationName: String
    }
    
    init(id: UUID = UUID(), name: String, symbol: String, coordinates: Coordinates) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.coordinates = coordinates
        self.createdAt = Date()
    }
    
    func toSearchResult() -> SearchResult {
        return SearchResult(
            type: .place,
            tokens: [[0, name.count]],
            name: coordinates.locationName,
            id: id.uuidString,
            lat: coordinates.latitude,
            lon: coordinates.longitude,
            areas: [],
            score: 1.0
        )
    }
}
