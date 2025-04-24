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
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.secondary.opacity(0.6))
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
