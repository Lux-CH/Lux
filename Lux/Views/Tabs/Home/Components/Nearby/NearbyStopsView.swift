//
//  NearbyStopsView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom
import Network
import CoreLocation

struct NearbyStopsView: View {
    var onStopTap: () -> Void
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchResults: [SearchResult] = []
    @State private var isLoading = false
    @State private var isWaitingForLocation = false
    
    @State private var lastFetchedLocation: CLLocation? = nil
    @State private var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var backgroundRefreshTask: Task<Void, Never>? = nil
    @State private var isUserConnectedToInternet: Bool = false
    
    private let significantDistance: CLLocationDistance = 100.0
    
    var body: some View {
        VStack {
            if isWaitingForLocation {
                ProgressView("En attente de votre position...")
                    .padding()
            } else if !isUserConnectedToInternet {
                Spacer()
                VStack(alignment: .center) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 64))
                    Text("Aucune connexion à Internet.")
                        .padding(.top)
                    Text("Vérifiez vos données mobile ou votre connexion Wi-Fi et réessayez.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.bottom)
                }
                .padding(.top, -15)
                Spacer()
            } else if isLoading {
                ProgressView("Chargement des arrêts à proximité...")
                    .padding()
            } else if searchResults.isEmpty {
                Text("Aucun arrêt à proximité trouvé.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 2.5) {
                    ForEach(searchResults.prefix(2)) { result in
                        let maxGroups = (searchResults.firstIndex(where: { $0.id == result.id }) == 1) ? 2 : 3
                        
                        ZStack {
                            StopView(stop: result, maxGroupsToShow: maxGroups, fromStops: false)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Divider()
                        .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            monitorNetwork()
            if locationManager.location == nil {
                isWaitingForLocation = true
            } else if searchResults.isEmpty {
                loadNearbyStops(showLoading: true)
            } else {
                checkLocationAndRefresh()
            }
        }
        .onChange(of: locationManager.location) { oldValue, newValue in
            if isWaitingForLocation && newValue != nil {
                isWaitingForLocation = false
                loadNearbyStops(showLoading: true)
            } else {
                checkLocationAndRefresh()
            }
        }
        .onReceive(refreshTimer) { _ in
            guard let currentLoc = locationManager.location, let lastLoc = lastFetchedLocation else {
                if locationManager.location != nil {
                    refreshNearbyStopsInBackground()
                }
                return
            }
            if currentLoc.distance(from: lastLoc) < significantDistance {
                refreshNearbyStopsInBackground()
            }
        }
        .onDisappear {
            backgroundRefreshTask?.cancel()
            isWaitingForLocation = false
        }
    }
    
    private func checkLocationAndRefresh() {
        guard let currentLoc = locationManager.location else {
            isWaitingForLocation = true
            return
        }
        
        isWaitingForLocation = false
        
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
                isWaitingForLocation = true
                print("loc not available for loading stops..:(")
                return
            }
            
            isWaitingForLocation = false
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
    
    private func monitorNetwork() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                isUserConnectedToInternet = path.status == .satisfied
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
}
