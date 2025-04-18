//
//  NearbyStopsView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct NearbyStopsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchResults: [SearchResult] = []
    @State private var isLoading = false

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading nearby stops...")
                    .padding()
            } else if searchResults.isEmpty {
                Text("No nearby stops found.")
                    .foregroundColor(.gray)
            } else {
                ForEach(searchResults.prefix(2)) { result in
                    StopView(stop: result)
                }
            }
        }
        .onAppear {
            loadNearbyStops()
        }
    }

    private func loadNearbyStops() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                if let loc = locationManager.location?.coordinate {
                    let results = try await reverseGeocode(
                        place: (loc.latitude, loc.longitude),
                        type: .stop
                    )
                    // sometimes, some stops with empty coords are returned with reverse geocoding.
                    searchResults = results.filter { result in
                        return result.lat != 0.0 && result.lon != 0.0
                    }
                }
            } catch {
                print("Failed to load nearby stops: \(error)")
            }
        }
    }
}
