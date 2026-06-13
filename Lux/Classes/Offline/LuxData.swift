//
//  LuxData.swift
//  Lux
//
//  Created by Constantin Clerc on 13.06.2026.
//

import Foundation
import LuxCom

enum LuxData {

    static func departures(
        stopId: String,
        time: Date = Date(),
        arriveBy: Bool = false,
        both: Bool = false,
        direction: String? = nil,
        mode: [String]? = ["TRANSIT"],
        numberOfEvents: Int,
        radius: Int? = nil,
        pageCursor: String? = nil
    ) async throws -> StopTimes {
        if let provider = OfflineRouter.shared.active {
            return try await provider.departures(
                stopId: stopId, time: time, arriveBy: arriveBy,
                both: both, numberOfEvents: numberOfEvents
            )
        }
        return try await getDeparturesForStop(
            stopId: stopId, time: time, arriveBy: arriveBy, both: both,
            direction: direction, mode: mode, numberOfEvents: numberOfEvents,
            radius: radius, pageCursor: pageCursor
        )
    }

    static func geocode(
        text: String,
        language: String = "fr",
        type: LocationType? = nil,
        place: (Double, Double)? = nil,
        placeBias: Int? = nil
    ) async throws -> [SearchResult] {
        if let provider = OfflineRouter.shared.active {
            return try await provider.geocode(text: text, type: type, place: place)
        }
        return try await geocode(
            text: text, language: language, type: type,
            place: place, placeBias: placeBias
        )
    }

    static func reverseGeocode(
        place: (Double, Double),
        type: LocationType? = nil
    ) async throws -> [SearchResult] {
        if let provider = OfflineRouter.shared.active {
            return try await provider.reverseGeocode(place: place, type: type)
        }
        return try await reverseGeocode(place: place, type: type)
    }

    static func trip(tripId: String) async throws -> Itinerary {
        if let provider = OfflineRouter.shared.active {
            return try await provider.trip(tripId: tripId)
        }
        return try await getTrip(tripId: tripId)
    }

    static func route(_ options: RouteOptions) async throws -> Trip {
        if OfflineRouter.shared.active != nil {
            throw OfflineError.tripPlanningUnavailable
        }
        return try await getRoute(options)
    }
}
