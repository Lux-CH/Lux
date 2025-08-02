//
//  StopRowView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import LuxCom
import CoreLocation

struct StopRowView: View {
    let stop: SearchResult
    let locationManager: LocationManager
    @State private var connections: [String] = []
    @State private var relativeAngle: Double = 0
    let isSearching: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "signpost.right")
                        .foregroundColor(.secondary)
                    
                    Text(stop.name)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                }
                HStack {
                    if !isSearching {
                        HStack(spacing: 4) {
                            ForEach(connections.prefix(5), id: \.self) { routeName in
                                LinePill(line: routeName, mode: .bus)
                            }
                            if connections.count > 5 {
                                MorePill()
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .onAppear {
                if !isSearching {
                    ConnectionService.shared.getConnections(for: stop.id) { results in
                        connections = results
                    }
                }
                updateRelativeAngle()
            }
            
            Spacer()
            HStack {
                if let userLocation = locationManager.location {
                    let distance = calculateDistance(
                        userLat: userLocation.coordinate.latitude,
                        userLon: userLocation.coordinate.longitude,
                        stopLat: stop.lat,
                        stopLon: stop.lon
                    )
                    HStack {
                        Image(systemName: isSearching ? "location.fill" : "location.north.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(relativeAngle))
                        Text(formatDistance(distance))
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
        .background(Color.clear)
        .onReceive(locationManager.$heading) { _ in
            updateRelativeAngle()
        }
    }
    
    private func calculateDistance(userLat: Double, userLon: Double, stopLat: Double, stopLon: Double) -> Double {
        let userLocation = CLLocation(latitude: userLat, longitude: userLon)
        let stopLocation = CLLocation(latitude: stopLat, longitude: stopLon)
        return userLocation.distance(from: stopLocation)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            let km = distance / 1000
            return "\(Int(km))km"
        } else {
            return "\(Int(distance))m"
        }
    }
    
    private func calculateRelativeAngle(userLat: Double, userLon: Double, stopLat: Double, stopLon: Double, deviceHeading: Double) -> Double {
        let lat1 = userLat * .pi / 180
        let lat2 = stopLat * .pi / 180
        let deltaLon = (stopLon - userLon) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        let normalizedBearing = bearing >= 0 ? bearing : bearing + 360
        
        let relativeAngle = normalizedBearing - deviceHeading
        return relativeAngle >= 0 ? relativeAngle : relativeAngle + 360
    }
    
    private func updateRelativeAngle() {
        guard let userLocation = locationManager.location,
              let heading = locationManager.heading, !isSearching else { return }
        
        let deviceHeading = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading

        relativeAngle = calculateRelativeAngle(
            userLat: userLocation.coordinate.latitude,
            userLon: userLocation.coordinate.longitude,
            stopLat: stop.lat,
            stopLon: stop.lon,
            deviceHeading: deviceHeading
        )
    }
}
