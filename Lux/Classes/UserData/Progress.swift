//
//  Progress.swift
//  Lux
//
//  Created by Constantin Clerc on 06.08.2025.
//

import SwiftUI
import LuxCom
import CoreLocation

class Progress: ObservableObject, @unchecked Sendable {
    @MainActor static let shared = Progress()
    
    // counts
    @AppStorage("progress_numOfTimesStopViewWasOpened") var numOfTimesStopViewWasOpened: Int = 0
    @AppStorage("progress_numOfTimesTripViewWasOpened") var numOfTimesTripViewWasOpened: Int = 0
    
    // tips
    @AppStorage("tip_shownTripViewSuggestion") var shownTripViewSuggestion: Bool = false
    @Published var searchResults: [SearchResult] = []
}
