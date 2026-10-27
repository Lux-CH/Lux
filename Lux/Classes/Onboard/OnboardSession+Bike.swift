//
//  OnboardSession+Bike.swift
//  Lux
//
//  Created by Constantin Clerc on 27.10.2026.
//

import Foundation
import CoreLocation
import SwiftUI
import LuxCom

extension OnboardSession {
    var isOnBikeLeg: Bool { currentLeg?.mode.isCycling == true }

    var currentOffRouteDistance: CLLocationDistance {
        isOnBikeLeg ? 55 : offRouteDistance
    }

    func streetInstruction(to leg: Leg, isDestination: Bool) -> String {
        let place = placeName(leg.to, isDestination: isDestination)
        return leg.mode.isCycling
            ? String(localized: "Pédalez jusqu'à \(place)")
            : String(localized: "Marchez jusqu'à \(place)")
    }

    func rerouteByBike(from location: CLLocation, index: Int) {
        let leg = legs[index]
        rerouteTask?.cancel()
        rerouteTask = Task { [weak self] in
            var options = RouteOptions(
                from: .init(coordinates: (location.coordinate.latitude, location.coordinate.longitude)),
                to: .init(coordinates: (leg.to.lat, leg.to.lon)),
                via: nil,
                viaMinimumStay: [],
                time: Date(),
                arriveBy: false,
                maxTransfers: 0,
                minTransferTime: 0,
                pedestrianProfile: .foot,
                pedestrianSpeed: nil,
                transitModes: nil,
                numItineraries: 1,
                timetableView: false,
                maxPreTransitTime: nil,
                maxPostTransitTime: nil
            )
            options.directModes = [.bike]
            let speed = BikeMode.storedSpeed
            options.cyclingSpeed = speed == BikeMode.defaultSpeed ? nil : speed

            guard let trip = try? await LuxData.route(options),
                  let ride = trip.direct.first?.legs.first(where: { $0.mode == .bike }),
                  !Task.isCancelled, let self, self.legIndex == index, self.phase == .walking else { return }

            let path = RoutePath(encoded: ride.legGeometry.points)
            guard !path.isEmpty else { return }
            self.paths[index] = path
            self.maneuvers[index] = WalkManeuverBuilder.maneuvers(for: ride.steps ?? [], on: path)
            self.reroutedWalks.insert(index)

            let current = self.legs[index]
            let end = self.now.addingTimeInterval(TimeInterval(ride.duration))
            let to = Place(
                name: current.to.name, stopId: current.to.stopId, parentId: current.to.parentId,
                lat: current.to.lat, lon: current.to.lon, level: current.to.level,
                arrival: end, departure: nil, scheduledArrival: end, scheduledDeparture: nil,
                scheduledTrack: nil, track: nil, vertexType: current.to.vertexType
            )
            self.legs[index] = Leg(
                mode: current.mode, from: current.from, to: to,
                duration: Int(end.timeIntervalSince(current.startTime)), startTime: current.startTime, endTime: end,
                scheduledStartTime: current.scheduledStartTime, scheduledEndTime: end,
                realTime: current.realTime, cancelled: current.cancelled, distance: ride.distance,
                headsign: current.headsign, routeShortName: current.routeShortName,
                intermediateStops: current.intermediateStops,
                legGeometry: ride.legGeometry,
                agencyId: current.agencyId, tripId: current.tripId, steps: ride.steps,
                rental: current.rental
            )
            self.alongInLeg = 0
            self.offRouteStreak = 0
            self.spokenManeuvers.removeAll()
            withAnimation { self.isOffRoute = false }
            self.announcer.announce(String(localized: "Nouvel itinéraire à vélo."), urgency: .guidance)
            self.evaluate()
        }
    }
}
