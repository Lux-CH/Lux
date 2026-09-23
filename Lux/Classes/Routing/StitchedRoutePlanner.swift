//
//  StitchedRoutePlanner.swift
//  Lux
//

import Foundation
import LuxCom

/// What the trip search needs from a routing answer, whether MOTIS produced it in one
/// request or the planner stitched it together from several.
struct PlannedRoute {
    var itineraries: [Itinerary]
    var direct: [Itinerary]
    var previousPageCursor: String
    var nextPageCursor: String

    init(itineraries: [Itinerary], direct: [Itinerary], previousPageCursor: String, nextPageCursor: String) {
        self.itineraries = itineraries
        self.direct = direct
        self.previousPageCursor = previousPageCursor
        self.nextPageCursor = nextPageCursor
    }

    init(_ trip: Trip) {
        self.init(
            itineraries: trip.itineraries,
            direct: trip.direct,
            previousPageCursor: trip.previousPageCursor,
            nextPageCursor: trip.nextPageCursor
        )
    }
}

/// A via as the planner sees it: MOTIS can route through stops itself, but only by ID,
/// so any other place becomes a real stopover between two separately planned trips.
struct PlannedVia {
    let location: SearchResult
    /// Minutes spent at the via.
    let stay: Int

    var isStop: Bool { location.type == .stop }
}

enum StitchedRoutePlanner {

    /// One stretch between the origin, place vias and destination; stop vias inside it
    /// are left to MOTIS.
    private struct Segment {
        let from: RouteOptions.RouteLocation
        let to: RouteOptions.RouteLocation
        let stopVias: [PlannedVia]
        /// Name for the stopover the segment ends at, replacing MOTIS's "END".
        let endName: String?
        /// Name for the stopover the segment starts from, replacing MOTIS's "START".
        let startName: String?
        /// Seconds to stay at the stopover this segment ends at.
        let stayAfter: TimeInterval
    }

    /// Pages fetched per later segment when the first page doesn't reach every connection.
    private static let maxExtraPages = 2

    static func needsStitching(_ vias: [PlannedVia]) -> Bool {
        vias.contains { !$0.isStop }
    }

    static func plan(_ base: RouteOptions, vias: [PlannedVia]) async throws -> PlannedRoute {
        let segments = makeSegments(base, vias: vias)
        let route = base.arriveBy
            ? try await planBackward(base, segments: segments)
            : try await planForward(base, segments: segments)
        return route
    }

    // MARK: - Segments

    private static func makeSegments(_ base: RouteOptions, vias: [PlannedVia]) -> [Segment] {
        var segments: [Segment] = []
        var from = base.from
        var startName: String? = nil
        var pendingStops: [PlannedVia] = []

        for via in vias {
            if via.isStop {
                pendingStops.append(via)
                continue
            }
            let place = RouteOptions.RouteLocation(
                coordinates: (via.location.lat, via.location.lon),
                level: via.location.level
            )
            segments.append(Segment(
                from: from, to: place, stopVias: pendingStops,
                endName: via.location.name, startName: startName,
                stayAfter: TimeInterval(via.stay * 60)
            ))
            from = place
            startName = via.location.name
            pendingStops = []
        }

        segments.append(Segment(
            from: from, to: base.to, stopVias: pendingStops,
            endName: nil, startName: startName, stayAfter: 0
        ))
        return segments
    }

    private static func options(
        for segment: Segment,
        base: RouteOptions,
        time: Date?,
        arriveBy: Bool,
        pageCursor: String?
    ) -> RouteOptions {
        let stopIDs = segment.stopVias.map(\.location.id)
        let stays = segment.stopVias.map(\.stay)
        return RouteOptions(
            from: segment.from,
            to: segment.to,
            via: stopIDs.isEmpty ? nil : stopIDs,
            viaMinimumStay: stays.contains { $0 > 0 } ? stays : [],
            time: time,
            arriveBy: arriveBy,
            maxTransfers: base.maxTransfers,
            minTransferTime: base.minTransferTime,
            pedestrianProfile: base.pedestrianProfile,
            pedestrianSpeed: base.pedestrianSpeed,
            transitModes: base.transitModes,
            numItineraries: base.numItineraries,
            pageCursor: pageCursor,
            timetableView: base.timetableView,
            // The walk to and from a stopover is the point of it, so walking limits
            // only apply at the real origin and destination.
            maxPreTransitTime: segment.startName == nil ? base.maxPreTransitTime : nil,
            maxPostTransitTime: segment.endName == nil ? base.maxPostTransitTime : nil,
            numLegAlternatives: base.numLegAlternatives
        )
    }

