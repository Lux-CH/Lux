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
                    if url.pathExtension == "luxtrip" {
                        handleItinerary(url)
                    }
                }
                .fullScreenCover(isPresented: $showItinerarySheet) {
                    if let itinerary = sharedItinerary {
                        ItineraryView(itinerary: itinerary, fromNearby: false)
                    }
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
