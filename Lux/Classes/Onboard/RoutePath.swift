//
//  RoutePath.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import CoreLocation
import Polyline

struct RoutePath {
    struct Projection {
        let along: CLLocationDistance
        let offset: CLLocationDistance
        let coordinate: CLLocationCoordinate2D
        let segment: Int
    }

    let coordinates: [CLLocationCoordinate2D]
    let cumulative: [CLLocationDistance]

    var length: CLLocationDistance { cumulative.last ?? 0 }
    var isEmpty: Bool { coordinates.count < 2 }

    init(coordinates: [CLLocationCoordinate2D]) {
        var cleaned: [CLLocationCoordinate2D] = []
        cleaned.reserveCapacity(coordinates.count)
        for coordinate in coordinates where CLLocationCoordinate2DIsValid(coordinate) {
            if let last = cleaned.last, last.latitude == coordinate.latitude, last.longitude == coordinate.longitude {
                continue
            }
            cleaned.append(coordinate)
        }
        self.coordinates = cleaned

        var cumulative: [CLLocationDistance] = [0]
        cumulative.reserveCapacity(cleaned.count)
        for index in cleaned.indices.dropFirst() {
            cumulative.append(cumulative[index - 1] + cleaned[index - 1].distance(to: cleaned[index]))
        }
        self.cumulative = cleaned.isEmpty ? [] : cumulative
    }

    init(encoded: String, precision: Double = 1e6, fallback: [CLLocationCoordinate2D] = []) {
        let decoded = Polyline(encodedPolyline: encoded, precision: precision).coordinates ?? []
        self.init(coordinates: decoded.count >= 2 ? decoded : fallback)
    }

    func project(_ point: CLLocationCoordinate2D, hint: CLLocationDistance? = nil) -> Projection? {
        guard coordinates.count >= 2 else {
            guard let only = coordinates.first else { return nil }
            return Projection(along: 0, offset: only.distance(to: point), coordinate: only, segment: 0)
        }

        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLon = 111_320.0 * cos(point.latitude * .pi / 180)

        var best: (score: Double, projection: Projection)?
        for index in 0..<(coordinates.count - 1) {
            let a = coordinates[index]
            let b = coordinates[index + 1]
            let ax = (a.longitude - point.longitude) * metersPerDegreeLon
            let ay = (a.latitude - point.latitude) * metersPerDegreeLat
            let bx = (b.longitude - point.longitude) * metersPerDegreeLon
            let by = (b.latitude - point.latitude) * metersPerDegreeLat
            let dx = bx - ax
            let dy = by - ay
            let lengthSquared = dx * dx + dy * dy
            let t = lengthSquared > 0 ? max(0, min(1, -(ax * dx + ay * dy) / lengthSquared)) : 0
            let px = ax + t * dx
            let py = ay + t * dy
            let offset = (px * px + py * py).squareRoot()
            let along = cumulative[index] + t * (cumulative[index + 1] - cumulative[index])

            let score = offset + (hint.map { abs(along - $0) * 0.15 } ?? 0)
            if best == nil || score < best!.score {
                let coordinate = CLLocationCoordinate2D(
                    latitude: a.latitude + (b.latitude - a.latitude) * t,
                    longitude: a.longitude + (b.longitude - a.longitude) * t
                )
                best = (score, Projection(along: along, offset: offset, coordinate: coordinate, segment: index))
            }
        }
        return best?.projection
    }

    func projectSequence(_ points: [CLLocationCoordinate2D]) -> [CLLocationDistance] {
        var result: [CLLocationDistance] = []
        var floor: CLLocationDistance = 0
        for point in points {
            let along = max(floor, project(point, hint: floor)?.along ?? floor)
            result.append(along)
            floor = along
        }
        return result
    }

    func coordinate(at along: CLLocationDistance) -> CLLocationCoordinate2D? {
        guard let first = coordinates.first else { return nil }
        guard coordinates.count >= 2, along > 0 else { return first }
        guard along < length else { return coordinates.last }

        var low = 0
        var high = cumulative.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if cumulative[mid] <= along { low = mid } else { high = mid }
        }
        let span = cumulative[high] - cumulative[low]
        let t = span > 0 ? (along - cumulative[low]) / span : 0
        let a = coordinates[low]
        let b = coordinates[high]
        return CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    func bearing(at along: CLLocationDistance, lookAhead: CLLocationDistance = 25) -> CLLocationDirection? {
        guard let from = coordinate(at: max(0, along - 5)),
              let to = coordinate(at: min(length, along + lookAhead)),
              from.distance(to: to) > 1 else { return nil }
        return from.bearing(to: to)
    }

    func slice(from start: CLLocationDistance, to end: CLLocationDistance) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }
        let lower = max(0, min(start, end))
        let upper = min(length, max(start, end))
        guard upper > lower, let first = coordinate(at: lower), let last = coordinate(at: upper) else { return [] }

        var result = [first]
        for index in coordinates.indices where cumulative[index] > lower && cumulative[index] < upper {
            result.append(coordinates[index])
        }
        result.append(last)
        return result
    }

    func sliced(from start: CLLocationDistance, to end: CLLocationDistance) -> RoutePath {
        RoutePath(coordinates: slice(from: start, to: end))
    }
}

extension CLLocationCoordinate2D {
    func bearing(to other: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLon = (other.longitude - longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let degrees = atan2(y, x) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    func offset(by distance: CLLocationDistance, bearing: CLLocationDirection) -> CLLocationCoordinate2D {
        let radians = bearing * .pi / 180
        let dLat = distance * cos(radians) / 111_320
        let dLon = distance * sin(radians) / (111_320 * cos(latitude * .pi / 180))
        return CLLocationCoordinate2D(latitude: latitude + dLat, longitude: longitude + dLon)
    }
}

enum Angle360 {
    static func delta(from: Double, to: Double) -> Double {
        var difference = (to - from).truncatingRemainder(dividingBy: 360)
        if difference > 180 { difference -= 360 }
        if difference < -180 { difference += 360 }
        return difference
    }

    static func normalized(_ angle: Double) -> Double {
        let value = angle.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}
