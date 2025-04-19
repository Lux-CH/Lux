//
//  IncomingBusView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct IncomingBusView: View {
    let group: GroupedStopTime
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    LinePill(line: group.routeShortName, mode: group.stopTimes.first?.mode ?? .bus)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Color.primary.opacity(0.3))
                    Text(group.headsign)
                        .fontWeight(.regular)
                }
                .multilineTextAlignment(.leading)
                .padding(.bottom, 3)
                
                let displayTrack = group.stopTimes.first {
                    $0.place.track != nil || $0.place.scheduledTrack != nil
                }?.place.track ?? group.stopTimes.first?.place.scheduledTrack ?? "inconnu"
                
                let transport = group.stopTimes.first?.mode.rawValue.capitalized ?? "Bus"
                
                Text("\(transport) - Quai \(displayTrack)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            VStack(alignment: .trailing) {
                if let firstStop = group.stopTimes.first {
                    ArrivalMinuteView(incomingStop: firstStop)
                }
                if group.stopTimes.count > 1 {
                    ArrivalMinuteView(incomingStop: group.stopTimes[1])
                }
            }
        }
    }
}
