//
//  StopWidgetBundle.swift
//  StopWidget
//
//  Created by Constantin Clerc on 29.06.2025.
//

import WidgetKit
import SwiftUI
import AppIntents

@main
struct StopWidgetBundle: WidgetBundle {
    var body: some Widget {
        StopWidget()
    }
}


struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Actualiser les départs"
    
    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
