//
//  TransportationModeStyle.swift
//  Lux
//
//  Created by Constantin Clerc on 25.07.2026.
//

import Foundation
import SwiftUI
import UIKit
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

enum Punctuality {
    case cancelled
    case scheduled
    case onTime
    case early
    case late

    var color: Color {
        switch self {
        case .cancelled: return .red
        case .scheduled: return .primary
        case .onTime: return .green
        case .early: return .cyan
        case .late: return .yellow
        }
    }

    var borderColor: Color {
        switch self {
        case .cancelled: return .red
        case .scheduled: return Color(UIColor.separator)
        case .onTime, .early, .late: return color.opacity(0.5)
        }
    }

    /// Color to use where the punctuality should only stand out when it is worth signalling,
    /// leaving on-time and theoretical times in their regular styling.
    var highlightColor: Color? {
        switch self {
        case .cancelled, .early, .late: return color
        case .scheduled, .onTime: return nil
        }
    }
}

extension Place {
    /// Minutes between the scheduled and the effective time, positive when late.
    func scheduledDifference(calendar: Calendar = .current) -> Int {
        guard let scheduled = scheduledDeparture ?? scheduledArrival,
              let effective = departure ?? arrival else { return 0 }
        return calendar.dateComponents([.minute], from: scheduled, to: effective).minute ?? 0
    }

    func punctuality(realTime: Bool, cancelled: Bool = false, calendar: Calendar = .current) -> Punctuality {
        if cancelled { return .cancelled }
        guard realTime else { return .scheduled }

        let difference = scheduledDifference(calendar: calendar)
        if difference < 0 { return .early }
        if difference >= 2 { return .late }
        return .onTime
    }
}

extension StopTime {
    func punctuality(calendar: Calendar = .current) -> Punctuality {
        place.punctuality(realTime: realTime, cancelled: cancelled, calendar: calendar)
    }
}
