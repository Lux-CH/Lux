//
//  LuxApp.swift
//  Lux
//
//  Created by Constantin Clerc on 29.03.2025.
//

import SwiftUI
import LuxCom
import TipKit

@main
struct LuxApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var shortcutManager = ShortcutManager()
    @StateObject private var disruptionManager = DisruptionManager()
    @StateObject private var accentColorManager = AccentColorManager.shared
    
    @State private var showItinerarySheet: Bool = false
    @State private var showStopSheet: Bool = false
    @State private var showTripPlaceSheet: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var showItineraryProcessingError: Bool = false
    @State private var pendingURL: URL?
    @State private var sharedItinerary: Itinerary?
    @State private var sharedStopDetail: (String, String)?
    @State private var errorMessage: String = ""
    @State private var didHandleStartupDataSource = false
    @State private var isWaitingForStartupLocation = false
    @State private var didConfigureTipKit = false
    
    @ObservedObject var settings = Settings.shared
    
    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .preferredColorScheme(getColorScheme())
                .environmentObject(locationManager)
                .environmentObject(shortcutManager)
                .environmentObject(disruptionManager)
                .tint(accentColorManager.selectedAccentColor)
                // i am fully aware this will deprecated in the future; however not putting it doesn't apply the accent everywhere; same if you only leave accentColor
                .accentColor(accentColorManager.selectedAccentColor)
                .onAppear {
                    configureDataSourceOnStartupIfNeeded()
                    configureTipKitIfNeeded()
                    if ((settings.appLaunchCount % 15) == 0) {
                        Task.detached(priority: .background) {
                            await CacheCleaner.performCleanup()
                        }
                    }
                    settings.appLaunchCount += 1
                }
                .onChange(of: locationManager.location) {
                    guard isWaitingForStartupLocation else { return }
                    guard settings.dataSourceMode == .auto else { return }
                    guard let coordinate = locationManager.location?.coordinate else { return }
                    
                    applyAutomaticDataSource(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    isWaitingForStartupLocation = false
                }
                .onChange(of: locationManager.authorizationStatus) {
                    guard isWaitingForStartupLocation else { return }
                    guard settings.dataSourceMode == .auto else { return }
                    guard locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted else { return }
                    
                    setDataSourceIfNeeded(.luxCom)
                    isWaitingForStartupLocation = false
                }
                .onChange(of: settings.dataSourceMode) {
                    applySelectedDataSourceMode()
                }
                .onOpenURL { url in
                    Task {
                        await handleIncomingURL(url)
                    }
                }
                .fullScreenCover(isPresented: $settings.firstLaunch) {
                    WelcomeView()
                        .environmentObject(locationManager)
                        .environmentObject(shortcutManager)
                        .environmentObject(disruptionManager)
                }
                .fullScreenCover(isPresented: $showItinerarySheet) {
                    if let itinerary = sharedItinerary {
                        ItineraryView(itinerary: itinerary, fromNearby: false)
                            .preferredColorScheme(getColorScheme())
                            .environmentObject(locationManager)
                            .environmentObject(shortcutManager)
                            .environmentObject(disruptionManager)
                            .tint(accentColorManager.selectedAccentColor)
                            .accentColor(accentColorManager.selectedAccentColor)
                    } else {
                        ProgressView("Chargement de l'itinéraire...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .foregroundStyle(.primary)
                    }
                }
                .fullScreenCover(isPresented: $showStopSheet) {
                    stopView
                        .environmentObject(locationManager)
                        .environmentObject(shortcutManager)
                        .environmentObject(disruptionManager)
                        .tint(accentColorManager.selectedAccentColor)
                        .accentColor(accentColorManager.selectedAccentColor)
                }
                .fullScreenCover(isPresented: $showTripPlaceSheet) {
                    if let place = sharedStopDetail {
                        TripsSearchView(
                            initialSearchResult: SearchResult(type: .stop, tokens: [], name: place.1, id: place.0, lat: 0.0, lon: 0.0, areas: [], score: 0.0),
                            initialTargetField: .to
                        )
                        .environmentObject(locationManager)
                        .environmentObject(shortcutManager)
                        .environmentObject(disruptionManager)
                        .tint(accentColorManager.selectedAccentColor)
                        .accentColor(accentColorManager.selectedAccentColor)
                    }
                }
                .alert("Êtes-vous sûr de vouloir ouvrir cet itinéraire ?", isPresented: $showConfirmation) {
                    Button("Ouvrir") {
                        if let url = pendingURL {
                            Task {
                                await handleConfirmedItinerary(url)
                            }
                        }
                    }
                    Button("Annuler", role: .cancel) {
                        pendingURL = nil
                    }
                } message: {
                    Text("Cet itinéraire vous a été partagé. Assurez-vous qu'il provient d'une source fiable.")
                }
                .alert("L'itinéraire n'a pas pu être ouvert.", isPresented: $showItineraryProcessingError) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage.isEmpty ? "Une erreur est survenue lors de son ouverture. Il est possible que le lien ait expiré." : errorMessage)
                }
        }
    }
    
    private func configureDataSourceOnStartupIfNeeded() {
        guard !didHandleStartupDataSource else { return }
        didHandleStartupDataSource = true
        applySelectedDataSourceMode()
    }

    private func configureTipKitIfNeeded() {
        guard !didConfigureTipKit else { return }

        do {
            try Tips.configure([.displayFrequency(.immediate)])
            didConfigureTipKit = true
        } catch {
            print(error)
        }
    }
    
    private func applySelectedDataSourceMode() {
        switch settings.dataSourceMode {
        case .auto:
            if let coordinate = locationManager.location?.coordinate {
                applyAutomaticDataSource(latitude: coordinate.latitude, longitude: coordinate.longitude)
                isWaitingForStartupLocation = false
            } else {
                // Auto defaults to LuxCom outside Geneva (or while location is unavailable).
                setDataSourceIfNeeded(.luxCom)
                isWaitingForStartupLocation = true
            }
        case .luxCom:
            isWaitingForStartupLocation = false
            setDataSourceIfNeeded(.luxCom)
        case .cita:
            isWaitingForStartupLocation = false
            setDataSourceIfNeeded(.cita)
        }
    }
    
    private func applyAutomaticDataSource(latitude: Double, longitude: Double) {
        let shouldUseCita = isInsideCitaBounds(latitude: latitude, longitude: longitude)
        setDataSourceIfNeeded(shouldUseCita ? .cita : .luxCom)
    }
    
    private func setDataSourceIfNeeded(_ dataSource: DataSource) {
        guard settings.dataSource != dataSource else { return }
        settings.dataSource = dataSource
        NotificationCenter.default.post(name: NSNotification.Name("ReloadNearbyStops"), object: nil)
    }
    
    private func isInsideCitaBounds(latitude: Double, longitude: Double) -> Bool {
        let minLongitude = 5.88593
        let minLatitude = 46.09657
        let maxLongitude = 6.31577
        let maxLatitude = 46.31119
        
        return longitude >= minLongitude &&
               longitude <= maxLongitude &&
               latitude >= minLatitude &&
               latitude <= maxLatitude
    }
    
    @MainActor
    private func handleIncomingURL(_ url: URL) async {
        let result = await URLHandler.process(url)
        
        switch result {
        case .confirmationRequired(let url):
            pendingURL = url
            showConfirmation = true
            
        case .stopPlace(let name, let stopId):
            sharedStopDetail = (stopId, name)
            showItinerarySheet = false
            showTripPlaceSheet = false
            showStopSheet = false
            showTripPlaceSheet = true
            
        case .stopDetail(let stopId, let name):
            sharedStopDetail = (stopId, name)
            showItinerarySheet = false
            showTripPlaceSheet = false
            showStopSheet = false
            showStopSheet = true
            
        case .itinerary(let itinerary):
            sharedItinerary = itinerary
            showItinerarySheet = false
            showTripPlaceSheet = false
            showStopSheet = false
            showItinerarySheet = true
            
        case .error(let error):
            errorMessage = error.localizedDescription
            showItineraryProcessingError = true
        }
    }
    
    @MainActor
    private func handleConfirmedItinerary(_ url: URL) async {
        let result = await URLHandler.handleConfirmedItinerary(url)
        
        switch result {
        case .itinerary(let itinerary):
            sharedItinerary = itinerary
            showItinerarySheet = false
            showTripPlaceSheet = false
            showStopSheet = false
            showItinerarySheet = true
            
        case .error(let error):
            errorMessage = error.localizedDescription
            showItineraryProcessingError = true
            
        default:
            errorMessage = "Une erreur est survenue."
            showItineraryProcessingError = true
        }
        
        pendingURL = nil
    }
    
    private func getColorScheme() -> ColorScheme? {
        if settings.autoColorScheme {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: Date())
            
            if hour >= 20 || hour < 6 {
                return .dark
            } else {
                return .light
            }
        }
        if settings.customScheme {
            if settings.customSchemeSelection == "dark" {
                return .dark
            } else {
                return .light
            }
        } else {
            return nil
        }
    }
    
    @ViewBuilder
    private var stopView: some View {
        if let (stopId, name) = sharedStopDetail {
            ItineraryStopDetailView(stop: Place(
                name: name,
                stopId: stopId,
                lat: 0.0,
                lon: 0.0,
                level: 0,
                arrival: nil,
                departure: nil,
                scheduledArrival: nil,
                scheduledDeparture: nil,
                scheduledTrack: nil,
                track: nil,
                vertexType: .transit), isFromMultiple: true, forceLC: true)
        }
    }
}
