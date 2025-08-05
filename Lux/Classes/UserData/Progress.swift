//
//  Progress.swift
//  Lux
//
//  Created by Constantin Clerc on 06.08.2025.
//

import SwiftUI

class Progress: ObservableObject, @unchecked Sendable {
    @MainActor static let shared = Progress()
    
    @AppStorage("progress_numOfTimesStopViewWasOpened") var numOfTimesStopViewWasOpened: Int = 0
    @AppStorage("progress_numOfTimesTripViewWasOpened") var numOfTimesTripViewWasOpened: Int = 0
}
