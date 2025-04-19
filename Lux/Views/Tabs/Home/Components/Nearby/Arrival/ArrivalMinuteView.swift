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

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        Text(displayText)
            .foregroundColor(latenessColor)
            .onReceive(timer) { _ in
                self.now = Date()
            }
    }
    
    private var displayText: String {
        let arrival = incomingStop.place.departure ?? now

        let timeDifference = calendar.dateComponents([.minute], from: now, to: arrival).minute ?? 0
        let isNextDay = !calendar.isDate(arrival, inSameDayAs: now)

        if timeDifference == 0 {
            let secondsDifference = calendar.dateComponents([.second], from: now, to: arrival).second ?? 0
            if secondsDifference >= 0 {
                return "~\(secondsDifference)s"
            } else {
                 return "0'"
            }
        } else if abs(timeDifference) < 99 {
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
}
