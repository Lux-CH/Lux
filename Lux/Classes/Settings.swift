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
    @AppStorage("showModern") var showModern: Bool = true
    @AppStorage("showShortcutLabel") var showShortcutLabel: Bool = true
    @AppStorage("getPolylineWithOSRM") var getPolylineWithOSRM: Bool = false
}
