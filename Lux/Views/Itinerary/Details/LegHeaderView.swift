//
//  LegHeaderView.swift
//  Lux
//
//  Created by Constantin Clerc on 23.07.2025.
//

import SwiftUI
import LuxCom

struct LegHeaderView: View {
    let leg: Leg
    let legColor: Color
    let isSingle: Bool
    let nextStop: Place?
    @State private var showTripIdView: Bool = false
    
    var body: some View {
        Group {
            if !isSingle, let tripId = leg.tripId {
                Button {
                    showTripIdView = true
                } label: {
                    contentView
                }
                .buttonStyle(PlainButtonStyle())
                .fullScreenCover(isPresented: $showTripIdView) {
                    ItineraryView(tripId: tripId, fromNearby: false)
                }
            } else {
                contentView
            }
        }
    }
    
    private var contentView: some View {
        HStack(alignment: .top, spacing: 10) {
            LinePill(line: leg.routeShortName ?? "",
                     mode: leg.mode,
                     agency: leg.agencyId,
                     width: 64,
                     height: 40,
                     fontSize: 19)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(legColor.opacity(0.7))
                    Text(leg.headsign ?? "")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                HStack(spacing: 4) {
                    if leg.cancelled {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)

                        Text("Course supprimée")
                            .bold()
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    else if let nextStop = nextStop {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("Prochain: \(nextStop.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
//                            .lineLimit(1)
//                            .frame(maxWidth: 250, alignment: .leading)
//                            .truncationMode(.head)
                    }
                    else {
                        Image(systemName: leg.mode.symbolName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("Montez à \(formatTime(leg.startTime))")
                            .bold()
                            .font(.caption)
                            .foregroundColor(boardingTimeColor)
                    }
                }
            }
        }
    }
    
    private var boardingTimeColor: Color {
        leg.from.punctuality(realTime: leg.realTime, cancelled: leg.cancelled).highlightColor ?? .secondary
    }
}
