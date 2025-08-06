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
    @ObservedObject var settings = Settings.shared
    @ObservedObject var progress = Progress.shared
    
    @State private var lastFetchedLocation: CLLocation? = nil
    @State private var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var backgroundRefreshTask: Task<Void, Never>? = nil
    @State private var isUserConnectedToInternet: Bool = false
    @State private var maintenanceStatus: MaintenanceStatus? = nil
    @State private var showingSuggestion: Bool = false
    
    private let significantDistance: CLLocationDistance = 100.0
    
    var isAuthorizationNotAllowed: Bool {
        return locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted
    }
    
    var body: some View {
        VStack {
            if isAuthorizationNotAllowed{
                Spacer()
                VStack(alignment: .center) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 64))
                    
                    Text("Accès à la localisation refusé")
                        .padding(.top)
                    
                    Text("Pour afficher les arrêts à proximité, veuillez autoriser l'accès à votre position dans les réglages.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding([.bottom, .horizontal])
                        .padding(.top, 5)
                    
                    Button("Ouvrir les Réglages") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 35)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 35)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                }
                .padding(.top, -15)
                Spacer()
            } else if isWaitingForLocation {
                ProgressView("En attente de votre position...")
                    .padding()
            } else if !isUserConnectedToInternet {
                Spacer()
                VStack(alignment: .center) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 64))
                    Text("Aucune connexion à Internet.")
                        .padding(.top)
                        .padding(.horizontal)
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
                            Link("État des serveurs", destination: URL(string: "https://lux.cronitorstatus.com")!)
                                .foregroundColor(.accentColor)
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
                    Link("État des serveurs", destination: URL(string: "https://lux.cronitorstatus.com")!)
                        .foregroundColor(.accentColor)
                }
            } else {
                VStack(spacing: 8) {
                    VStack(spacing: 2.5) {
                        ForEach(Array(searchResults.prefix(2).enumerated()), id: \.element.id) { index, result in
                            ZStack {
                                StopView(stop: result, maxGroupsToShow: index == 0 ? 3 : (showingSuggestion ? 1 : 2), fromStops: false)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                    }
                    
                    if settings.appLaunchCount < 5 {
                        HintIndicatorView(
                            icon: "chevron.compact.up",
                            message: String(localized: "Glissez vers le haut pour voir plus d'arrêts à proximité"),
                            delay: 2,
                            duration: 35
                        ) {
                            showingSuggestion = false
                        }
                        .onAppear {
                            showingSuggestion = true
                        }
                        .padding(.top, 14)
                    } else if progress.numOfTimesTripViewWasOpened <= 5 && !progress.shownTripViewSuggestion {
                        HintIndicatorView(
                            icon: "chevron.compact.down",
                            message: String(localized: "Glissez vers le bas pour planifier un itinéraire ou obtenir des directions"),
                            delay: 2,
                            duration: 35
                        ) {
                            progress.shownTripViewSuggestion = true
                            showingSuggestion = false
                        }
                        .onAppear {
                            showingSuggestion = true
                        }
                        .padding(.top, 14)
                    }
                }
            }
        }
        .onAppear {
            monitorNetwork()
            if locationManager.location == nil && !isAuthorizationNotAllowed {
                isWaitingForLocation = true
            } else if searchResults.isEmpty && !isAuthorizationNotAllowed {
                loadNearbyStops(showLoading: true)
            } else if !isAuthorizationNotAllowed {
                checkLocationAndRefresh()
            }
        }
        .onChange(of: locationManager.location) { oldValue, newValue in
            if isWaitingForLocation && newValue != nil {
                isWaitingForLocation = false
                loadNearbyStops(showLoading: true)
            } else if !isAuthorizationNotAllowed {
                checkLocationAndRefresh()
            }
        }
        .onChange(of: locationManager.authorizationStatus) {
            if !isAuthorizationNotAllowed {
                locationManager.requestLoc()
                if locationManager.location != nil {
                    loadNearbyStops(showLoading: true)
                }
            }
        }
        .onReceive(refreshTimer) { _ in
            guard !isAuthorizationNotAllowed else { return }
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
        guard !isAuthorizationNotAllowed else { return }
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
        guard !isAuthorizationNotAllowed else { return }
        
        if showLoading { isLoading = true }
        backgroundRefreshTask?.cancel()
        
        backgroundRefreshTask = Task {
            guard let loc = locationManager.location?.coordinate else {
                if showLoading { isLoading = false }
                if !isAuthorizationNotAllowed {
                    isWaitingForLocation = true
                }
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
        guard !isAuthorizationNotAllowed else { return }
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
