//
//  ItineraryStopTimeView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2025.
//

import SwiftUI
import LuxCom

struct ItineraryStopTimeView: View {
    let stop: Place
    let stopStatus: StopStatus
    let legColor: Color
    let accentColor: Color
    let isDepartureStop: Bool
    let isArrivalStop: Bool
    let isRealTime: Bool
    let isCancelled: Bool
    @Environment(\.calendar) private var calendar
    @ObservedObject private var settings = Settings.shared
    
    private var punctuality: Punctuality {
        stop.punctuality(realTime: isRealTime, cancelled: isCancelled, calendar: calendar)
    }
    
    private var scheduledDifference: Int {
        stop.scheduledDifference(calendar: calendar)
    }
    
    private var showsDelay: Bool {
        settings.showDelayInsteadOfDirectTime && isRealTime && !isCancelled && scheduledDifference != 0
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let time = stop.departure ?? stop.arrival {
                let scheduled = stop.scheduledDeparture ?? stop.scheduledArrival
                let displayedTime = settings.showDelayInsteadOfDirectTime ? (scheduled ?? time) : time
                
                Text(formatTime(displayedTime))
                    .font(.subheadline)
                    .foregroundColor(settings.showDelayInsteadOfDirectTime ? .secondary : (punctuality.highlightColor ?? .secondary))
                    .strikethrough(isCancelled, color: .red)
                
                if showsDelay {
                    Text("\(scheduledDifference >= 0 ? "+" : "")\(scheduledDifference)'")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(punctuality.color)
                }
                
                if isCancelled {
                    Text("Supprimé")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                } else if !stopStatus.timeUntil.isEmpty && time < Date().addingTimeInterval(10800) {
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(stopStatus.timeUntil)
                        .font(.subheadline)
                        .foregroundColor(stopStatus.isCurrentStop ? accentColor : legColor)
                        .fontWeight(stopStatus.isCurrentStop ? .semibold : .regular)
                }
            }
            
            StopTypeLabel(
                isDepartureStop: isDepartureStop,
                isArrivalStop: isArrivalStop,
            )
        }
    }
}
