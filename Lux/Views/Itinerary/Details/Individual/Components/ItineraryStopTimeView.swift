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
    
    var body: some View {
        HStack(spacing: 8) {
            if let time = stop.departure ?? stop.arrival {
                Text(formatTime(time))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !stopStatus.timeUntil.isEmpty && time < Date().addingTimeInterval(10800) {
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
