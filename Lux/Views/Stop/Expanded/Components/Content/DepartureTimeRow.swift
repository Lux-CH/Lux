//
//  DepartureTimeRow.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom

struct DepartureTimeRow: View {
    let stopTime: StopTime
    @Binding var animateIn: Bool
    let index: Int
    
    var body: some View {
        HStack {
            if let departure = stopTime.place.departure {
                Text(formatTime(departure))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(stopTime.realTime ? .green : .primary)
                    .fontWeight(.medium)
                    .contentTransition(.numericText())
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func relativeTime(for date: Date?) -> String {
        guard let date = date else { return "N/A" }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.minute], from: now, to: date)
        
        if let minutes = components.minute {
            if minutes < 0 {
                return "Passé"
            } else if minutes == 0 {
                return "Maintenant"
            } else if minutes < 60 {
                return "Dans \(minutes) min"
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
