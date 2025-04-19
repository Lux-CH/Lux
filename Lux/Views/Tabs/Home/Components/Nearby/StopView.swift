//
//  StopView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom
import Combine

struct StopView: View {
    @State var stop: SearchResult
    @State private var stopTimes: StopTimes? = nil
    @State private var routeGroups: [String: [GroupedStopTime]] = [:]
    @State private var isLoading = false
    @State private var routeNames: [String] = []
    @State private var currentPages: [String: Int] = [:]
    private let activeDotColor = Color.primary.opacity(0.5)
    private let inactiveDotColor = Color.secondary.opacity(0.3)
    
    @State private var refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var departureCheckTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var backgroundRefreshTask: Task<Void, Never>? = nil
    
    
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
                .padding(.horizontal, 25)
                .padding(.bottom, 12)
                .padding(.top, 20)
                Divider()
                    .padding(.bottom, 0)
            }
            .background {
                MaskedImageView()
                    .edgesIgnoringSafeArea(.all)
            }
            if isLoading {
                ProgressView("Chargement des départs...")
                    .padding()
            }
            else if routeGroups.isEmpty && !isLoading {
                Text("Aucun départ à venir.")
                    .foregroundColor(.gray)
                    .padding()
            }
            else {
                VStack(spacing: 0) {
                    ForEach(routeNames.prefix(2), id: \.self) { routeName in
                        if let groups = routeGroups[routeName], !groups.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ZStack(alignment: .bottom) {
                                    TabView(selection: Binding(
                                        get: { currentPages[routeName] ?? 0 },
                                        set: { currentPages[routeName] = $0 }
                                    )) {
                                        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                            if !group.stopTimes.isEmpty {
                                                IncomingBusView(group: group)
                                                    .padding(.horizontal)
                                                    .tag(index)
                                            }
                                        }
                                    }
                                    .frame(height: 70)
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    
                                    if groups.count > 1 {
                                        let currentPage = currentPages[routeName] ?? 0
                                        HStack(spacing: 6) {
                                            ForEach(0..<min(groups.count, 10), id: \.self) { index in
                                                Circle()
                                                    .frame(width: 5, height: 5)
                                                    .foregroundColor(index == currentPage ? activeDotColor : inactiveDotColor)
                                            }
                                        }
                                        .padding(.bottom, 5)
                                    }
                                }
                                if routeName != routeNames.prefix(2).last {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if stopTimes == nil {
                isLoading = true
                Task {
                    await refreshDepartures(showLoading: true)
                }
            } else {
                Task {
                    await refreshDeparturesInBackground()
                }
            }
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await refreshDeparturesInBackground()
            }
        }
        .onReceive(departureCheckTimer) { _ in
            checkAndHandleDepartures()
        }
        .onDisappear {
            refreshTimer.upstream.connect().cancel()
            departureCheckTimer.upstream.connect().cancel()
            backgroundRefreshTask?.cancel()
            cancellables.forEach { $0.cancel() }
        }
    }
    
    private func refreshDepartures(showLoading: Bool) async {
        if showLoading { isLoading = true }
        backgroundRefreshTask?.cancel()
        
        backgroundRefreshTask = Task {
            defer { if showLoading { isLoading = false } }
            do {
                let freshStopTimes = try await getDeparturesForStop(stopId: stop.id, numberOfEvents: 15)
                if Task.isCancelled { return }
                self.stopTimes = freshStopTimes
                let times = freshStopTimes.stopTimes
                if !times.isEmpty {
                    groupStopTimes(times)
                } else {
                    self.routeGroups = [:]
                    self.routeNames = []
                    self.currentPages = [:]
                }
            } catch {
                if !(error is CancellationError) {
                    print("failed to load departures !!!!!! \(error)")
                }
            }
        }
        await backgroundRefreshTask?.value
    }
    
    private func refreshDeparturesInBackground() async {
        guard backgroundRefreshTask == nil || backgroundRefreshTask?.isCancelled == true else {
            return
        }
        
        backgroundRefreshTask = Task {
            do {
                let freshStopTimes = try await getDeparturesForStop(stopId: stop.id, numberOfEvents: 15)
                if Task.isCancelled { return }
                self.stopTimes = freshStopTimes
                let times = freshStopTimes.stopTimes
                if !times.isEmpty {
                    groupStopTimes(times)
                    checkAndHandleDepartures()
                } else {
                    self.routeGroups = [:]
                    self.routeNames = []
                    self.currentPages = [:]
                }
            } catch {
                if !(error is CancellationError) {
                    print("failed to load \(error)")
                }
            }
            backgroundRefreshTask = nil
        }
    }
    
    private func checkAndHandleDepartures() {
        let now = Date()
        var needsRefresh = false
        let calendar = Calendar.current
        
        for routeName in routeNames.prefix(2) {
            guard let groups = routeGroups[routeName], !groups.isEmpty else { continue }
            let currentPage = currentPages[routeName] ?? 0
            
            guard currentPage < groups.count else {
                currentPages[routeName] = 0
                continue
            }
            
            let currentGroup = groups[currentPage]
            guard let firstStopTime = currentGroup.stopTimes.first,
                  let arrival = firstStopTime.place.arrival else { continue }
            
            if arrival < now {
                let timeDifference = calendar.dateComponents([.minute], from: arrival, to: now).minute ?? 0
                if timeDifference < 1 {
                    needsRefresh = true
                    currentPages[routeName] = 0
                }
            }
        }
        
        if needsRefresh {
            Task {
                await refreshDeparturesInBackground()
            }
        }
    }
    
    private func groupStopTimes(_ stopTimes: [StopTime]) {
        let groupedByRoute = Dictionary(grouping: stopTimes) { $0.routeShortName }
        
        var result: [String: [GroupedStopTime]] = [:]
        var newCurrentPages: [String: Int] = [:]
        
        for (routeName, routeStopTimes) in groupedByRoute {
            let groupedByHeadsign = Dictionary(grouping: routeStopTimes) { $0.headsign ?? "" }
            
            let groupedStopTimes = groupedByHeadsign.map { headsign, times -> GroupedStopTime in
                return GroupedStopTime(
                    routeShortName: routeName,
                    headsign: headsign,
                    stopTimes: times.sorted { ($0.place.arrival ?? Date.distantFuture) < ($1.place.arrival ?? Date.distantFuture) }
                )
            }.sorted {
                ($0.stopTimes.first?.place.arrival ?? Date.distantFuture) <
                    ($1.stopTimes.first?.place.arrival ?? Date.distantFuture)
            }
            
            result[routeName] = groupedStopTimes
            newCurrentPages[routeName] = 0
        }
        
        let sortedRouteNames = groupedByRoute.keys.sorted { routeA, routeB in
            let firstArrivalA = result[routeA]?.first?.stopTimes.first?.place.arrival ?? Date.distantFuture
            let firstArrivalB = result[routeB]?.first?.stopTimes.first?.place.arrival ?? Date.distantFuture
            return firstArrivalA < firstArrivalB
        }
        
        self.routeNames = sortedRouteNames
        self.routeGroups = result
        self.currentPages = newCurrentPages
    }
}

