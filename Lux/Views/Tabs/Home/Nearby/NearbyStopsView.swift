//
//  NearbyStopsView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import Combine
import LuxCom
import LuxComHAFAS
import Network
import CoreLocation

struct NearbyStopsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var offline: OfflineManager
    @State private var isLoading = false
    @State private var isWaitingForLocation = false
    @ObservedObject var settings = Settings.shared
    @ObservedObject var progress = Progress.shared
    
    @State private var lastFetchedLocation: CLLocation? = nil
    @State private var pendingFetchLocation: CLLocation? = nil
    @State private var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var backgroundRefreshTask: Task<Void, Never>? = nil
    @State private var isUserConnectedToInternet: Bool = false
    @State private var maintenanceStatus: MaintenanceStatus? = nil
    @State private var warningMessage: WarningMessage? = nil
    @State private var showingSuggestion: Bool = false
    @State private var showSafari: Bool = false
    @State private var networkMonitor: NWPathMonitor? = nil
    
    private let significantDistance: CLLocationDistance = 100.0
    private let networkMonitorQueue = DispatchQueue(label: "NetworkMonitor")
    
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
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
            } else if progress.searchResults.isEmpty {
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
                            Button("État des serveurs") {
                                showSafari = true
                            }
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
                    Button("État des serveurs") {
                        showSafari = true
                    }
                    .foregroundColor(.accentColor)
                }
            } else {
                VStack(spacing: 8) {
                    VStack(spacing: 2.5) {
                        ForEach(Array(progress.searchResults.prefix(2).enumerated()), id: \.element.id) { index, result in
                            let isLastStop = index == min(1, progress.searchResults.count - 1)
                            ZStack {
                                StopView(stop: result, maxGroupsToShow: index == 0 ? 3 : (showingSuggestion ? 1 : 2), fromStops: false, isLastStopOverall: isLastStop)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                    }
                    
                    if offline.needsUpdate {
                        HintIndicatorView(
                            icon: "arrow.down.circle",
                            message: String(localized: "Vos horaires hors ligne datent de plus de 2 semaines. Touchez pour les mettre à jour."),
                            delay: 0.5,
                            duration: 25
                        ) {
                            showingSuggestion = false
                        }
                        .onAppear {
                            showingSuggestion = true
                        }
                        .onTapGesture {
                            offline.startImport()
                        }
                        .padding(.top, 14)
                    } else if settings.appLaunchCount < 5 && progress.numOfTimesStopViewWasOpened < 2 && !settings.firstLaunch {
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
                    } else if progress.numOfTimesTripViewWasOpened < 2 && !progress.shownTripViewSuggestion && !settings.firstLaunch {
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
                    } else if let message = warningMessage, message.show {
                        HintIndicatorView(
                            icon: message.icon,
                            message: message.message,
                            delay: 0.25,
                            duration: 10
                        ) {
                            showingSuggestion = false
                        }
                        .onAppear {
                            showingSuggestion = true
                        }
                        .padding(.top, 14)
                    }
                    else if UIDevice.current.batteryLevel <= 0.35 && UIDevice.current.batteryState != .charging && UIDevice.current.modelIdentifier == "iPhone12,1" {
                        HintIndicatorView(
                            icon: "battery.25",
                            message: "Votre batterie est faible.\nPensez à charger votre appareil avant de partir.",
                            delay: 0.25,
                            duration: 25
                        ) {
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
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: "https://lux.cronitorstatus.com")!)
                .ignoresSafeArea()
        }
        .onAppear {
            locationManager.startMonitoring()
            if UIDevice.current.modelIdentifier == "iPhone12,1" {
                UIDevice.current.isBatteryMonitoringEnabled = true
            }
            
            startNetworkMonitoring()
            Task.detached() {
                await checkMessage()
            }
            if locationManager.location == nil && !isAuthorizationNotAllowed {
                isWaitingForLocation = true
                if locationManager.authorizationStatus == .notDetermined && !settings.firstLaunch {
                    locationManager.requestLoc()
                }
            } else if progress.searchResults.isEmpty && !isAuthorizationNotAllowed {
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadNearbyStops"))) { _ in
            progress.searchResults = []
            lastFetchedLocation = nil
            maintenanceStatus = nil
            warningMessage = nil
            
            if !isAuthorizationNotAllowed && locationManager.location != nil {
                loadNearbyStops(showLoading: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            locationManager.resumeUpdates()
            
            stopNetworkMonitoring()
            startNetworkMonitoring()
            
            if !isAuthorizationNotAllowed {
                if progress.searchResults.isEmpty {
                    loadNearbyStops(showLoading: true)
                } else {
                    refreshNearbyStopsInBackground()
                }
            }
        }
        .onDisappear {
            locationManager.stopMonitoring()
            backgroundRefreshTask?.cancel()
            stopNetworkMonitoring()
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
        
        let referenceLoc = pendingFetchLocation ?? lastFetchedLocation
        guard let referenceLoc else {
            loadNearbyStops(showLoading: false)
            return
        }

        if currentLoc.distance(from: referenceLoc) >= significantDistance {
            loadNearbyStops(showLoading: false)
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
            
            pendingFetchLocation = fetchLocation
            defer {
                if showLoading { isLoading = false }
                if !Task.isCancelled {
                    backgroundRefreshTask = nil
                }
            }
            
            do {
                var results: [SearchResult] = []
                if OfflineRouter.shared.isOfflineActive {
                    results = try await LuxData.reverseGeocode(place: (loc.latitude, loc.longitude))
                }
                else if settings.dataSource == .luxCom {
                    results = try await getMapSearchResults(
                        currentLoc: (loc.latitude, loc.longitude))
                }
                else {
                    results = try await citaReverseGeocode(currentLoc: (loc.latitude, loc.longitude))
                }
                
                if Task.isCancelled { return }
                
                let filteredResults = results.filter { result in
                    return result.lat != 0.0 && result.lon != 0.0
                }
                
                self.progress.searchResults = filteredResults
                self.lastFetchedLocation = fetchLocation
                
                self.pendingFetchLocation = nil
                if filteredResults.isEmpty {
                    if maintenanceStatus == nil {
                        await checkMaintenanceStatus()
                    }
                }
                
            } catch {
                if !(error is CancellationError) {
                    self.pendingFetchLocation = nil
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
    
    private func startNetworkMonitoring() {
        guard networkMonitor == nil else { return }
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                isUserConnectedToInternet = path.status == .satisfied
            }
        }
        monitor.start(queue: networkMonitorQueue)
        networkMonitor = monitor
    }
    
    private func stopNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil
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
    
    func checkMessage() async {
        let url = URL(string: "https://cclerc.ch/lux-status/message.json?t=\(Date().timeIntervalSince1970)")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let message = try JSONDecoder().decode(WarningMessage.self, from: data)
            
            await MainActor.run {
                self.warningMessage = message
            }
        } catch {
            print("error fetching error \(error)")
            await MainActor.run {
                self.warningMessage = nil
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

struct WarningMessage: Codable {
    let message: String
    let icon: String
    let show: Bool
}

extension UIDevice {
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }
}
