//
//  StopRowView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import LuxCom
import CoreLocation

// MARK: - Stop Row View
struct StopRowView: View {
    let stop: SearchResult
    let locationManager: LocationManager
    @State private var connections: [String] = []
    let isSearching: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "signpost.right")
                        .foregroundColor(.secondary)
                    
                    Text(stop.name)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                HStack {
                    if !isSearching {
                        HStack(spacing: 4) {
                            ForEach(connections.prefix(3), id: \.self) { routeName in
                                LinePill(line: routeName, mode: .bus)
                            }
                            if connections.count > 3 {
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
            }
            
            Spacer()
            HStack {
                // distance calc
                if let userLocation = locationManager.location {
                    let distance = calculateDistance(
                        userLat: userLocation.coordinate.latitude,
                        userLon: userLocation.coordinate.longitude,
                        stopLat: stop.lat,
                        stopLon: stop.lon
                    )
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(formatDistance(distance))
                            .foregroundColor(.green)
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
}
