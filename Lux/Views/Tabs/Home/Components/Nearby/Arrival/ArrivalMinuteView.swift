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
    @State private var isVisible = true
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let blinkTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        Group {
            if displayText == "0'" || displayText == "-1'" {
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
            }
            // TODO: add other blinkings
            else {
                Text(displayText)
                    .foregroundColor(latenessColor)
            }
        }
        .onReceive(timer) { _ in
            self.now = Date()
        }
    }
    
    private var displayText: String {
        let arrival = incomingStop.place.departure ?? now

        let timeDifference = calendar.dateComponents([.minute], from: now, to: arrival).minute ?? 0
        let isNextDay = !calendar.isDate(arrival, inSameDayAs: now)

        if abs(timeDifference) < 99 {
            return "\(timeDifference)'"
        } else {
            return "\(Self.hourFormatter.string(from: arrival))\(isNextDay ? "*" : "")"
        }
    }

    private var latenessColor: Color {
        let scheduledArrival = incomingStop.place.scheduledDeparture ?? Date()
        let arrival = incomingStop.place.departure ?? Date()

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
            .opacity(isVisible ? 1.0 : 0.0)
            .onReceive(blinkTimer) { _ in
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.isVisible.toggle()
                }
            }
    }
}
