//
//  IncomingBus.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct IncomingBusView: View {
    @State var incomingStop: StopTime
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    LinePill(line: incomingStop.routeShortName)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Color.primary.opacity(0.3))
                    Text(incomingStop.headsign ?? "")
                        .fontWeight(.regular)
                }
                .multilineTextAlignment(.leading)
                
                Text("\(incomingStop.mode.rawValue.capitalized) - Quai \(incomingStop.place.track ?? incomingStop.place.scheduledTrack ?? "Inconnu")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            ArrivalMinuteView(incomingStop: incomingStop)
        }
    }
}
