//
//  WidgetManager.swift
//  Lux
//
//  Created by Constantin Clerc on 29.06.2025.
//

import Foundation
import WidgetKit

class WidgetManager {
    static let shared = WidgetManager()
    private let groupIdentifier = "group.ch.lmetral.lux.shareddata"
    
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: groupIdentifier)
    }
        
    // MARK: - Stop ID Management
    func setSelectedStopId(_ stopId: String) {
        sharedDefaults?.set(stopId, forKey: "selectedStopId")
        sharedDefaults?.synchronize()
    }
    
    func getSelectedStopId() -> String? {
        return sharedDefaults?.string(forKey: "selectedStopId")
    }
    
    func requestWidgetRefresh() {
        WidgetCenter.shared.reloadTimelines(ofKind: "StopWidget")
    }
}
