//
//  GroupedStopTime.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import Foundation
import LuxCom

struct GroupedStopTime: Identifiable {
    let id = UUID()
    let routeShortName: String
    let headsign: String
    let stopTimes: [StopTime]
    
    init(routeShortName: String, headsign: String, stopTimes: [StopTime]) {
        self.routeShortName = routeShortName
        self.headsign = headsign
        self.stopTimes = stopTimes
    }
}