    // MARK: - Forward (leave at)

    /// Plans the first segment at the requested time, then gives every option the next
    /// segment's earliest arrival that leaves once its stay is over.
    private static func planForward(_ base: RouteOptions, segments: [Segment]) async throws -> PlannedRoute {
        let first = try await LuxData.route(
            options(for: segments[0], base: base, time: base.time, arriveBy: false, pageCursor: base.pageCursor)
        )
        var chains = (first.itineraries + first.direct).map { [$0] }

        for index in segments.indices.dropFirst() {
            let segment = segments[index]
            let stay = segments[index - 1].stayAfter
            let readyTimes = chains.map { $0.last!.endTime.addingTimeInterval(stay) }
            guard let earliest = readyTimes.min(), let latest = readyTimes.max() else { break }

            var response = try await LuxData.route(
                options(for: segment, base: base, time: earliest, arriveBy: false, pageCursor: nil)
            )
            var candidates = response.itineraries
            let directs = response.direct
            var pages = 0
            while (candidates.map(\.startTime).max() ?? .distantPast) < latest,
                  pages < maxExtraPages, !response.nextPageCursor.isEmpty {
                response = try await LuxData.route(
                    options(for: segment, base: base, time: earliest, arriveBy: false,
                            pageCursor: response.nextPageCursor)
                )
                candidates += response.itineraries
                pages += 1
            }

            chains = chains.compactMap { chain in
                let ready = chain.last!.endTime.addingTimeInterval(stay)
                let transit = candidates.filter { $0.startTime >= ready }
                // Walk-only options have no timetable, so they can leave right when you're ready.
                let walks = directs.map { $0.shifted(by: ready.timeIntervalSince($0.startTime)) }
                guard let best = (transit + walks).min(by: { $0.endTime < $1.endTime }) else { return nil }
                return chain + [best]
            }
        }

        return PlannedRoute(
            itineraries: merged(chains, segments: segments),
            direct: [],
            previousPageCursor: first.previousPageCursor,
            nextPageCursor: first.nextPageCursor
        )
    }

    // MARK: - Backward (arrive by)

    /// Mirror of `planForward`: anchors on the last segment and works back, giving every
    /// option the previous segment's latest departure that still arrives before the stay.
    private static func planBackward(_ base: RouteOptions, segments: [Segment]) async throws -> PlannedRoute {
        let lastIndex = segments.count - 1
        let last = try await LuxData.route(
            options(for: segments[lastIndex], base: base, time: base.time, arriveBy: true, pageCursor: base.pageCursor)
        )
        var chains = (last.itineraries + last.direct).map { [$0] }

        for index in segments.indices.dropLast().reversed() {
            let segment = segments[index]
            let stay = segment.stayAfter
            let deadlines = chains.map { $0.first!.startTime.addingTimeInterval(-stay) }
            guard let earliest = deadlines.min(), let latest = deadlines.max() else { break }

            var response = try await LuxData.route(
                options(for: segment, base: base, time: latest, arriveBy: true, pageCursor: nil)
            )
            var candidates = response.itineraries
            let directs = response.direct
            var pages = 0
            while (candidates.map(\.endTime).min() ?? .distantFuture) > earliest,
                  pages < maxExtraPages, !response.previousPageCursor.isEmpty {
                response = try await LuxData.route(
                    options(for: segment, base: base, time: latest, arriveBy: true,
                            pageCursor: response.previousPageCursor)
                )
                candidates += response.itineraries
                pages += 1
            }

            chains = chains.compactMap { chain in
                let deadline = chain.first!.startTime.addingTimeInterval(-stay)
                let transit = candidates.filter { $0.endTime <= deadline }
                let walks = directs.map { $0.shifted(by: deadline.timeIntervalSince($0.endTime)) }
                guard let best = (transit + walks).max(by: { $0.startTime < $1.startTime }) else { return nil }
                return [best] + chain
            }
        }

        return PlannedRoute(
            itineraries: merged(chains, segments: segments),
            direct: [],
            previousPageCursor: last.previousPageCursor,
            nextPageCursor: last.nextPageCursor
        )
    }

    // MARK: - Merging

