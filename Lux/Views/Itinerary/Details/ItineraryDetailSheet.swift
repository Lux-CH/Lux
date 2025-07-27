//
//  ItineraryDetailSheet.swift
//  Lux
//
//  Created by Constantin Clerc on 24.04.2025.
//
//  https://swiftwithmajid.com/2022/05/18/mastering-timelineview-in-swiftui/

import SwiftUI
import LuxCom

struct ItineraryDetailSheet: View {
    let viewModel: ItineraryViewModel
    let isSingle: Bool
    
    var body: some View {
        if let itinerary = viewModel.itinerary {
            if isSingle {
                IndividualItineraryDetailView(itinerary: itinerary, isMultipleLeg: false)
            } else {
                MultipleItineraryDetailView(itinerary: itinerary, viewModel: viewModel)
            }
        } else {
            ContentUnavailableView {
                Label("Itinéraire indisponible", systemImage: "map.fill")
            } description: {
                Text("Les informations de l'itinéraire ne sont pas disponibles pour le moment.")
            }
        }
    }
}

struct StopStatus {
    let isCurrentStop: Bool
    let timeUntil: String
}

func calculateStopStatus(stop: Place, currentDate: Date) -> StopStatus {
    let preArrivalWindow: TimeInterval = 60
    let postArrivalWindow: TimeInterval = 60
    let preDepartureWindow: TimeInterval = 60
    let postDepartureWindow: TimeInterval = 60
    
    let now = currentDate
    
    var isCurrentStop = false
    
    if let arrival = stop.arrival, let departure = stop.departure {
        if now >= arrival && now <= departure {
            isCurrentStop = true
        } else if now >= arrival.addingTimeInterval(-preArrivalWindow) &&
                    now <= departure.addingTimeInterval(postDepartureWindow) {
            isCurrentStop = true
        }
    }
    else if let departure = stop.departure {
        isCurrentStop = now >= departure.addingTimeInterval(-preDepartureWindow) &&
        now <= departure.addingTimeInterval(postDepartureWindow)
    }
    else if let arrival = stop.arrival {
        isCurrentStop = now >= arrival.addingTimeInterval(-preArrivalWindow) &&
        now <= arrival.addingTimeInterval(postArrivalWindow)
    }
    
    return StopStatus(isCurrentStop: isCurrentStop, timeUntil: calculateTimeUntilReachingStop(for: stop, now: now, isCurrentStop: isCurrentStop))
}

func calculateTimeUntilReachingStop(for stop: Place, now: Date, isCurrentStop: Bool) -> String {
    guard let relevantTime = stop.departure ?? stop.arrival else {
        return ""
    }
    
    let secondsDifference = Int(relevantTime.timeIntervalSince(now))
    
    if secondsDifference <= 0 {
        return isCurrentStop ? "Maintenant" : ""
    }
    
    if secondsDifference < 60 {
        return "<1 min"
    }
    
    let minutes = Int(ceil(Double(secondsDifference) / 60.0))
    
    if minutes < 100 {
        return "\(minutes) min"
    }
    
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    
    if remainingMinutes == 0 {
        return "\(hours) h"
    } else {
        return "\(hours) h \(remainingMinutes) min"
    }
}

func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
