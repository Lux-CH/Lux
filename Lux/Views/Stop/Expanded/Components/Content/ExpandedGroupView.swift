//
//  ExpandedGroupView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom

struct ExpandedGroupView: View {
    let group: GroupedStopTime
    @Binding var animateIn: Bool
    var animation: Namespace.ID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                LinePill(line: group.routeShortName, mode: .bus)
                    .matchedGeometryEffect(id: "pill_\(group.routeShortName)", in: animation)
                Text(group.headsign)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }
            
            // Show multiple departure times
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(group.stopTimes.prefix(4).enumerated()), id: \.element.id) { index, stopTime in
                    DepartureTimeRow(stopTime: stopTime, animateIn: $animateIn, index: index)
                }
            }
        }
    }
}
