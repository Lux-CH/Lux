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
    let maxGroupsToShow: Int
    @State private var stopTimes: StopTimes? = nil
    @State private var routeGroups: [String: [GroupedStopTime]] = [:]
    @State private var isLoading = false
    @State private var routeNames: [String] = []
    @State private var currentPages: [String: Int] = [:]
    @State private var routeOrder: [String: Int] = [:]
    
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
//                        LinePill(line: "80")
                        MorePill()
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
                    ForEach(routeNames.prefix(maxGroupsToShow), id: \.self) { routeName in
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
                                if routeName != routeNames.prefix(maxGroupsToShow).last {
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
            
            refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
            departureCheckTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
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
            defer {
                if showLoading {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
            
            do {
                let freshStopTimes = try await getDeparturesForStop(stopId: stop.id, numberOfEvents: 15)
                if Task.isCancelled { return }
                
                DispatchQueue.main.async {
                    self.stopTimes = freshStopTimes
                    let times = freshStopTimes.stopTimes
                    if !times.isEmpty {
                        self.groupStopTimes(times)
                    } else {
                        self.routeGroups = [:]
                        self.routeNames = []
                        self.currentPages = [:]
                    }
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
                
                DispatchQueue.main.async {
                    self.stopTimes = freshStopTimes
                    let times = freshStopTimes.stopTimes
                    if !times.isEmpty {
                        self.groupStopTimes(times)
                        self.checkAndHandleDepartures()
                    } else {
                        self.routeGroups = [:]
                        self.routeNames = []
                        self.currentPages = [:]
                    }
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
        
        outerLoop: for (_, groups) in routeGroups {
            guard !groups.isEmpty else { continue }
            
            for group in groups {
                if let firstStopTime = group.stopTimes.first,
                   let arrival = firstStopTime.place.departure,
                   arrival < now {
                    Task {
                        await refreshDepartures(showLoading: false)
                    }
                    break outerLoop
                }
            }
        }
    }
    
    private func groupStopTimes(_ stopTimes: [StopTime]) {
        let groupedByRoute = Dictionary(grouping: stopTimes) { $0.routeShortName }
        
        var result: [String: [GroupedStopTime]] = [:]
        var newCurrentPages: [String: Int] = [:]
        
        var routeTiming: [String: Date] = [:]
        
        for (routeName, routeStopTimes) in groupedByRoute {
            let groupedByHeadsign = Dictionary(grouping: routeStopTimes) { $0.headsign ?? "" }
            
            let groupedStopTimes = groupedByHeadsign.map { headsign, times -> GroupedStopTime in
                return GroupedStopTime(
                    routeShortName: routeName,
                    headsign: headsign,
                    stopTimes: times.sorted { ($0.place.departure ?? Date.distantFuture) < ($1.place.departure ?? Date.distantFuture) }
                )
            }.sorted {
                ($0.stopTimes.first?.place.departure ?? Date.distantFuture) <
                    ($1.stopTimes.first?.place.departure ?? Date.distantFuture)
            }
            
            result[routeName] = groupedStopTimes
            
            if let currentPage = currentPages[routeName] {
                newCurrentPages[routeName] = min(currentPage, groupedStopTimes.count - 1)
            } else {
                newCurrentPages[routeName] = 0
            }
            
            if let firstTime = groupedStopTimes.first?.stopTimes.first?.place.departure {
                routeTiming[routeName] = firstTime
            }
        }
        
        let sortedRouteNames = groupedByRoute.keys.sorted { routeA, routeB in
            if let orderA = routeOrder[routeA], let orderB = routeOrder[routeB] {
                return orderA < orderB
            } else if routeOrder[routeA] != nil {
                return true
            } else if routeOrder[routeB] != nil {
                return false
            } else {
                let firstArrivalA = routeTiming[routeA] ?? Date.distantFuture
                let firstArrivalB = routeTiming[routeB] ?? Date.distantFuture
                return firstArrivalA < firstArrivalB
            }
        }
        
        if routeOrder.isEmpty && !sortedRouteNames.isEmpty {
            for (index, routeName) in sortedRouteNames.enumerated() {
                routeOrder[routeName] = index
            }
        }
        
        for routeName in sortedRouteNames where routeOrder[routeName] == nil {
            routeOrder[routeName] = routeOrder.values.max().map { $0 + 1 } ?? routeOrder.count
        }
        
        self.routeNames = sortedRouteNames
        self.routeGroups = result
        self.currentPages = newCurrentPages
    }
}

