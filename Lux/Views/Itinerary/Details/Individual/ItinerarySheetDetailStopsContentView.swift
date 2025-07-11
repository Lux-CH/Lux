//
//  ItinerarySheetDetailStopsContentView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2025.
//

import SwiftUI
import LuxCom

struct ItinerarySheetDetailStopsContentView: View {
    let stops: [Place]
    let legColor: Color
    let fromStop: Place
    let toStop: Place
    let isMultipleLeg: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Prochains arrêts")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(stops.count) arrêts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
            
            if stops.isEmpty {
                ContentUnavailableView {
                    Label("Aucun arrêt prévu", systemImage: "flag.checkered")
                } description: {
                    Text("Plus d'arrêts prévus sur cette ligne.")
                }
                .padding()
            } else {
                ItineraryStopTimelineView(
                    stops: stops,
                    legColor: legColor,
                    fromStop: fromStop,
                    toStop: toStop,
                    isMultipleLeg: isMultipleLeg
                )
                .padding(.top, 4)
            }
        }
    }
}
