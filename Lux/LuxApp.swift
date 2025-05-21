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
    @ObservedObject var settings = Settings.shared
    
    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .environmentObject(locationManager)
                .environmentObject(shortcutManager)
        }
    }
}
