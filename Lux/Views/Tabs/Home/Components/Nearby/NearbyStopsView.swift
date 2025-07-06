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
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchResults: [SearchResult] = []
    @State private var isLoading = false
    @State private var isWaitingForLocation = false
    
    @State private var lastFetchedLocation: CLLocation? = nil
    @State private var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var backgroundRefreshTask: Task<Void, Never>? = nil
    @State private var isUserConnectedToInternet: Bool = false
    @State private var maintenanceStatus: MaintenanceStatus? = nil
    
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
                if let status = maintenanceStatus, status.isMaintenance {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "wrench.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.accentColor)

                        Text("Maintenance en cours")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(status.message)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            if let eta = status.estimatedDateOfResolution {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    Text("Résolution prévue : \(formatDate(eta))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.secondary)
                                Text("Dernière mise à jour : \(formatDate(status.dateOfUpdate))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Button("Actualiser") {
                                Task {
                                    await checkMaintenanceStatus()
                                }
                            }
                        }
                        .padding(.top, 8)

                        Spacer().frame(height: 8)
                    }
                    .padding()
                    .padding(.top, -15)
                    Spacer()
                } else {
                    Text("Aucun arrêt à proximité trouvé.")
                        .foregroundColor(.gray)
                        .padding()
                        .onAppear {
                            Task {
                                if maintenanceStatus == nil {
                                    await checkMaintenanceStatus()
                                }
                            }
                        }
                }
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
                
                if filteredResults.isEmpty {
                    if maintenanceStatus == nil {
                        await checkMaintenanceStatus()
                    }
                }
                
            } catch {
                if !(error is CancellationError) {
                    print("failed to load nerby stops!! \(error)")
                    if maintenanceStatus == nil {
                        await checkMaintenanceStatus()
                    }
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
    
    func checkMaintenanceStatus() async {
        print("server seems down. checking for maintenance.")
        let url = URL(string: "https://cclerc.ch/lux-status/status.json?t=\(Date().timeIntervalSince1970)")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let status = try JSONDecoder().decode(MaintenanceStatus.self, from: data)
            
            await MainActor.run {
                self.maintenanceStatus = status
            }
        } catch {
            print("error fetching error \(error)")
            await MainActor.run {
                self.maintenanceStatus = nil
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "fr_FR")
        
        return displayFormatter.string(from: date)
    }
}

struct MaintenanceStatus: Codable {
    let dateOfUpdate: String
    let message: String
    let estimatedDateOfResolution: String?
    let isMaintenance: Bool
}
