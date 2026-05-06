//
//  GroupedStopTime.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import Foundation
import LuxCom

struct GroupedStopTime: Identifiable {
    var id: String { "\(routeShortName)|\(headsign)" }
    let routeShortName: String
    let headsign: String
    let stopTimes: [StopTime]
}
