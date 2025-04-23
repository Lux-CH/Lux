//
//  VehicleVisualisation.swift
//  Lux
//
//  Created by Constantin Clerc on 23.04.2025.
//
//  This was mainly inspired from https://github.com/motis-project/motis/blob/master/ui/src/lib/RailViz.svelte

import CoreLocation
import LuxCom
import Polyline
import SwiftUICore

struct VehicleAnnotation: Identifiable {
    let id: String
    var coordinate: CLLocationCoordinate2D
    let mode: TransportationMode
    let routeShortName: String?
    let color: Color
}

enum VehicleVisualisation {
    // MARK: - KeyFrame Definition
    struct KeyFrame {
        let point: CLLocationCoordinate2D
        let heading: CLLocationDirection
        let time: TimeInterval
    }
    
    // MARK: - KeyFrame Calculation
    static func calculateKeyFrames(for leg: Leg) -> [KeyFrame] {
        let polyline = Polyline(encodedPolyline: leg.legGeometry.points, precision: 1e7)
        guard let coordinates = polyline.coordinates, coordinates.count >= 2 else { return [] }
        
        let departureTime = leg.startTime.timeIntervalSince1970
        let arrivalTime = leg.endTime.timeIntervalSince1970
        let totalDuration = arrivalTime - departureTime
        
        let totalDistance = zip(coordinates, coordinates.dropFirst())
            .reduce(0) { $0 + $1.0.distance(to: $1.1) }
        
        var keyFrames: [KeyFrame] = []
        var currentDistance: CLLocationDistance = 0
        
        for i in 0..<(coordinates.count - 1) {
            let from = coordinates[i]
            let to = coordinates[i + 1]
            let distance = from.distance(to: to)
            let heading = from.heading(to: to)
            let ratio = currentDistance / totalDistance
            let time = departureTime + ratio * totalDuration
            
            keyFrames.append(KeyFrame(point: from, heading: heading, time: time))
            currentDistance += distance
        }
        
        keyFrames.append(KeyFrame(
            point: coordinates.last!,
            heading: keyFrames.last?.heading ?? 0,
            time: arrivalTime
        ))
        
        return keyFrames
    }
    
    // MARK: - Real-Time Position Interpolation
    static func interpolatePosition(at timestamp: TimeInterval, using keyFrames: [KeyFrame]) -> CLLocationCoordinate2D? {
        guard !keyFrames.isEmpty else { return nil }
        
        if timestamp <= keyFrames.first!.time { return keyFrames.first!.point }
        if timestamp >= keyFrames.last!.time { return keyFrames.last!.point }
        
        for i in 1..<keyFrames.count {
            let startFrame = keyFrames[i - 1]
            let endFrame = keyFrames[i]
            if timestamp >= startFrame.time && timestamp <= endFrame.time {
                let progress = (timestamp - startFrame.time) / (endFrame.time - startFrame.time)
                return interpolate(from: startFrame.point, to: endFrame.point, progress: progress)
            }
        }
        return nil
    }
    
    private static func interpolate(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        progress: Double
    ) -> CLLocationCoordinate2D {
        let lat = start.latitude + (end.latitude - start.latitude) * progress
        let lon = start.longitude + (end.longitude - start.longitude) * progress
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }
    
    func heading(to other: CLLocationCoordinate2D) -> CLLocationDirection {
        let deltaLon = other.longitude - longitude
        let y = sin(deltaLon) * cos(other.latitude)
        let x = cos(latitude) * sin(other.latitude) - sin(latitude) * cos(other.latitude) * cos(deltaLon)
        return atan2(y, x) * 180 / .pi
    }
}
