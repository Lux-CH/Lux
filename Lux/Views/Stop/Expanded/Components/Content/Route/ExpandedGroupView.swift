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
    let viewModel: StopViewModel
    @Binding var animateIn: Bool
    var animation: Namespace.ID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                LinePill(line: group.routeShortName, mode: group.stopTimes.first?.mode ?? .bus)
                    .matchedGeometryEffect(id: "pill_\(group.id)", in: animation)
                Text(group.headsign)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(colorScheme == .dark ? Color.white: Color.black)
                Spacer()
                HStack {
                    let displayTrack = group.stopTimes.first {
                        $0.place.track != nil || $0.place.scheduledTrack != nil
                    }?.place.track ?? group.stopTimes.first?.place.scheduledTrack
                    
                    if let track = displayTrack {
                        Text(getTrackType(track))
                            .font(.caption)
                            .foregroundStyle(Color.secondary.opacity(0.7))
                    }
                }
            }
            
            gridView()
        }
    }
    
    @ViewBuilder
    private func gridView() -> some View {
        let stopTimes = Array(group.stopTimes.prefix(4))
        let reorderedIndices = getReorderedIndices(for: stopTimes.count)
        
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(reorderedIndices, id: \.self) { originalIndex in
                if originalIndex < stopTimes.count {
                    DepartureTimeRow(
                        stopTime: stopTimes[originalIndex],
                        animateIn: $animateIn,
                        index: originalIndex,
                        group: group,
                        viewModel: viewModel
                    )
                }
            }
        }
    }
    
    private func getReorderedIndices(for count: Int) -> [Int] {
        switch count {
        case 1:
            return [0]
        case 2:
            return [0, 1]
        case 3:
            return [0, 2, 1]
        case 4:
            return [0, 2, 1, 3]
        default:
            return Array(0..<count)
        }
    }
}

func getTrackType(_ track: String) -> String {
    if Int(track) != nil {
        return String(localized: "Voie \(track)")
    }
    else {
        return String(localized: "Quai \(track)")
    }
}
