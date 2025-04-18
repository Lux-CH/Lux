//
//  StopView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct StopView: View {
    @State var stop: SearchResult
    @State private var stopTimes: StopTimes? = nil
    @State private var routeGroups: [String: [GroupedStopTime]] = [:]
    @State private var isLoading = false
    @State private var routeNames: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    HStack {
                        Image(systemName: "signpost.right")
                        Text(stop.name)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    HStack {
                        // for now this isn't automated
                        LinePill(line: "80")
//                        MorePill()
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 12)
                .padding(.top, 25)
                Divider()
                    .padding(.bottom, 0)
            }
            if isLoading {
                ProgressView("Loading departures...")
                    .padding()
            }
            else if routeGroups.isEmpty {
                Text("No upcoming departures")
                    .foregroundColor(.gray)
                    .padding()
            }
            else {
                VStack(spacing: 0) {
                    ForEach(routeNames.prefix(2), id: \.self) { routeName in
                        if let groups = routeGroups[routeName], !groups.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                TabView {
                                    ForEach(groups) { group in
                                        IncomingBusView(group: group)
                                            .padding(.horizontal)
                                    }
                                }
                                .frame(height: 70)
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            isLoading = true
            Task {
                defer { isLoading = false }
                do {
                    stopTimes = try await getDeparturesForStop(stopId: stop.id, numberOfEvents: 15)
                    if let times = stopTimes?.stopTimes {
                        groupStopTimes(times)
                    }
                }
                catch {
                    print("Failed to load departures: \(error)")
                }
            }
        }
    }
    
    private func groupStopTimes(_ stopTimes: [StopTime]) {
        let groupedByRoute = Dictionary(grouping: stopTimes) { $0.routeShortName }
        
        var result: [String: [GroupedStopTime]] = [:]
        
        for (routeName, routeStopTimes) in groupedByRoute {
            let groupedByHeadsign = Dictionary(grouping: routeStopTimes) { $0.headsign ?? "" }
            
            let groupedStopTimes = groupedByHeadsign.map { headsign, times -> GroupedStopTime in
                return GroupedStopTime(
                    routeShortName: routeName,
                    headsign: headsign,
                    stopTimes: times.sorted { ($0.place.arrival ?? Date()) < ($1.place.arrival ?? Date()) }
                )
            }.sorted { $0.headsign < $1.headsign }
            
            result[routeName] = groupedStopTimes
        }
        
        routeNames = groupedByRoute.keys.sorted()
        
        routeGroups = result
    }
}

//#Preview {
//    StopView(stopName: "Genève, Cornavin")
//}
