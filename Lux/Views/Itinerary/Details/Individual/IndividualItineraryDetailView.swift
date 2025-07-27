//
//  IndividualItineraryDetailView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2025.
//

import SwiftUI
import LuxCom

struct IndividualItineraryDetailView: View {
    let itinerary: Itinerary
    let isMultipleLeg: Bool
    private let mainLeg: Leg?
    private let legColor: Color
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var disruptionManager: DisruptionManager
    
    private let upcomingStops: [Place]
    private let nextStop: Place?
    
    init(itinerary: Itinerary, isMultipleLeg: Bool) {
        self.itinerary = itinerary
        self.mainLeg = itinerary.legs.first
        self.legColor = mainLeg.flatMap(getLegColor) ?? .black
        
        if let leg = itinerary.legs.first {
            self.upcomingStops = Self.calculateUpcomingStops(leg: leg)
            self.nextStop = Self.calculateNextStop(leg: leg)
        } else {
            self.upcomingStops = []
            self.nextStop = nil
        }
        self.isMultipleLeg = isMultipleLeg
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color.white
    }
    
    private static func calculateUpcomingStops(leg: Leg) -> [Place] {
        guard let intermediateStops = leg.intermediateStops else { return [] }
        
        let now = Date()
        var allStops = [leg.from]
        allStops.append(contentsOf: intermediateStops)
        allStops.append(leg.to)
        
        return allStops.filter { stop in
            let relevantTime = stop.departure ?? stop.arrival
            return relevantTime == nil || relevantTime! >= now.addingTimeInterval(-60)
        }
    }
    
    private static func calculateNextStop(leg: Leg) -> Place? {
        let now = Date()
        
        if let departureTime = leg.from.departure {
            if departureTime > now {
                return leg.from
            }
        }
        
        if let intermediateStops = leg.intermediateStops {
            for stop in intermediateStops {
                let relevantTime = stop.departure ?? stop.arrival
                if let time = relevantTime, time > now {
                    return stop
                }
            }
        }
        
        return leg.to
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let leg = mainLeg {
                    LegHeaderView(leg: leg, legColor: legColor, isSingle: !isMultipleLeg, nextStop: nextStop)
                        .padding(.horizontal, 20)
                        .padding(.top, 25)
                        .padding(.bottom, 17.5)
                    Divider()
                        .padding(.horizontal, 20)
                        .frame(minHeight: 1)
                    ScrollViewReader { proxy in
                        ScrollView {
                            if let actualName = leg.routeShortName {
                                DisruptionSectionView(disruptions: disruptionManager.disruptions(for: actualName))
                                .padding(.horizontal, 20)
                                .padding(.top, 15)
                                .padding(.bottom, -10)
                            }
                            ItinerarySheetDetailStopsContentView(
                                stops: upcomingStops,
                                legColor: legColor,
                                fromStop: leg.from,
                                toStop: leg.to,
                                isMultipleLeg: isMultipleLeg
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            Divider()
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                                .frame(minHeight: 1)
                            let itineraarySharer = ItinerarySharer()
                            ShareButtonView(itinerary: itinerary, itineraarySharer: itineraarySharer)
                        }
                    }
                }
            }
            .background(backgroundColor)
        }
    }
}
