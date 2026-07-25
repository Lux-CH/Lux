//
//  TransportationModeStyle.swift
//  Lux
//
//  Created by Constantin Clerc on 25.07.2026.
//

import Foundation
import LuxCom

extension TransportationMode {
    var symbolName: String {
        switch self {
        case .tram: return "tram"
        case .ferry: return "ferry"
        default: return isRail ? "tram.tunnel.fill" : "bus"
        }
    }

    var usesSquaredPill: Bool {
        isRail || self == .ferry
    }

    var dwellTime: TimeInterval {
        switch self {
        case .bus, .tram: return 25
        case .ferry: return 50
        default: return isRail ? 50 : 30
        }
    }
}

extension StopTime {
    var displayBufferTime: TimeInterval {
        guard mode.isRail || mode == .ferry else { return 50 }

        if let arrival = place.arrival,
           let departure = place.departure,
           arrival != departure {
            let dwell = departure.timeIntervalSince(arrival)
            if dwell > 0 { return dwell }
        }

        return 60
    }
}
