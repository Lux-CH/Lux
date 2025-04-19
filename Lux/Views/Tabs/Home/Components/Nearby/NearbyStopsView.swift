//
//  NearbyStopsView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom
import CoreLocation

struct NearbyStopsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchResults: [SearchResult] = []
    @State private var isLoading = false

    @State private var lastFetchedLocation: CLLocation? = nil
    @State private var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var backgroundRefreshTask: Task<Void, Never>? = nil

    private let significantDistance: CLLocationDistance = 100.0

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Chargement des arrêts à proximité...")
                    .padding()
            } else if searchResults.isEmpty {
                Text("Aucun arrêt à proximité trouvé.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(searchResults.prefix(2)) { result in
                    ZStack {
                        StopView(stop: result, maxGroupsToShow: 3, fromStops: false)
                       }
                       .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            if searchResults.isEmpty {
                loadNearbyStops(showLoading: true)
            } else {
                checkLocationAndRefresh()
            }
        }
        .onChange(of: locationManager.location) {
             checkLocationAndRefresh()
        }
        .onReceive(refreshTimer) { _ in
             guard let currentLoc = locationManager.location, let lastLoc = lastFetchedLocation else {
                 refreshNearbyStopsInBackground()
                 return
             }
             if currentLoc.distance(from: lastLoc) < significantDistance {
                 refreshNearbyStopsInBackground()
             }
        }
        .onDisappear {
             backgroundRefreshTask?.cancel()
        }
    }

    private func checkLocationAndRefresh() {
        guard let currentLoc = locationManager.location else { return }

        if let lastLoc = lastFetchedLocation {
            let distance = currentLoc.distance(from: lastLoc)
            if distance >= significantDistance {
                refreshNearbyStopsInBackground()
            }
        } else {
            refreshNearbyStopsInBackground()
        }
    }

    private func loadNearbyStops(showLoading: Bool) {
        if showLoading { isLoading = true }
        backgroundRefreshTask?.cancel()

        backgroundRefreshTask = Task {
            guard let loc = locationManager.location?.coordinate else {
                if showLoading { isLoading = false }
                print("loc not available for loading stops..:(")
                return
            }

            let fetchLocation = locationManager.location

            defer {
                if showLoading { isLoading = false }
                if !Task.isCancelled {
                    backgroundRefreshTask = nil
                }
            }

            do {
                let results = try await reverseGeocode(
                    place: (loc.latitude, loc.longitude),
                    type: .stop
                )
                if Task.isCancelled { return }

                let filteredResults = results.filter { result in
                    return result.lat != 0.0 && result.lon != 0.0
                }

                self.searchResults = filteredResults
                self.lastFetchedLocation = fetchLocation

            } catch {
                 if !(error is CancellationError) {
                     print("failed to load nerby stops!! \(error)")
                 }
            }
        }
    }

    private func refreshNearbyStopsInBackground() {
        guard backgroundRefreshTask == nil || backgroundRefreshTask?.isCancelled == true else {
            return
        }
        loadNearbyStops(showLoading: false)
    }
}
