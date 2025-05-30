//
//  LuxApp.swift
//  Lux
//
//  Created by Constantin Clerc on 29.03.2025.
//

import SwiftUI

@main
struct LuxApp: App {
    @StateObject private var connectionService = ConnectionService.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var shortcutManager = ShortcutManager()
    @StateObject private var disruptionManager = DisruptionManager()
    @StateObject private var accentColorManager = AccentColorManager.shared
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
        }
    }
}
