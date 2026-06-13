import Foundation
import CoreLocation
import LuxCom
import Polyline

private let tripDaySeparator = "@@D"

struct OfflineProvider: OfflineDataProvider {
    let store: OfflineGTFSStore

    func departures(stopId: String, time: Date, arriveBy: Bool, both: Bool, numberOfEvents: Int) async throws -> StopTimes {
        let rows = try store.departures(stopId: stopId, time: time, limit: numberOfEvents)
        let stopTimes = rows.map { row -> StopTime in
            let depDate = row.depSec.map { OfflineProvider.absolute(row.serviceDay, $0) }
            let arrDate = row.arrSec.map { OfflineProvider.absolute(row.serviceDay, $0) }
            let place = Place(
                name: row.stopName, stopId: row.stopId, parentId: nil,
                lat: row.lat, lon: row.lon, level: 0,
                arrival: arrDate, departure: depDate,
                scheduledArrival: arrDate, scheduledDeparture: depDate,
                scheduledTrack: nil, track: nil, vertexType: .normal
            )
            return StopTime(
                place: place,
                mode: OfflineProvider.mode(forRouteType: row.routeType),
                realTime: false,
                headsign: row.headsign,
                routeShortName: row.routeShortName,
                tripId: OfflineProvider.encodeTripId(row.tripId, serviceDay: row.serviceDay),
                agencyId: row.agencyId,
                cancelled: false
            )
        }
        return StopTimes(stopTimes: stopTimes, previousPageCursor: "", nextPageCursor: "")
    }

    func geocode(text: String, type: LocationType?, place: (Double, Double)?) async throws -> [SearchResult] {
        let stops = try store.searchStops(text: text, limit: 25)
        let biased: [GTFSStop]
        if let place {
            let origin = CLLocation(latitude: place.0, longitude: place.1)
            biased = stops.sorted {
                CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: origin)
                    < CLLocation(latitude: $1.lat, longitude: $1.lon).distance(from: origin)
            }
        } else {
            biased = stops
        }
        return biased.enumerated().map { OfflineProvider.searchResult($1, score: Double(biased.count - $0)) }
    }

    func reverseGeocode(place: (Double, Double), type: LocationType?) async throws -> [SearchResult] {
        let stops = try store.nearestStops(lat: place.0, lon: place.1, limit: 15)
        return stops.enumerated().map { OfflineProvider.searchResult($1, score: Double(stops.count - $0)) }
    }

    func trip(tripId: String) async throws -> Itinerary {
        let (rawId, serviceDay) = OfflineProvider.decodeTripId(tripId)
        guard let details = try store.tripDetails(tripId: rawId, serviceDay: serviceDay),
              details.stops.count >= 2 else {
            throw OfflineError.notAvailableOffline
        }

        let places = details.stops.map { stop -> Place in
            let arr = stop.arrSec.map { OfflineProvider.absolute(serviceDay, $0) }
            let dep = stop.depSec.map { OfflineProvider.absolute(serviceDay, $0) }
            return Place(
                name: stop.name, stopId: stop.stopId, parentId: nil,
                lat: stop.lat, lon: stop.lon, level: 0,
                arrival: arr, departure: dep,
                scheduledArrival: arr, scheduledDeparture: dep,
                scheduledTrack: nil, track: nil, vertexType: .transit
            )
        }

        let start = places.first?.departure ?? places.first?.arrival ?? serviceDay
        let end = places.last?.arrival ?? places.last?.departure ?? serviceDay
        let coords = details.stops.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let encoded = Polyline(coordinates: coords, precision: 1e6).encodedPolyline

        let leg = Leg(
            mode: OfflineProvider.mode(forRouteType: details.routeType),
            from: places.first!, to: places.last!,
            duration: max(0, Int(end.timeIntervalSince(start))),
            startTime: start, endTime: end,
            scheduledStartTime: start, scheduledEndTime: end,
            realTime: false, distance: nil,
            headsign: details.headsign, routeShortName: details.routeShortName,
            intermediateStops: places.count > 2 ? Array(places[1..<(places.count - 1)]) : [],
            legGeometry: LegGeometry(points: encoded, length: coords.count),
            agencyId: details.agencyId, tripId: tripId,
            steps: nil, interlineWithPreviousLeg: nil, alternatives: nil
        )

        return Itinerary(
            duration: max(0, Int(end.timeIntervalSince(start))),
            startTime: start, endTime: end, transfers: 0, legs: [leg]
        )
    }

    private static func searchResult(_ stop: GTFSStop, score: Double) -> SearchResult {
        SearchResult(
            type: .stop, tokens: [], name: stop.name, id: stop.id,
            lat: stop.lat, lon: stop.lon, level: nil,
            street: nil, houseNumber: nil, zip: nil, areas: [], score: score
        )
    }

    static func absolute(_ serviceDay: Date, _ seconds: Int) -> Date {
        serviceDay.addingTimeInterval(TimeInterval(seconds))
    }

    static func encodeTripId(_ id: String, serviceDay: Date) -> String {
        let ymd = OfflineGTFSStore.zurich.dateComponents([.year, .month, .day], from: serviceDay)
        let stamp = String(format: "%04d%02d%02d", ymd.year ?? 0, ymd.month ?? 0, ymd.day ?? 0)
        return "\(id)\(tripDaySeparator)\(stamp)"
    }

    static func decodeTripId(_ encoded: String) -> (id: String, serviceDay: Date) {
        guard let range = encoded.range(of: tripDaySeparator, options: .backwards) else {
            return (encoded, OfflineGTFSStore.zurich.startOfDay(for: Date()))
        }
        let id = String(encoded[..<range.lowerBound])
        let stamp = String(encoded[range.upperBound...])
        if stamp.count == 8, let y = Int(stamp.prefix(4)),
           let m = Int(stamp.dropFirst(4).prefix(2)), let d = Int(stamp.suffix(2)) {
            var comps = DateComponents()
            comps.year = y; comps.month = m; comps.day = d
            let day = OfflineGTFSStore.zurich.date(from: comps) ?? Date()
            return (id, OfflineGTFSStore.zurich.startOfDay(for: day))
        }
        return (id, OfflineGTFSStore.zurich.startOfDay(for: Date()))
    }

    static func mode(forRouteType type: Int) -> TransportationMode {
        switch type {
        case 0, 5, 900...999: return .tram
        case 1, 400...404: return .subway
        case 2, 12, 100...199, 405: return .rail
        case 3, 11, 700...799, 800: return .bus
        case 4, 1000...1099, 1200: return .ferry
        case 6, 7, 1300...1499: return .other
        default: return .transit
        }
    }
}
