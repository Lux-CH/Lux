//
//  PolylineCodec.swift
//  Lux
//
//  Created by Constantin Clerc on 27.10.2026.
//

import Foundation
import CoreLocation

enum PolylineCodec {
    private final class Decoded {
        let coordinates: [CLLocationCoordinate2D]
        init(_ coordinates: [CLLocationCoordinate2D]) { self.coordinates = coordinates }
    }

    private static let cache: NSCache<NSString, Decoded> = {
        let cache = NSCache<NSString, Decoded>()
        cache.countLimit = 256
        return cache
    }()

    private static let cachedLength = 128

    static func decode(_ encoded: String, precision: Double = 1e6) -> [CLLocationCoordinate2D] {
        guard !encoded.isEmpty, precision > 0 else { return [] }
        guard encoded.utf8.count >= cachedLength else { return decodeUncached(encoded, precision: precision) }

        let key = "\(precision)|\(encoded)" as NSString
        if let hit = cache.object(forKey: key) { return hit.coordinates }
        let coordinates = decodeUncached(encoded, precision: precision)
        cache.setObject(Decoded(coordinates), forKey: key)
        return coordinates
    }

    static func encode(_ coordinates: [CLLocationCoordinate2D], precision: Double = 1e6) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(coordinates.count * 10)
        var previousLat = 0
        var previousLon = 0
        for coordinate in coordinates {
            let lat = Int((coordinate.latitude * precision).rounded())
            let lon = Int((coordinate.longitude * precision).rounded())
            append(lat - previousLat, to: &bytes)
            append(lon - previousLon, to: &bytes)
            previousLat = lat
            previousLon = lon
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func decodeUncached(_ encoded: String, precision: Double) -> [CLLocationCoordinate2D] {
        var reader = Reader(bytes: encoded.utf8.makeIterator())
        var coordinates: [CLLocationCoordinate2D] = []
        coordinates.reserveCapacity(encoded.utf8.count / 6)
        var lat = 0
        var lon = 0
        while let deltaLat = reader.next(), let deltaLon = reader.next() {
            lat += deltaLat
            lon += deltaLon
            coordinates.append(CLLocationCoordinate2D(latitude: Double(lat) / precision, longitude: Double(lon) / precision))
        }
        return coordinates
    }

    private static func append(_ value: Int, to bytes: inout [UInt8]) {
        var remaining = value < 0 ? ~(value << 1) : value << 1
        while remaining >= 0x20 {
            bytes.append(UInt8((0x20 | (remaining & 0x1f)) + 63))
            remaining >>= 5
        }
        bytes.append(UInt8(remaining + 63))
    }

    private struct Reader {
        var bytes: String.UTF8View.Iterator

        mutating func next() -> Int? {
            var value = 0
            var shift = 0
            while let byte = bytes.next() {
                let chunk = Int(byte) - 63
                guard chunk >= 0, shift < 60 else { return nil }
                value |= (chunk & 0x1f) << shift
                shift += 5
                if chunk < 0x20 {
                    return value & 1 != 0 ? ~(value >> 1) : value >> 1
                }
            }
            return nil
        }
    }
}
