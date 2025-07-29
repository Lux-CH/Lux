//
//  LuxApp.swift
//  Lux
//
//  Created by Constantin Clerc on 29.03.2025.
//

import SwiftUI
import LuxCom

@main
struct LuxApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var shortcutManager = ShortcutManager()
    @StateObject private var disruptionManager = DisruptionManager()
    @StateObject private var accentColorManager = AccentColorManager.shared
    
    @State private var showItinerarySheet: Bool = false
    @State private var showStopSheet: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var showItineraryProcessingError: Bool = false
    @State private var inputedURL: URL?
    @State private var sharedItinerary: Itinerary?
    @State private var sharedStopDetail: (String, String)?
    
    @ObservedObject var settings = Settings.shared
    
    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .preferredColorScheme(
                        getColorScheme() ?? nil
                )
                .environmentObject(locationManager)
                .environmentObject(shortcutManager)
                .environmentObject(disruptionManager)
                .tint(accentColorManager.selectedAccentColor)
                // i am fully aware this will deprecated in the future; however not putting it doesn't apply the accent everywhere; same if you only leave accentColor
                .accentColor(accentColorManager.selectedAccentColor)
                .onOpenURL { url in
                    inputedURL = url
                    if url.pathExtension == "luxtrip" {
                        showConfirmation = true
                    } else if let urlStr = inputedURL?.absoluteString, urlStr.contains("//") {
                        let components = urlStr.components(separatedBy: "//")
                        if components.count == 2 {
                            let stopId = components[0]
                            let encodedName = components[1]
                            if let name = encodedName.removingPercentEncoding {
                                self.sharedStopDetail = (stopId, name)
                                self.showStopSheet = true
                            }
                        }
                    }
                }
                .fullScreenCover(isPresented: $showItinerarySheet, onDismiss: {ItinerarySharer().cleanUp()}) {
                    if let itinerary = sharedItinerary {
                        ItineraryView(itinerary: itinerary, fromNearby: false)
                            .preferredColorScheme(
                                    getColorScheme() ?? nil
                            )
                            .environmentObject(locationManager)
                            .environmentObject(shortcutManager)
                            .environmentObject(disruptionManager)
                            .tint(accentColorManager.selectedAccentColor)
                            .accentColor(accentColorManager.selectedAccentColor)
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
                .alert("Êtes-vous sûr de vouloir ouvrir cet itinéraire ?", isPresented: $showConfirmation) {
                    Button("Ouvrir") {
                        if let url = inputedURL {
                            handleItinerary(url)
                        }
                    }
                    Button("Annuler", role: .cancel) { }
                } message: {
                    Text("Cet itinéraire vous a été partagé. Assurez-vous qu'il provient d'une source fiable.")
                }
                .alert("L'itinéraire n'a pas pu être ouvert.", isPresented: $showItineraryProcessingError) {
                    Button("OK") { }
                } message: {
                    Text("Une erreur est survenue lors de son ouverture. Assurez-vous que son contenu soit valide.")
                }
        }
    }
    
    private func handleItinerary(_ url: URL) {
        let hasSSRAccess = url.startAccessingSecurityScopedResource()
        
        defer {
            if hasSSRAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path), let size = fileAttributes[.size] as? Int64, size > 51200 {
                print("invalid file!")
                showItineraryProcessingError.toggle()
                return
            }
            let data = try Data(contentsOf: url)
            let itinerarySharer = ItinerarySharer()
            let decodedItinerary = try itinerarySharer.decode(data)
            
            guard itinerarySharer.validateItinerary(decodedItinerary) else {
                print("invalid file!")
                showItineraryProcessingError.toggle()
                return
            }
            
            DispatchQueue.main.async {
                self.sharedItinerary = decodedItinerary
                self.showItinerarySheet = true
            }
            
        } catch {
            showItineraryProcessingError.toggle()
            print(error)
        }
    }
    private func getColorScheme() -> ColorScheme? {
        if settings.autoColorScheme {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: Date())
            
            if hour >= 20 || hour < 6 {
                return .dark
            }
            else {
                return .light
            }
        }
        if settings.customScheme {
            if settings.customSchemeSelection == "dark" {
                return .dark
            }
            else {
                return .light
            }
        }
        else {
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
                vertexType: .transit))
        }
    }
}
