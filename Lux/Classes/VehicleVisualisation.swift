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
        let isDwelling: Bool
    }
    
    // MARK: - Default Dwell Times
    private static func defaultDwellTime(for mode: TransportationMode) -> TimeInterval {
        switch mode {
        case .bus, .tram:
            return 25
        case .rail, .highSpeedRail, .regionalRail, .regionalFastRail, .subway, .ferry:
            return 50
        default:
            return 30
        }
    }
    
    // MARK: - KeyFrame Calculation
    static func calculateKeyFrames(for leg: Leg) -> [KeyFrame] {
        let polyline = Polyline(encodedPolyline: leg.legGeometry.points, precision: 1e7)
        guard let coordinates = polyline.coordinates, coordinates.count >= 2 else { return [] }
        
        let departureTime = leg.startTime.timeIntervalSince1970
        let arrivalTime = leg.endTime.timeIntervalSince1970
        
        var stops: [(arrivalTime: TimeInterval?, departureTime: TimeInterval, coordinate: CLLocationCoordinate2D)] = []
        
        stops.append((nil, departureTime, CLLocationCoordinate2D(latitude: leg.from.lat, longitude: leg.from.lon)))
        
        if let intermediateStops = leg.intermediateStops {
            for stop in intermediateStops {
                let arrivalTime = stop.arrival?.timeIntervalSince1970 ?? stop.scheduledArrival?.timeIntervalSince1970
                let departureTime = stop.departure?.timeIntervalSince1970 ?? stop.scheduledDeparture?.timeIntervalSince1970
                
                if let depTime = departureTime {
                    stops.append((arrivalTime, depTime, CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)))
                } else if let arrTime = arrivalTime {
                    stops.append((arrTime, arrTime, CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)))
                }
            }
        }
        
        stops.append((arrivalTime, arrivalTime, CLLocationCoordinate2D(latitude: leg.to.lat, longitude: leg.to.lon)))
        
        let mode = leg.mode
        for i in 1..<(stops.count-1) {
            if let arrivalTime = stops[i].arrivalTime, abs(arrivalTime - stops[i].departureTime) < 1.0 {
                stops[i].departureTime = arrivalTime + defaultDwellTime(for: mode)
            }
        }
        
        var mappedStops: [(arrivalTime: TimeInterval?, departureTime: TimeInterval, index: Int)] = []
        
        for stop in stops {
            let closestIndex = findClosestPointIndex(coordinates: coordinates, to: stop.coordinate)
            mappedStops.append((stop.arrivalTime, stop.departureTime, closestIndex))
        }
        
        var keyFrames: [KeyFrame] = []
        
        let firstStop = mappedStops.first!
        keyFrames.append(KeyFrame(
            point: coordinates[firstStop.index],
            heading: firstStop.index + 1 < coordinates.count ?
                coordinates[firstStop.index].heading(to: coordinates[firstStop.index + 1]) : 0,
            time: firstStop.departureTime,
            isStop: true,
            isDwelling: false
        ))
        
        for i in 0..<(mappedStops.count - 1) {
            let startStop = mappedStops[i]
            let endStop = mappedStops[i + 1]
            
            if let arrivalTime = endStop.arrivalTime, arrivalTime < endStop.departureTime {
                createMovementSegment(
                    coordinates: coordinates,
                    fromIndex: startStop.index,
                    toIndex: endStop.index,
                    startTime: startStop.departureTime,
                    endTime: arrivalTime,
                    keyFrames: &keyFrames,
                    isDepartingFromStop: true,
                    isArrivingAtStop: true
                )
                
                keyFrames.append(KeyFrame(
                    point: coordinates[endStop.index],
                    heading: calculateHeading(coordinates: coordinates, atIndex: endStop.index),
                    time: arrivalTime,
                    isStop: true,
                    isDwelling: true
                ))
                
                keyFrames.append(KeyFrame(
                    point: coordinates[endStop.index],
                    heading: calculateHeading(coordinates: coordinates, atIndex: endStop.index),
                    time: endStop.departureTime,
                    isStop: true,
                    isDwelling: false
                ))
            } else {
                createMovementSegment(
                    coordinates: coordinates,
                    fromIndex: startStop.index,
                    toIndex: endStop.index,
                    startTime: startStop.departureTime,
                    endTime: endStop.departureTime,
                    keyFrames: &keyFrames,
                    isDepartingFromStop: true,
                    isArrivingAtStop: true
                )
            }
        }
        
        return keyFrames
    }
    
    private static func calculateHeading(coordinates: [CLLocationCoordinate2D], atIndex index: Int) -> CLLocationDirection {
        if index + 1 < coordinates.count {
            return coordinates[index].heading(to: coordinates[index + 1])
        } else if index > 0 {
            return coordinates[index - 1].heading(to: coordinates[index])
        }
        return 0
    }
    
    private static func createMovementSegment(
        coordinates: [CLLocationCoordinate2D],
        fromIndex: Int,
        toIndex: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        keyFrames: inout [KeyFrame],
        isDepartingFromStop: Bool,
        isArrivingAtStop: Bool
    ) {
        let segmentDuration = endTime - startTime
        if segmentDuration <= 0 || fromIndex == toIndex { return }
        
        let increment = fromIndex <= toIndex ? 1 : -1
        let segmentRange = stride(from: fromIndex, through: toIndex, by: increment)
        
        let segmentCoordinates: [CLLocationCoordinate2D] = segmentRange.map { coordinates[$0] }
        
        let totalDistance = zip(segmentCoordinates, segmentCoordinates.dropFirst())
            .reduce(0) { $0 + $1.0.distance(to: $1.1) }
        
        if totalDistance > 0 {
            var distances: [Double] = [0]
            var cumulativeDistance: Double = 0
            
            for i in 1..<segmentCoordinates.count {
                cumulativeDistance += segmentCoordinates[i-1].distance(to: segmentCoordinates[i])
                distances.append(cumulativeDistance)
            }
            
            // apply velocity profile,  3 sections :
            // 1. Acceleration from stop (if exisitng)
            // 2. Cruising at normal speed
            // 3. Deceleration to stop (if applicable)
            
            let accelerationDistance = isDepartingFromStop ? min(totalDistance * 0.15, 200.0) : 0
            let decelerationDistance = isArrivingAtStop ? min(totalDistance * 0.15, 200.0) : 0
            let cruisingDistance = totalDistance - accelerationDistance - decelerationDistance
            
            let accelerationTime = isDepartingFromStop ? segmentDuration * 0.12 : 0
            let decelerationTime = isArrivingAtStop ? segmentDuration * 0.12 : 0
            let cruisingTime = segmentDuration - accelerationTime - decelerationTime
            
            for i in 0..<segmentCoordinates.count {
                let distance = distances[i]
                var time = startTime
                
                if distance <= accelerationDistance && accelerationDistance > 0 {
                    let accelerationProgress = distance / accelerationDistance
                    let easedProgress = easeInQuad(accelerationProgress)
                    time += accelerationTime * easedProgress
                } else if distance >= totalDistance - decelerationDistance && decelerationDistance > 0 {
                    let decelerationProgress = (distance - (totalDistance - decelerationDistance)) / decelerationDistance
                    let easedProgress = easeOutQuad(decelerationProgress)
                    time += accelerationTime + cruisingTime + decelerationTime * easedProgress
                } else if cruisingDistance > 0 {
                    let cruisingProgress = (distance - accelerationDistance) / cruisingDistance
                    time += accelerationTime + cruisingTime * cruisingProgress
                }
                
                // Only add keyframe if this is a significant point in the journey
                if i == 0 || i == segmentCoordinates.count - 1 || i % max(1, segmentCoordinates.count / 10) == 0 {
                    let isFirstKeyFrame = i == 0
                    let isLastKeyFrame = i == segmentCoordinates.count - 1
                    
                    var heading: CLLocationDirection = 0
                    if i < segmentCoordinates.count - 1 {
                        heading = segmentCoordinates[i].heading(to: segmentCoordinates[i+1])
                    } else if i > 0 {
                        heading = segmentCoordinates[i-1].heading(to: segmentCoordinates[i])
                    } else if !keyFrames.isEmpty {
                        heading = keyFrames.last!.heading
                    }
                    
                    keyFrames.append(KeyFrame(
                        point: segmentCoordinates[i],
                        heading: heading,
                        time: time,
                        isStop: isFirstKeyFrame || isLastKeyFrame,
                        isDwelling: false
                    ))
                }
            }
        } else {
            // handle zero distance case (should be extra rare)
            let heading = keyFrames.isEmpty ? 0 : keyFrames.last!.heading
            keyFrames.append(KeyFrame(
                point: coordinates[fromIndex],
                heading: heading,
                time: endTime,
                isStop: true,
                isDwelling: false
            ))
        }
    }
    
    // https://easings.net/fr
    private static func easeInQuad(_ x: Double) -> Double {
        return x*x // we could also have used pow
    }
    
    private static func easeOutQuad(_ x: Double) -> Double {
        return 1 - (1 - x) * (1 - x)
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
                if startFrame.isDwelling && endFrame.isDwelling {
                    return startFrame.point
                }
                
                let segmentDuration = endFrame.time - startFrame.time
                let progress = (timestamp - startFrame.time) / segmentDuration
                
                if startFrame.point.latitude == endFrame.point.latitude &&
                   startFrame.point.longitude == endFrame.point.longitude {
                    return startFrame.point
                }
                
                let easedProgress: Double
                
                if startFrame.isStop && !startFrame.isDwelling {
                    easedProgress = easeInQuad(progress)
                } else if endFrame.isStop && !startFrame.isDwelling {
                    easedProgress = easeOutQuad(progress)
                } else {
                    easedProgress = progress
                }
                
                return interpolate(
                    from: startFrame.point,
                    to: endFrame.point,
                    progress: easedProgress
                )
            }
        }
        
        return keyFrames.last!.point
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
        let deltaLon = other.longitude.degreesToRadians - longitude.degreesToRadians
        let lat1 = latitude.degreesToRadians
        let lat2 = other.latitude.degreesToRadians
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let bearing = atan2(y, x).radiansToDegrees
        
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}

extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}
