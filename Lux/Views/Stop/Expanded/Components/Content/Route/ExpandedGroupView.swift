//
//  ExpandedGroupView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom

struct ExpandedGroupView: View {
    @Environment(\.colorScheme) var colorScheme
    let group: GroupedStopTime
    @Binding var animateIn: Bool
    var animation: Namespace.ID
    
    var body: some View {
        NavigationLink(destination: {
            if let tripId = group.stopTimes.first?.tripId {
                ItineraryView(tripId: tripId, fromNearby: false)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }
        }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    LinePill(line: group.routeShortName, mode: group.stopTimes.first?.mode ?? .bus)
                        .matchedGeometryEffect(id: "pill_\(group.id)", in: animation)
                    Text(group.headsign)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(colorScheme == .dark ? Color.white: Color.black)
                    Spacer()
                    HStack {
                        let displayTrack = group.stopTimes.first {
                            $0.place.track != nil || $0.place.scheduledTrack != nil
                        }?.place.track ?? group.stopTimes.first?.place.scheduledTrack ?? "inconnu"
                        
                            Text(getTrackType(displayTrack))
                                .font(.caption)
                                .foregroundStyle(Color.secondary.opacity(0.7))
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.secondary.opacity(0.6))
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(group.stopTimes.prefix(4).enumerated()), id: \.element.id) { index, stopTime in
                        DepartureTimeRow(stopTime: stopTime, animateIn: $animateIn, index: index)
                    }
                }
            }
        }
    }
}

func getTrackType(_ track: String) -> String {
    if Int(track) != nil {
        return "Voie \(track)"
    }
    else {
        return "Quai \(track)"
    }
}
