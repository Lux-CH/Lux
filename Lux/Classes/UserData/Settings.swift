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

    /// Experimental
    @AppStorage("fetchWalkingDirectionsUsingMKDirections") var fetchWalkingDirectionsUsingMKDirections: Bool = true
    @AppStorage("luxTripShareExpiryTimeH") var luxTripShareExpiryTimeH: Int = 24
    @AppStorage("crowdbackAllowed") var crowdbackAllowed: Bool = true
    @AppStorage("swisspassOnHome") var swisspassOnHome: Bool = false
}
