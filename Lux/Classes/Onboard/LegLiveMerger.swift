//
//  LegLiveMerger.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import Foundation
import LuxCom

enum LegLiveMerger {
    static func merge(_ leg: Leg, with trip: Itinerary, retargetingTo newTripId: String? = nil) -> Leg? {
        guard let tripLeg = trip.legs.first(where: { $0.tripId == (newTripId ?? leg.tripId) }) ?? trip.legs.first else { return nil }
        let stops = tripLeg.allStops
        guard let boardIndex = index(of: leg.from, in: stops, scheduled: \.scheduledDeparture),
              let alightIndex = index(of: leg.to, in: stops, scheduled: \.scheduledArrival, after: boardIndex),
              alightIndex > boardIndex else { return nil }

        let from = stops[boardIndex]
        let to = stops[alightIndex]
        let startTime = from.departure ?? from.scheduledDeparture ?? leg.startTime
        let endTime = to.arrival ?? to.scheduledArrival ?? leg.endTime

        return Leg(
            mode: leg.mode,
            from: from,
            to: to,
            duration: max(0, Int(endTime.timeIntervalSince(startTime))),
            startTime: startTime,
            endTime: endTime,
            scheduledStartTime: from.scheduledDeparture ?? leg.scheduledStartTime,
            scheduledEndTime: to.scheduledArrival ?? leg.scheduledEndTime,
            realTime: tripLeg.realTime,
            cancelled: tripLeg.cancelled,
            distance: leg.distance,
            headsign: leg.headsign ?? tripLeg.headsign,
            routeShortName: leg.routeShortName ?? tripLeg.routeShortName,
            intermediateStops: Array(stops[(boardIndex + 1)..<alightIndex]),
            legGeometry: leg.legGeometry,
            agencyId: leg.agencyId,
            tripId: newTripId ?? leg.tripId,
            steps: leg.steps,
            interlineWithPreviousLeg: leg.interlineWithPreviousLeg,
            alternatives: leg.alternatives
        )
    }

    static func slice(_ tripLeg: Leg, boardIndex: Int, alightIndex: Int) -> Leg? {
        let stops = tripLeg.allStops
        guard stops.indices.contains(boardIndex), stops.indices.contains(alightIndex), alightIndex > boardIndex else { return nil }
        let from = stops[boardIndex]
        let to = stops[alightIndex]
        let startTime = from.departure ?? from.scheduledDeparture ?? tripLeg.startTime
        let endTime = to.arrival ?? to.scheduledArrival ?? tripLeg.endTime

        return Leg(
            mode: tripLeg.mode,
            from: from,
            to: to,
            duration: max(0, Int(endTime.timeIntervalSince(startTime))),
            startTime: startTime,
            endTime: endTime,
            scheduledStartTime: from.scheduledDeparture ?? startTime,
            scheduledEndTime: to.scheduledArrival ?? endTime,
            realTime: tripLeg.realTime,
            cancelled: tripLeg.cancelled,
            distance: nil,
            headsign: tripLeg.headsign,
            routeShortName: tripLeg.routeShortName,
            intermediateStops: Array(stops[(boardIndex + 1)..<alightIndex]),
            legGeometry: tripLeg.legGeometry,
            agencyId: tripLeg.agencyId,
            tripId: tripLeg.tripId,
            steps: nil
        )
    }

    private static func index(
        of place: Place,
        in stops: [Place],
        scheduled: KeyPath<Place, Date?>,
        after lowerBound: Int = -1
    ) -> Int? {
        let candidates = stops.indices.filter { $0 > lowerBound }
        if let stopId = place.stopId {
            if let wanted = place[keyPath: scheduled],
               let exact = candidates.first(where: { stops[$0].stopId == stopId && stops[$0][keyPath: scheduled] == wanted }) {
                return exact
            }
            if let byId = candidates.first(where: { stops[$0].stopId == stopId }) {
                return byId
            }
        }
        return candidates.first { stops[$0].name == place.name }
    }
}
