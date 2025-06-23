//
//  Settings.swift
//  Lux
//
//  Created by Constantin Clerc on 17.05.2025.
//

import SwiftUI


class Settings: ObservableObject, @unchecked Sendable {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @MainActor static let shared = Settings()
    
    @AppStorage("firstLaunch") var firstLaunch: Bool = true
    
    /// Shortcuts
    @AppStorage("showShortcutLabel") var showShortcutLabel: Bool = true
    @AppStorage("useTimeBasedRelevance") var useTimeBasedRelevance: Bool = true

    /// Customisation
    @AppStorage("reduceSpacerBtwnStopContent") var reduceSpacerBtwnStopContent: Bool = false
    @AppStorage("highContrastButAccurateLinePill") var highContrastButAccurateLinePill: Bool = false
    @AppStorage("showDelayInsteadOfDirectTime") var showDelayInsteadOfDirectTime: Bool = false
    @AppStorage("autoColorScheme") var autoColorScheme: Bool = false
    @AppStorage("customScheme") var customScheme: Bool = false
    @AppStorage("customSchemeSelection") var customSchemeSelection: String = ""

    /// Experimental
    @AppStorage("getPolylineWithOSRM") var getPolylineWithOSRM: Bool = false
    @AppStorage("fetchWalkingDirectionsUsingMKDirections") var fetchWalkingDirectionsUsingMKDirections: Bool = true
}
