//
//  ArrivalMinuteView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct ArrivalMinuteView: View {
    let incomingStop: StopTime
    @Environment(\.calendar) private var calendar
    
    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        Text(displayText)
            .foregroundColor(latenessColor)
    }
    
    private var displayText: String {
        let now = Date()
        let arrival = incomingStop.place.arrival ?? now
        
        let timeDifference = calendar.dateComponents([.minute], from: now, to: arrival).minute ?? 0
        let isNextDay = !calendar.isDate(arrival, inSameDayAs: now)
        
        if abs(timeDifference) < 99 {
            return "\(timeDifference)'"
        } else {
            return "\(Self.hourFormatter.string(from: arrival))\(isNextDay ? "*" : "")"
        }
    }
    
    private var latenessColor: Color {
        let scheduledArrival = incomingStop.place.scheduledArrival ?? Date()
        let arrival = incomingStop.place.arrival ?? Date()
        
        let scheduledDifference = calendar.dateComponents([.minute], from: scheduledArrival, to: arrival).minute ?? 0
        
        if !incomingStop.realTime {
            return .primary
        } else if abs(scheduledDifference) <= 2 {
            return .green
        } else {
            return .red
        }
    }
}