    private static func merged(_ chains: [[Itinerary]], segments: [Segment]) -> [Itinerary] {
        let journeys = chains.compactMap { chain -> Itinerary? in
            guard chain.count == segments.count else { return nil }
            return stitch(chain, segments: segments)
        }
        return removingDominated(journeys).sorted { $0.startTime < $1.startTime }
    }

    private static func stitch(_ chain: [Itinerary], segments: [Segment]) -> Itinerary {
        var legs: [Leg] = []
        for (index, part) in chain.enumerated() {
            let segment = segments[index]
            for (legIndex, leg) in part.legs.enumerated() {
                let isFirst = legIndex == 0
                let isLast = legIndex == part.legs.count - 1
                legs.append(leg.renamingEndpoints(
                    from: isFirst ? segment.startName : nil,
                    to: isLast ? segment.endName : nil
                ))
            }
        }

        let start = chain.first!.startTime
        let end = chain.last!.endTime
        // Getting back on board after a stopover is a change of vehicle, even if each part is direct.
        let partsWithTransit = chain.filter { $0.legs.contains { $0.mode != .walk } }.count
        let transfers = chain.reduce(0) { $0 + $1.transfers } + max(0, partsWithTransit - 1)

        return Itinerary(
            duration: Int(end.timeIntervalSince(start)),
            startTime: start,
            endTime: end,
            transfers: transfers,
            legs: legs
        )
    }

    /// Several first-segment options can funnel into the same connection; keep only
    /// journeys that no other one beats on departure, arrival and transfers at once.
    private static func removingDominated(_ journeys: [Itinerary]) -> [Itinerary] {
        journeys.enumerated().filter { index, journey in
            !journeys.enumerated().contains { otherIndex, other in
                guard otherIndex != index else { return false }
                let noWorse = other.startTime >= journey.startTime
                    && other.endTime <= journey.endTime
                    && other.transfers <= journey.transfers
                let strictlyBetter = other.startTime > journey.startTime
                    || other.endTime < journey.endTime
                    || other.transfers < journey.transfers
                // Identical journeys: keep the first occurrence only.
                return noWorse && (strictlyBetter || otherIndex < index)
            }
        }
        .map(\.element)
    }
}

// MARK: - Retiming and renaming

private extension Itinerary {
    func shifted(by interval: TimeInterval) -> Itinerary {
        guard interval != 0 else { return self }
        return Itinerary(
            duration: duration,
            startTime: startTime.addingTimeInterval(interval),
            endTime: endTime.addingTimeInterval(interval),
            transfers: transfers,
            legs: legs.map { $0.shifted(by: interval) }
        )
    }
}

private extension Leg {
    func shifted(by interval: TimeInterval) -> Leg {
        rebuilt(
            from: from.shifted(by: interval),
            to: to.shifted(by: interval),
            shift: interval
        )
    }

    func renamingEndpoints(from fromName: String?, to toName: String?) -> Leg {
        guard fromName != nil || toName != nil else { return self }
        var newFrom = from
        var newTo = to
        if let fromName { newFrom.name = fromName }
        if let toName { newTo.name = toName }
        return rebuilt(from: newFrom, to: newTo, shift: 0)
    }

    private func rebuilt(from: Place, to: Place, shift: TimeInterval) -> Leg {
        Leg(
            mode: mode, from: from, to: to, duration: duration,
            startTime: startTime.addingTimeInterval(shift),
            endTime: endTime.addingTimeInterval(shift),
            scheduledStartTime: scheduledStartTime.addingTimeInterval(shift),
            scheduledEndTime: scheduledEndTime.addingTimeInterval(shift),
            realTime: realTime, cancelled: cancelled, distance: distance,
            headsign: headsign, routeShortName: routeShortName,
            intermediateStops: intermediateStops, legGeometry: legGeometry,
            agencyId: agencyId, tripId: tripId, steps: steps,
            interlineWithPreviousLeg: interlineWithPreviousLeg, alternatives: alternatives
        )
    }
}

private extension Place {
    func shifted(by interval: TimeInterval) -> Place {
        Place(
            name: name, stopId: stopId, parentId: parentId,
            lat: lat, lon: lon, level: level,
            arrival: arrival?.addingTimeInterval(interval),
            departure: departure?.addingTimeInterval(interval),
            scheduledArrival: scheduledArrival?.addingTimeInterval(interval),
            scheduledDeparture: scheduledDeparture?.addingTimeInterval(interval),
            scheduledTrack: scheduledTrack, track: track,
            vertexType: vertexType, modes: modes, importance: importance
        )
    }
}
