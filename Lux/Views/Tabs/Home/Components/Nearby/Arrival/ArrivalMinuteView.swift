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
    @StateObject private var blinkManager = BlinkManager.shared
    @State private var now = Date()
    @State private var bufferTime: TimeInterval = 40.0
        
    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        Group {
            if shouldBlink {
                transportImage
            } else {
                Text(displayText)
                    .foregroundColor(latenessColor)
                    .strikethrough(incomingStop.cancelled, color: .red)
            }
        }
        .onAppear {
            bufferTime = bufferTimeForTransport()
        }
    }
    
    private var timeDifferenceInSeconds: Int {
        let arrival = incomingStop.place.departure ?? incomingStop.place.arrival ?? now
        return Int(arrival.timeIntervalSince(now))
    }
    
    private var displayText: String {
        let secondsDifference = timeDifferenceInSeconds
                
        if secondsDifference < 0 {
            let minutesAgo = Int(ceil(Double(abs(secondsDifference)) / 60.0))
            if minutesAgo <= 1 {
                return "-1'"
            } else {
                let arrival = incomingStop.place.departure ?? incomingStop.place.arrival ?? now
                let isNextDay = !calendar.isDate(arrival, inSameDayAs: now)
                return "\(Self.hourFormatter.string(from: arrival))\(isNextDay ? "*" : "")"
            }
        }
        else if secondsDifference <= 60 {
            if secondsDifference <= 30 {
                return "0'"
            } else if secondsDifference <= 45 {
                return "<1'"
            } else {
                return "1'"
            }
        } else {
            let minutes = Int(ceil(Double(secondsDifference) / 60.0))
            if minutes < 100 {
                return "\(minutes)'"
            } else {
                let arrival = incomingStop.place.departure ?? incomingStop.place.arrival ?? now
                let isNextDay = !calendar.isDate(arrival, inSameDayAs: now)
                return "\(Self.hourFormatter.string(from: arrival))\(isNextDay ? "*" : "")"
            }
        }
    }
    
    private func bufferTimeForTransport() -> TimeInterval {
        switch incomingStop.mode {
        case .rail, .highSpeedRail, .regionalRail, .regionalFastRail, .ferry:
            if let arrival = incomingStop.place.arrival,
                  let departure = incomingStop.place.departure,
               arrival != departure {
                let timeDifference = departure.timeIntervalSince(arrival)
                if timeDifference > 0 {
                    return timeDifference
                }
            }
            return 60.0
        default:
            return 40.0
        }
    }
    
    private var shouldBlink: Bool {
        let eventTime = incomingStop.place.departure ?? incomingStop.place.arrival ?? now
        let secondsUntilCleanup = Int(eventTime.addingTimeInterval(bufferTime).timeIntervalSince(now))
        
        return secondsUntilCleanup <= Int(bufferTime) && secondsUntilCleanup >= Int(-bufferTime)
    }
    
    private var latenessColor: Color {
        let scheduledArrival = incomingStop.place.scheduledDeparture ?? incomingStop.place.scheduledArrival ?? Date()
        let arrival = incomingStop.place.departure ?? incomingStop.place.arrival ?? Date()
        
        let scheduledDifference = calendar.dateComponents([.minute], from: scheduledArrival, to: arrival).minute ?? 0
        
        if incomingStop.cancelled {
            return .red
        } else if !incomingStop.realTime {
            return .primary
        } else if scheduledDifference < 2 && scheduledDifference >= -1 {
            return .green
        } else {
            return .red
        }
    }
    
    @ViewBuilder
    private var transportImage: some View {
        let systemName: String = {
            switch incomingStop.mode {
            case .tram: return "tram"
            case .ferry: return "ferry"
            case .bus: return "bus"
            case .rail, .highSpeedRail, .regionalFastRail, .regionalRail: return "tram.tunnel.fill"
            default: return "bus"
            }
        }()
        
        Image(systemName: systemName)
            .foregroundColor(latenessColor)
            .font(.system(size: 15))
            .opacity(blinkManager.isVisible ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: blinkManager.isVisible)
    }
}
