//
//  ItinerarySheetDetailStopsContentView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2025.
//

import SwiftUI
import LuxCom

struct ItinerarySheetDetailStopsContentView: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    @ObservedObject var viewModel: ItineraryViewModel
    let stops: [Place]
    let legColor: Color
    let fromStop: Place
    let toStop: Place
    let duration: Int
    let isMultipleLeg: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(isMultipleLeg ? "Arrêts" : "Prochains arrêts")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if isMultipleLeg {
                    Text("\(duration/60)min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
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
                    viewModel: viewModel,
                    stops: stops,
                    legColor: legColor,
                    accentColor: accentColorManager.selectedAccentColor,
                    fromStop: fromStop,
                    toStop: toStop,
                    isMultipleLeg: isMultipleLeg
                )
                .padding(.top, 4)
            }
        }
    }
}
