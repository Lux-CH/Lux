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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Stop name with icon
                HStack(spacing: 8) {
                    Image(systemName: "signpost.right")
                        .foregroundColor(.secondary)
                    
                    Text(stop.name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Distance calculation
                if let userLocation = locationManager.location {
                    let distance = calculateDistance(
                        userLat: userLocation.coordinate.latitude,
                        userLon: userLocation.coordinate.longitude,
                        stopLat: stop.lat,
                        stopLon: stop.lon
                    )
                    Text(formatDistance(distance))
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
                
                // Line pills
                HStack(spacing: 4) {
                    LinePill(line: "80", mode: .bus)
                }
            }
            .padding(.vertical, 12)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
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
