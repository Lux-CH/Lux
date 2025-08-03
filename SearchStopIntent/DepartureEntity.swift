//
//  DepartureEntity.swift
//  Lux
//
//  Created by Constantin Clerc on 03.08.2025.
//

import AppIntents
import Foundation
import LuxCom

struct DepartureEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Départs"
    static var defaultQuery = DepartureQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(routeShortName) → \(headsign)",
            subtitle: LocalizedStringResource(stringLiteral: formattedTime),
        )
    }
    
    let routeShortName: String
    let headsign: String
    let departureTime: Date
    let realTime: Bool
    let cancelled: Bool
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH'h'mm"
        return formatter.string(from: departureTime)
    }
    
    init(from stopTime: StopTime) {
        self.id = stopTime.tripId
        self.routeShortName = stopTime.routeShortName
        self.headsign = stopTime.headsign ?? "inconnu"
        self.departureTime = stopTime.place.departure ?? stopTime.place.arrival ?? Date.distantFuture
        self.realTime = stopTime.realTime
        self.cancelled = stopTime.cancelled
    }
}

struct DepartureQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DepartureEntity] {
        return []
    }
    
    func suggestedEntities() async throws -> [DepartureEntity] {
        return []
    }
}
