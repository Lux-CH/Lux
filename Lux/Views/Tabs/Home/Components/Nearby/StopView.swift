//
//  StopView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct StopView: View {
    @State var stop: SearchResult
    @State private var stopTimes: StopTimes? = nil
    @State private var isLoading = false

    var body: some View {
        VStack {
            HStack {
                HStack {
                    Image(systemName: "signpost.right")
                    Text(stop.name)
                        .fontWeight(.bold)
                }
                Spacer()
                HStack {
                    // for now this isn't automated
                    LinePill(line: "80")
                    MorePill()
                }
            }
            if isLoading {
                ProgressView("Loading departures...")
                    .padding()
            }
            else {
                if let existingStopTimes = stopTimes {
                    ForEach(existingStopTimes.stopTimes.prefix(4)) { stopTime in
                        IncomingBusView(incomingStop: stopTime)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            isLoading = true
            Task {
                defer { isLoading = false }
                do {
                    stopTimes = try await getDeparturesForStop(stopId: stop.id, numberOfEvents: 5)
                }
            }
        }
    }
}

//#Preview {
//    StopView(stopName: "Genève, Cornavin")
//}
