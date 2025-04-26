//
//  ItineraryDetailSheet.swift
//  Lux
//
//  Created by Constantin Clerc on 24.04.2025.
//
//  https://swiftwithmajid.com/2022/05/18/mastering-timelineview-in-swiftui/

import SwiftUI
import LuxCom

struct ItineraryDetailSheet: View {
    @State var itinerary: Itinerary?
    var body: some View {
        if let itinerary = itinerary {
            if itinerary.legs.count == 1 {
                IndividualItineraryDetailView(itinerary: itinerary)
            }
        } else {
            Text("Itinéraire indisponible")
        }
    }
}

struct IndividualItineraryDetailView: View {
    @State var itinerary: Itinerary
    @State private var mainLeg: Leg?
    @State private var legColor: Color = .black
    
    init(itinerary: Itinerary) {
        self.itinerary = itinerary
        _mainLeg = State(initialValue: itinerary.legs.first)
    }
    
    var body: some View {
        if let leg = mainLeg {
            VStack {
                HStack {
                    LinePill(line: leg.routeShortName ?? "", mode: leg.mode, width: 55, height: 35, fontSize: 17)
                    VStack {
                        HStack {
                            Image(systemName: "arrow.right")
                                .foregroundStyle(Color.primary.opacity(0.3))
                            Text(leg.headsign ?? "")
                                .font(.footnote)
                        }
                        Text(currentStop(leg: leg)?.name ?? "")
                    }
                }
                .padding(.vertical, 15)
                .padding(.horizontal, 15)
            }
            .background(Color(.secondarySystemFill).opacity(0.5))
            .padding(.top, 15)
            .onAppear {
                if let leg = mainLeg {
                    legColor = getLegColor(leg)
                }
            }
            
            TimelineView(.periodic(from: .now, by: 5)) { _ in
                ScrollView {
                    VStack(alignment: .leading) {
                        if let intermediateStops = leg.intermediateStops {
                            let now = Date()
                            let upcomingStops = intermediateStops.filter {
                                $0.departure != nil && $0.departure! > now
                            }
                            
                            ForEach(upcomingStops, id: \.self) { stop in
                                NavigationLink(destination: createExpandedStopView(stop: stop)) {
                                    HStack(spacing: 0) {
                                        VStack(spacing: 0) {
                                            Circle()
                                                .fill(legColor)
                                                .frame(width: 10, height: 10)
                                            Rectangle()
                                                .fill(Color.gray)
                                                .frame(width: 2)
                                        }
                                        .frame(width: 20)
                                        VStack {
                                            Text(stop.name)
                                                .padding(.vertical, 5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func currentStop(leg: Leg) -> Place? {
        let now = Date()
        
        var allStops = [leg.from]
        
        if let intermediateStops = leg.intermediateStops {
            allStops.append(contentsOf: intermediateStops)
        }
        
        allStops.append(leg.to)
        
        let upcomingStops = allStops.filter { $0.departure != nil && $0.departure! > now }
        
        return upcomingStops.min(by: { $0.departure! < $1.departure! })
    }
    private func createExpandedStopView(stop: Place) -> some View {
        let searchResult = SearchResult(
            type: .stop,
            tokens: [[]],
            name: stop.name,
            id: stop.stopId ?? "",
            lat: stop.lat,
            lon: stop.lon,
            level: Double(stop.level),
            street: nil,
            houseNumber: nil,
            zip: nil,
            areas: [],
            score: 1.0
        )
        return ExpandedStopView(viewModel: StopViewModel(stop: searchResult, fromStops: true), maxGroupsToShow: 50)
            .background(Color(.secondarySystemBackground))
    }
}
