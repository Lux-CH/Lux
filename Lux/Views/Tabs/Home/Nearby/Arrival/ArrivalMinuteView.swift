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
    let shouldAutoRefresh: Bool
    @StateObject private var blinkManager = BlinkManager.shared
    @State private var now = Date()
    @State private var bufferTime: TimeInterval = 50.0
    @State private var previousTimeDifferenceInSeconds: Int?
    
    private var refreshIdentity: String {
        let event = incomingStop.place.departure ?? incomingStop.place.arrival
        let scheduled = incomingStop.place.scheduledDeparture ?? incomingStop.place.scheduledArrival
        return [
            incomingStop.tripId,
            String(describing: incomingStop.mode),
            String(event?.timeIntervalSince1970 ?? 0),
            String(scheduled?.timeIntervalSince1970 ?? 0),
            incomingStop.cancelled ? "1" : "0",
            incomingStop.realTime ? "1" : "0"
        ].joined(separator: "|")
    }
        
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
                    .contentTransition(.numericText(countsDown: shouldCountDown))
                    .animation(.snappy, value: displayText)
            }
        }
        .onAppear {
            blinkManager.startBlinking()
            bufferTime = bufferTimeForTransport()
            previousTimeDifferenceInSeconds = timeDifferenceInSeconds
        }
        .onDisappear {
            blinkManager.stopBlinking()
        }
        .onChange(of: timeDifferenceInSeconds) { oldValue, _ in
            previousTimeDifferenceInSeconds = oldValue
        }
        .onChange(of: refreshIdentity) {
            now = Date()
            bufferTime = bufferTimeForTransport()
            previousTimeDifferenceInSeconds = timeDifferenceInSeconds
        }
        .task {
            guard shouldAutoRefresh else { return }
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(5))
            }
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

    private var shouldCountDown: Bool {
        guard let previousTimeDifferenceInSeconds else { return true }
        return timeDifferenceInSeconds <= previousTimeDifferenceInSeconds
    }
    
    private func bufferTimeForTransport() -> TimeInterval {
        incomingStop.displayBufferTime
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
            return .yellow
        }
    }
    
    @ViewBuilder
    private var transportImage: some View {
        Image(systemName: incomingStop.mode.symbolName)
            .foregroundColor(latenessColor)
            .font(.system(size: 15))
            .opacity(blinkManager.isVisible ? 1.0 : 0.0)
            .scaleEffect(blinkManager.isVisible ? 1.0 : 0.88)
            .animation(.easeInOut(duration: 0.35), value: blinkManager.isVisible)
    }
}
