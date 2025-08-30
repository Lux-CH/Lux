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
    let accentColor: Color
    let fromStop: Place
    let toStop: Place
    let isMultipleLeg: Bool
    
    @State private var showAllStops = false
    
    private var displayedStops: [Place] {
        if !isMultipleLeg || showAllStops || stops.count <= 2 {
            return stops
        }
        
        return [stops.first!, stops.last!]
    }
    
    private var intermediateStopsCount: Int {
        max(0, stops.count - 2)
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            LazyVStack(spacing: 0) {
                ForEach(Array(displayedStops.enumerated()), id: \.element.stopId) { index, stop in
                    let actualIndex = getActualIndex(displayIndex: index)
                    
                    ItineraryStopTimelineRowView(
                        stop: stop,
                        legColor: legColor,
                        accentColor: accentColor,
                        isFirstStop: actualIndex == 0,
                        isLastStop: actualIndex == stops.count - 1,
                        isDepartureStop: stop.name == fromStop.name,
                        isArrivalStop: stop.name == toStop.name,
                        currentDate: timeline.date
                    )
                    .id(stop.stopId)
                    
                    if index == 0 && isMultipleLeg && stops.count > 2 {
                        IntermediateStopsButton(
                            count: intermediateStopsCount,
                            legColor: legColor,
                            isExpanded: showAllStops
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showAllStops.toggle()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getActualIndex(displayIndex: Int) -> Int {
        if showAllStops || !isMultipleLeg {
            return displayIndex
        }
        
        if displayIndex == 0 {
            return 0
        } else {
            return stops.count - 1
        }
    }
}

struct IntermediateStopsButton: View {
    let count: Int
    let legColor: Color
    let isExpanded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(legColor)
                        .frame(width: 3, height: 20)
                    
                    Rectangle()
                        .fill(legColor)
                        .frame(width: 3, height: 20)
                }
                .frame(width: 60)
                
                HStack(spacing: 8) {
                    let plural = count == 1 ? "" : "s"
                    Text("\(count) arrêt\(plural) intermédiaire\(plural)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(legColor)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(legColor)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 12)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ItineraryStopTimelineRowView: View {
    let stop: Place
    let legColor: Color
    let accentColor: Color
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
                    accentColor: accentColor,
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
                        
                        Text(parsedStopName.location.shortnameCapitalize)
                            .font(.system(size: 17, weight: fontWeight))
                            .foregroundColor(.primary)
                    }
                    
                    ItineraryStopTimeView(
                        stop: stop,
                        stopStatus: stopStatus,
                        legColor: legColor,
                        accentColor: accentColor,
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
