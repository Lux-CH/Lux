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
    let group: GroupedStopTime
    let viewModel: StopViewModel
    
    var body: some View {
        NavigationLink(destination: {
            let otherTripOptions = group.stopTimes.prefix(10).map { stopTime in
                TripOption(
                    id: stopTime.tripId,
                    startTime: stopTime.place.departure ?? stopTime.place.scheduledDeparture ?? stopTime.place.arrival ?? stopTime.place.scheduledArrival ?? Date()
                )
            }
            
            ItineraryView(tripId: stopTime.tripId, fromNearby: false, otherTripOptions: otherTripOptions)
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    viewModel.userSelectedLine(group.routeShortName)
                }
        }) {
            TimelineView(.periodic(from: .now, by: 5)) { context in
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        if let departure = stopTime.place.departure ?? stopTime.place.arrival,
                           let scheduledDeparture = stopTime.place.scheduledDeparture ?? stopTime.place.scheduledArrival {
                            let isNextDay = !calendar.isDate(departure, inSameDayAs: context.date)
                            
                            Text(settings.showDelayInsteadOfDirectTime ? formatTime(scheduledDeparture) : formatTime(departure))
                                .font(.system(.headline, design: .monospaced))
                                .foregroundColor(settings.showDelayInsteadOfDirectTime ? .primary : latenessColor)
                                .fontWeight(.bold)
                                .contentTransition(.numericText())
                                .strikethrough(stopTime.cancelled, color: .red)
                            
                            if isNextDay {
                                Text("*")
                                    .font(.caption2)
                                    .foregroundColor(settings.showDelayInsteadOfDirectTime ? .primary : latenessColor)
                                    .contentTransition(.numericText())
                            }
                            
                            if settings.showDelayInsteadOfDirectTime && !stopTime.cancelled && stopTime.realTime {
                                let scheduledDifference = calendar.dateComponents([.minute], from: scheduledDeparture, to: departure).minute ?? 0
                                
                                if scheduledDifference != 0 {
                                    Text("\(scheduledDifference >= 0 ? "+" : "")\(scheduledDifference)'")
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(latenessColor)
                                        .fontWeight(.bold)
                                        .contentTransition(.numericText())
                                }
                            }
                        }
                    }
                    
                    Text(relativeTime(for: stopTime.place.departure ?? stopTime.place.arrival, from: context.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(delayBorderColor, lineWidth: stopTime.cancelled ? 2 : 1)
                        )
                )
                .scaleEffect(animateIn ? 1 : 0.9)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05 + 0.1), value: animateIn)
            }
        }
        .buttonStyle(ScaleButtonStyle())
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
            return .yellow
        }
    }
    
    private var delayBorderColor: Color {
        let scheduledArrival = stopTime.place.scheduledDeparture ?? stopTime.place.scheduledArrival ?? Date()
        let arrival = stopTime.place.departure ?? stopTime.place.arrival ?? Date()
        
        let scheduledDifference = calendar.dateComponents([.minute], from: scheduledArrival, to: arrival).minute ?? 0
        
        if stopTime.cancelled {
            return .red
        } else if !stopTime.realTime {
            return Color(UIColor.separator)
        } else if scheduledDifference < 2 && scheduledDifference >= -1 {
            return .green.opacity(0.5)
        } else {
            return .yellow.opacity(0.5)
        }
    }
    
    private func relativeTime(for date: Date?, from currentTime: Date) -> String {
        guard let date = date else { return String(localized: "N/A") }
        
        let components = Calendar.current.dateComponents([.minute], from: currentTime, to: date)
        let secs = Calendar.current.dateComponents([.second], from: currentTime, to: date)
        if let minutes = components.minute {
            if minutes < 0 {
                return String(localized: "passé")
            } else if minutes == 0 {
                return String(localized: "maintenant")
            } else if minutes < 60 {
                if let sec = secs.second {
                    return String(localized: "dans \(Int(ceil(Double(sec) / 60.0))) min")
                }
                else {
                    return String(localized: "dans \(minutes) min")
                }
            } else {
                let hours = minutes / 60
                let remainingMinutes = minutes % 60
                if hours < 24 {
                    if remainingMinutes == 0 {
                        return String(localized: "dans \(hours)h")
                    } else {
                        return String(localized: "dans \(hours)h \(remainingMinutes)min")
                    }
                } else {
                    let days = hours / 24
                    let remainingHours = hours % 24
                    let plural = days > 1 ? String(localized: "s") : ""
                    var result = String(localized: "dans \(days) jour") + plural
                    if remainingHours > 0 {
                        result += " " + String(localized: "\(remainingHours)h")
                    }
                    return result
                }
            }
        }
        return String(localized: "N/A")
    }
}
