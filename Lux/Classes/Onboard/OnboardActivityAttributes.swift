//
//  OnboardActivityAttributes.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import Foundation
import ActivityKit

struct OnboardActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case walking, waiting, riding, arrived
        }

        var phase: Phase
        var title: String
        var subtitle: String
        var symbolName: String

        var line: String?
        var lineMode: String?
        var lineAgency: String?
        var lineColorHex: String?
        var headsign: String?

        var targetDate: Date?
        var countdownMinutes: Int?
        var arrivalDate: Date
        var delayMinutes: Int?

        var stopsRemaining: Int?
        var totalStops: Int?
        var passedStops: Int?
        var fromName: String?
        var toName: String?
        var progress: Double
        var segmentStart: Date?
        var segmentEnd: Date?

        var distanceMeters: Double?

        var vehicleIsLive: Bool
        var vehicleDistanceMeters: Double?

        var isUrgent: Bool
    }

    var destinationName: String
}
