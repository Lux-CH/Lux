//
//  ItineraryStopTimelineView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2025.
//

import SwiftUI
import LuxCom

struct ItineraryStopTimelineView: View {
    let stops: [Place]
    let legColor: Color
    let fromStop: Place
    let toStop: Place
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { timeline in
            LazyVStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.element.stopId) { index, stop in
                    ItineraryStopTimelineRowView(
                        stop: stop,
                        legColor: legColor,
                        isFirstStop: index == 0,
                        isLastStop: index == stops.count - 1,
                        isDepartureStop: stop.name == fromStop.name,
                        isArrivalStop: stop.name == toStop.name,
                        currentDate: timeline.date
                    )
                    .id(stop.stopId)
                }
            }
        }
    }
}

struct ItineraryStopTimelineRowView: View {
    let stop: Place
    let legColor: Color
    let isFirstStop: Bool
    let isLastStop: Bool
    let isDepartureStop: Bool
    let isArrivalStop: Bool
    let currentDate: Date
    @State private var showingStopDetail = false
    
    private var stopStatus: StopStatus {
        calculateStopStatus(stop: stop, currentDate: currentDate)
    }
    
    private var parsedStopName: (city: String, location: String) {
        let components = stop.name.components(separatedBy: ",")
        let city = components.first?.trimmingCharacters(in: .whitespaces) ?? stop.name
        let location = components.count > 1 ? components[1].trimmingCharacters(in: .whitespaces) : ""
        return (city, location)
    }
    
    private var shouldUseNormalDisplay: Bool {
        parsedStopName.location.isEmpty
    }
    // idk what to add here, thx michail for suggestions
    private static let genericLocationTerms: Set<String> = ["centre", "gare", "place", "douane", "gare cornavin", "p+r"]

    private var isCityReleavant: Bool {
        Self.genericLocationTerms.contains(parsedStopName.location.lowercased())
    }
    
    var body: some View {
        Button {
            showingStopDetail = true
        } label: {
            HStack(alignment: .center, spacing: 0) {
                TimelineIndicatorView(
                    legColor: legColor,
                    isFirstStop: isFirstStop,
                    isLastStop: isLastStop,
                    isDepartureStop: isDepartureStop,
                    isArrivalStop: isArrivalStop,
                    isCurrentStop: stopStatus.isCurrentStop,
                )
                .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    let fontWeight: Font.Weight = stopStatus.isCurrentStop ? .bold : .medium
                    
                    if shouldUseNormalDisplay {
                        Text(stop.name)
                            .font(.system(size: 17, weight: fontWeight))
                            .foregroundColor(.primary)
                    } else {
                        Text(parsedStopName.city)
                            .font(.system(size: 11, weight: isCityReleavant ? .heavy : fontWeight))
                            .foregroundColor(.secondary)
                        
                        Text(parsedStopName.location.capitalized)
                            .font(.system(size: 17, weight: fontWeight))
                            .foregroundColor(.primary)
                    }
                    
                    ItineraryStopTimeView(
                        stop: stop,
                        stopStatus: stopStatus,
                        legColor: legColor,
                        isDepartureStop: isDepartureStop,
                        isArrivalStop: isArrivalStop
                    )
                }
                .padding(.vertical, 16)
                
                Spacer()
                HStack {
                    if let track = stop.track {
                        Text(getTrackType(track))
                            .font(.caption)
                            .foregroundStyle(Color.secondary.opacity(0.7))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(stopStatus.isCurrentStop ?
//                      (colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5).opacity(0.5)) :
//                        Color.clear)
//                .padding(.horizontal, 8)
//        )
        .fullScreenCover(isPresented: $showingStopDetail) {
            ItineraryStopDetailView(stop: stop)
        }
    }
}
