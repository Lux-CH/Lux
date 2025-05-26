//
//  DepartureTimeRow.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom

struct DepartureTimeRow: View {
    @Environment(\.calendar) private var calendar
    @ObservedObject var settings = Settings.shared
    let stopTime: StopTime
    @Binding var animateIn: Bool
    let index: Int
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            HStack {
                if let departure = stopTime.place.departure, let scheduledDeparture = stopTime.place.scheduledDeparture {
                    let scheduledDifference = calendar.dateComponents([.minute], from: stopTime.place.scheduledDeparture ?? stopTime.place.scheduledArrival ?? Date(), to: stopTime.place.departure ?? stopTime.place.arrival ?? Date()).minute ?? 0
                    HStack(spacing:6) {
                        Text(settings.showDelayInsteadOfDirectTime ? formatTime(scheduledDeparture) : formatTime(departure))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(settings.showDelayInsteadOfDirectTime ? .primary : latenessColor)
                            .fontWeight(.medium)
                            .contentTransition(.numericText())
                            .strikethrough(stopTime.cancelled, color: .red)
                        if settings.showDelayInsteadOfDirectTime && !stopTime.cancelled && stopTime.realTime {
                            Text("\(scheduledDifference >= 0 ? "+" : "-")\(scheduledDifference)'")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(scheduledDifference == 0 ? .green : .red)
                                .contentTransition(.numericText())
                        }
                    }
                }
                
                Spacer()
                
                Text(relativeTime(for: stopTime.place.departure))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText())
            }
            .offset(x: animateIn ? 0 : -10)
            .opacity(animateIn ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1 + 0.1), value: animateIn)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private var latenessColor: Color {
        let scheduledArrival = stopTime.place.scheduledDeparture ?? stopTime.place.scheduledArrival ?? Date()
        let arrival = stopTime.place.departure ?? stopTime.place.arrival ?? Date()
        
        let scheduledDifference = calendar.dateComponents([.minute], from: scheduledArrival, to: arrival).minute ?? 0
        
        if stopTime.cancelled {
            return .red
        } else if !stopTime.realTime {
            return .primary
        } else if scheduledDifference < 2 && scheduledDifference >= -1 {
            return .green
        } else {
            return .red
        }
    }
    
    private func relativeTime(for date: Date?) -> String {
        guard let date = date else { return "N/A" }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.minute], from: now, to: date)
        let secs = Calendar.current.dateComponents([.second], from: now, to: date)
        if let minutes = components.minute {
            if minutes < 0 {
                return "Passé"
            } else if minutes == 0 {
                return "Maintenant"
            } else if minutes < 60 {
                if let sec = secs.second {
                    return "Dans \(Int(ceil(Double(sec) / 60.0))) min"
                }
                else {
                    return "Dans \(minutes) min"
                }
            } else {
                let hours = minutes / 60
                let remainingMinutes = minutes % 60
                if hours < 24 {
                    if remainingMinutes == 0 {
                        return "Dans \(hours)h"
                    } else {
                        return "Dans \(hours)h \(remainingMinutes)min"
                    }
                } else {
                    let days = hours / 24
                    let remainingHours = hours % 24
                    var result = "Dans \(days) jour" + (days > 1 ? "s" : "")
                    if remainingHours > 0 {
                        result += " \(remainingHours)h"
                    }
                    return result
                }
            }
        }
        return "N/A"
    }
}
