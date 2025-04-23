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
        let isStop: Bool
    }
    
    // MARK: - KeyFrame Calculation
    static func calculateKeyFrames(for leg: Leg) -> [KeyFrame] {
        let polyline = Polyline(encodedPolyline: leg.legGeometry.points, precision: 1e7)
        guard let coordinates = polyline.coordinates, coordinates.count >= 2 else { return [] }
        
        let departureTime = leg.startTime.timeIntervalSince1970
        let arrivalTime = leg.endTime.timeIntervalSince1970
        
        var stops: [(time: TimeInterval, coordinate: CLLocationCoordinate2D, isArrival: Bool)] = []
        
        stops.append((departureTime, CLLocationCoordinate2D(latitude: leg.from.lat, longitude: leg.from.lon), false))
        
        if let intermediateStops = leg.intermediateStops {
            for stop in intermediateStops {
                if let arrivalTime = stop.arrival?.timeIntervalSince1970 ?? stop.scheduledArrival?.timeIntervalSince1970 {
                    stops.append((arrivalTime, CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon), true))
                }
                
                if let departureTime = stop.departure?.timeIntervalSince1970 ?? stop.scheduledDeparture?.timeIntervalSince1970 {
                    stops.append((departureTime, CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon), false))
                }
            }
        }
        
        stops.append((arrivalTime, CLLocationCoordinate2D(latitude: leg.to.lat, longitude: leg.to.lon), true))
        
        stops.sort { $0.time < $1.time }
        
        var mappedStops: [(time: TimeInterval, index: Int, isArrival: Bool)] = []
        
        for stop in stops {
            let closestIndex = findClosestPointIndex(coordinates: coordinates, to: stop.coordinate)
            mappedStops.append((stop.time, closestIndex, stop.isArrival))
        }
        
        var keyFrames: [KeyFrame] = []
        
        for i in 0..<(mappedStops.count - 1) {
            let startStop = mappedStops[i]
            let endStop = mappedStops[i + 1]
            
            if startStop.index == endStop.index && startStop.isArrival && !endStop.isArrival {
                let point = coordinates[startStop.index]
                let heading = (i > 0) ? keyFrames.last?.heading ?? 0 :
                    (startStop.index + 1 < coordinates.count) ?
                    coordinates[startStop.index].heading(to: coordinates[startStop.index + 1]) : 0
                
                keyFrames.append(KeyFrame(
                    point: point,
                    heading: heading,
                    time: startStop.time,
                    isStop: true
                ))
                
                keyFrames.append(KeyFrame(
                    point: point,
                    heading: heading,
                    time: endStop.time,
                    isStop: false
                ))
                
                continue
            }
            
            let segmentStartTime = startStop.time
            let segmentEndTime = endStop.time
            let segmentDuration = segmentEndTime - segmentStartTime
            
            let startIndex = startStop.index
            let endIndex = endStop.index
            
            let increment = startIndex <= endIndex ? 1 : -1
            let segmentRange = stride(from: startIndex, through: endIndex, by: increment)
            
            var segmentCoordinates: [CLLocationCoordinate2D] = []
            for idx in segmentRange {
                segmentCoordinates.append(coordinates[idx])
            }
            
            let totalDistance = zip(segmentCoordinates, segmentCoordinates.dropFirst())
                .reduce(0) { $0 + $1.0.distance(to: $1.1) }
            
            if totalDistance > 0 {
                var currentDistance: CLLocationDistance = 0
                var previousPoint: CLLocationCoordinate2D? = nil
                
                for idx in segmentRange {
                    let point = coordinates[idx]
                    
                    if let prevPoint = previousPoint {
                        let distance = prevPoint.distance(to: point)
                        currentDistance += distance
                        
                        let ratio = currentDistance / totalDistance
                        let time = segmentStartTime + ratio * segmentDuration
                        
                        let heading = prevPoint.heading(to: point)
                        
                        if idx != startIndex || keyFrames.isEmpty {
                            keyFrames.append(KeyFrame(
                                point: point,
                                heading: heading,
                                time: time,
                                isStop: idx == endIndex && endStop.isArrival
                            ))
                        }
                    } else if idx == startIndex {
                        let heading = (idx + increment >= 0 && idx + increment < coordinates.count) ?
                            point.heading(to: coordinates[idx + increment]) :
                            keyFrames.last?.heading ?? 0
                        
                        keyFrames.append(KeyFrame(
                            point: point,
                            heading: heading,
                            time: segmentStartTime,
                            isStop: startStop.isArrival
                        ))
                    }
                    
                    previousPoint = point
                }
            } else {
                let heading = keyFrames.last?.heading ?? 0
                keyFrames.append(KeyFrame(
                    point: coordinates[startIndex],
                    heading: heading,
                    time: segmentStartTime,
                    isStop: startStop.isArrival
                ))
                
                keyFrames.append(KeyFrame(
                    point: coordinates[endIndex],
                    heading: heading,
                    time: segmentEndTime,
                    isStop: endStop.isArrival
                ))
            }
        }
        
        return keyFrames
    }
    
    private static func findClosestPointIndex(coordinates: [CLLocationCoordinate2D], to target: CLLocationCoordinate2D) -> Int {
        var closestDistance = Double.infinity
        var closestIndex = 0
        
        for (index, coordinate) in coordinates.enumerated() {
            let distance = coordinate.distance(to: target)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        
        return closestIndex
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
                let segmentDuration = endFrame.time - startFrame.time
                let progress = (timestamp - startFrame.time) / segmentDuration
                
                let easedProgress = calculateEasedProgress(
                    progress: progress,
                    isStartStop: startFrame.isStop,
                    isEndStop: endFrame.isStop
                )
                
                return interpolate(
                    from: startFrame.point,
                    to: endFrame.point,
                    progress: easedProgress
                )
            }
        }
        return nil
    }
    
    private static func calculateEasedProgress(progress: Double, isStartStop: Bool, isEndStop: Bool) -> Double {
        if isEndStop {
            // Slow down when approaching a stop (ease out)
            return 1 - pow(1 - progress, 2)
        } else if isStartStop {
            // Speed up when leaving a stop (ease in)
            return progress * progress
        }
        
        return progress
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
