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
    @StateObject private var connectionService = ConnectionService.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var shortcutManager = ShortcutManager()
    @StateObject private var disruptionManager = DisruptionManager()
    @StateObject private var accentColorManager = AccentColorManager.shared
    @State private var showItinerarySheet: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var inputedURL: URL?
    @State private var sharedItinerary: Itinerary?
    @ObservedObject var settings = Settings.shared
    
    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .environmentObject(locationManager)
                .environmentObject(shortcutManager)
                .environmentObject(disruptionManager)
                .tint(accentColorManager.selectedAccentColor)
                // i am fully aware this will deprecated in the future; however not putting it doesn't apply the accent everywhere; same if you only leave accentColor
                .accentColor(accentColorManager.selectedAccentColor)
                .onOpenURL { url in
                    inputedURL = url
                    if url.pathExtension == "luxtrip" {
                        showConfirmation.toggle()
                    }
                }
                .fullScreenCover(isPresented: $showItinerarySheet) {
                    if let itinerary = sharedItinerary {
                        ItineraryView(itinerary: itinerary, fromNearby: false)
                    }
                }
                .alert(isPresented: $showConfirmation) {
                    Alert(
                        title: Text("Êtes-vous sûr de vouloir ouvrir cet itinéraire ?"),
                        message: Text("Cet itinéraire vous a été partagé. Assurez-vous qu’il provient d’une source fiable."),
                        primaryButton: .default(Text("Ouvrir").bold()) {
                            if let url = inputedURL {
                                handleItinerary(url)
                            }
                        },
                        secondaryButton: .cancel(Text("Annuler"))
                    )
                }
        }
    }
    func handleItinerary(_ url: URL) {
        let hasSSRAccess = url.startAccessingSecurityScopedResource()
        
        defer {
            if hasSSRAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path), let size = fileAttributes[.size] as? Int64, size > 51200 {
                print("invalid file!")
                return
            }
            let data = try Data(contentsOf: url)
            let decodedItinerary = try ItinerarySharer().decode(data)
            
            DispatchQueue.main.async {
                self.sharedItinerary = decodedItinerary
                self.showItinerarySheet = true
            }
            
        } catch {
            print(error)
        }
    }
}
