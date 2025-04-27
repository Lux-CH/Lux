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
    @State private var now = Date()
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        Group {
            if shouldBlink {
                switch incomingStop.mode {
                case .tram:
                    transportImage(systemName: "tram")
                case .ferry:
                    transportImage(systemName: "ferry")
                case .bus:
                    transportImage(systemName: "bus")
                case .rail, .highSpeedRail, .regionalFastRail, .regionalRail:
                    transportImage(systemName: "tram.tunnel.fill")
                default:
                    transportImage(systemName: "bus")
                }
            } else {
                Text(displayText)
                    .foregroundColor(latenessColor)
            }
        }
        .onReceive(timer) { _ in
            self.now = Date()
        }
    }
    
    private var timeDifferenceInSeconds: Int {
        let arrival = incomingStop.place.departure ?? incomingStop.place.arrival ?? now
        return Int(arrival.timeIntervalSince(now))
    }
    
    private var displayText: String {
        let secondsDifference = timeDifferenceInSeconds
        let arrival = incomingStop.place.departure ?? incomingStop.place.arrival ?? now
        
        let isNextDay = !calendar.isDate(arrival, inSameDayAs: now)
        
        if secondsDifference <= 60 {
            if secondsDifference <= 30 {
                return "0'"
            } else {
                return "<1'"
            }
        } else {
            let minutes = Int(ceil(Double(secondsDifference) / 60.0))
            if minutes < 100 {
                return "\(minutes)'"
            } else {
                return "\(Self.hourFormatter.string(from: arrival))\(isNextDay ? "*" : "")"
            }
        }
    }
    
    private var shouldBlink: Bool {
        switch incomingStop.mode {
        case .rail, .highSpeedRail, .regionalRail, .regionalFastRail, .ferry:
            let arrival = incomingStop.place.arrival ?? incomingStop.place.scheduledArrival
            let departure = incomingStop.place.departure ?? incomingStop.place.scheduledDeparture
            
            if arrival != departure {
                if let arrival = arrival, let departure = departure {
                    let now = Date()
                    return now >= arrival && now <= departure
                } else {
                    return false
                }
            } else {
                let secondsDiff = timeDifferenceInSeconds
                return secondsDiff <= 50 && secondsDiff >= -50
            }
            
        default:
            let secondsDiff = timeDifferenceInSeconds
            return secondsDiff <= 20 && secondsDiff >= -20
        }
    }
    
    private var isVisibleNow: Bool {
        return Int(Date().timeIntervalSince1970) % 2 == 0
    }
    
    private var latenessColor: Color {
        let scheduledArrival = incomingStop.place.scheduledDeparture ?? incomingStop.place.scheduledArrival ?? Date()
        let arrival = incomingStop.place.departure ?? incomingStop.place.arrival ?? Date()
        
        let scheduledDifference = calendar.dateComponents([.minute], from: scheduledArrival, to: arrival).minute ?? 0
        
        if !incomingStop.realTime {
            return .primary
        } else if scheduledDifference <= 2 && scheduledDifference >= -1 {
            return .green
        } else {
            return .red
        }
    }
    
    func transportImage(systemName: String) -> some View {
        Image(systemName: systemName)
            .foregroundColor(latenessColor)
            .font(.system(size: 15))
            .opacity(isVisibleNow ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: isVisibleNow)
    }
}
