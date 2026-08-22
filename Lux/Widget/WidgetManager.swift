//
//  WidgetManager.swift
//  Lux
//
//  Created by Constantin Clerc on 29.06.2025.
//

import Foundation
import WidgetKit
import LuxCom

class WidgetManager {
    static let shared = WidgetManager()
    private let groupIdentifier = "group.ch.cclerc.luxapp.shared"

    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: groupIdentifier)
    }

    func setSelectedStopId(_ stopId: String) {
        sharedDefaults?.set(stopId, forKey: "selectedStopId")
        for key in ["selectedStopName", "selectedStopLat", "selectedStopLon", "selectedStopServesRail"] {
            sharedDefaults?.removeObject(forKey: key)
        }
        sharedDefaults?.synchronize()
    }

    func setSelectedStop(_ stop: SearchResult) {
        sharedDefaults?.set(stop.id, forKey: "selectedStopId")
        sharedDefaults?.set(stop.name, forKey: "selectedStopName")
        sharedDefaults?.set(stop.lat, forKey: "selectedStopLat")
        sharedDefaults?.set(stop.lon, forKey: "selectedStopLon")
        sharedDefaults?.set(stop.servesMainlineRail, forKey: "selectedStopServesRail")
        sharedDefaults?.synchronize()
    }

    func getSelectedStopId() -> String? {
        return sharedDefaults?.string(forKey: "selectedStopId")
    }
    
    func requestWidgetRefresh() {
        WidgetCenter.shared.reloadTimelines(ofKind: "StopWidget")
    }
}
