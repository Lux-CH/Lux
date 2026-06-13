//
//  Settings.swift
//  Lux
//
//  Created by Constantin Clerc on 17.05.2025.
//

import SwiftUI


class Settings: ObservableObject, @unchecked Sendable {
    @MainActor static let shared = Settings()
    
    @AppStorage("firstLaunch") var firstLaunch: Bool = true
    @AppStorage("appLaunchCount") var appLaunchCount: Int = 1
    @AppStorage("dataSource") var dataSource: DataSource = .luxCom
    @AppStorage("dataSourceMode") var dataSourceMode: DataSourceMode = .auto
    
    /// Shortcuts
    @AppStorage("showShortcutLabel") var showShortcutLabel: Bool = true
    @AppStorage("useTimeBasedRelevance") var useTimeBasedRelevance: Bool = true

    /// Customisation
    @AppStorage("reduceSpacerBtwnStopContent") var reduceSpacerBtwnStopContentView: Bool = UIDevice.current.userInterfaceIdiom == .phone
    @AppStorage("highContrastButAccurateLinePill") var highContrastButAccurateLinePill: Bool = false
    @AppStorage("showDelayInsteadOfDirectTime") var showDelayInsteadOfDirectTime: Bool = false
    @AppStorage("autoColorScheme") var autoColorScheme: Bool = false
    @AppStorage("customScheme") var customScheme: Bool = false
    @AppStorage("customSchemeSelection") var customSchemeSelection: String = ""
    @AppStorage("easyOnTheEyes") var easyOnTheEyes: Bool = false
    @AppStorage("showHistory") var showHistory: Bool = true

    /// Experimental
    @AppStorage("fetchWalkingDirectionsUsingMKDirections") var fetchWalkingDirectionsUsingMKDirections: Bool = false
    @AppStorage("luxTripShareExpiryTimeH") var luxTripShareExpiryTimeH: Int = 24
    @AppStorage("crowdbackAllowed") var crowdbackAllowed: Bool = true
    @AppStorage("swisspassOnHome") var swisspassOnHome: Bool = false
    @AppStorage("showDebug") var showDebug: Bool = false

    /// Offline mode (optional on-device GTFS dataset)
    @AppStorage("offlineModeEnabled") var offlineModeEnabled: Bool = false
    @AppStorage("offlineForceOffline") var offlineForceOffline: Bool = false
    @AppStorage("offlineLastImportDate") var offlineLastImportDate: Double = 0

    var isCita: Bool { dataSource == .cita }
}

enum DataSource: String, Codable, Hashable, Sendable {
   case luxCom = "LC"
   case cita = "CTA"
}

enum DataSourceMode: String, Codable, Hashable, Sendable {
   case auto = "AUTO"
   case luxCom = "LC"
   case cita = "CTA"
}
