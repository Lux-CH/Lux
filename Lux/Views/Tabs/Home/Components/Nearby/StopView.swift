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
    
    @State private var errorMessage: String? = nil
    
    private let activeDotColor = Color.primary.opacity(0.5)
    private let inactiveDotColor = Color.secondary.opacity(0.3)
    
    @State private var refreshTimer: AnyCancellable?
    @State private var departureCheckTimer: AnyCancellable?
    
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
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            else if routeGroups.isEmpty && !isLoading {
                Text("Aucun départ à venir.")
                    .foregroundColor(.gray)
                    .padding()
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
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
                                    .simultaneousGesture(DragGesture())
                                    .contentShape(Rectangle())
                                    .zIndex(10)
                                    
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
            
            refreshTimer = Timer.publish(every: 30, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    Task {
                        await refreshDeparturesInBackground()
                    }
                }
                
            departureCheckTimer = Timer.publish(every: 5, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    checkAndHandleDepartures()
                }
        }
        .onDisappear {
            refreshTimer?.cancel()
            departureCheckTimer?.cancel()
            backgroundRefreshTask?.cancel()
        }
    }
    
    @MainActor
    private func refreshDepartures(showLoading: Bool) async {
        if showLoading { isLoading = true }
        backgroundRefreshTask?.cancel()
        
        backgroundRefreshTask = Task {
            defer {
                if showLoading {
                    self.isLoading = false
                }
            }
            
            do {
                let freshStopTimes = try await getDeparturesForStop(stopId: stop.id, numberOfEvents: 15)
                if Task.isCancelled { return }
                
                self.stopTimes = freshStopTimes
                let times = freshStopTimes.stopTimes
                if !times.isEmpty {
                    self.groupStopTimes(times)
                } else {
                    self.routeGroups = [:]
                    self.routeNames = []
                    self.currentPages = [:]
                }
            } catch {
                if !(error is CancellationError) {
                    print("failed to load departures !!!!!! \(error)")
                    self.errorMessage = error.localizedDescription
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
                    self.errorMessage = error.localizedDescription
                }
            }
            backgroundRefreshTask = nil
        }
    }
    
    @MainActor
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
        let routeGroups = Dictionary(grouping: stopTimes) { $0.routeShortName }
        
        var result: [String: [GroupedStopTime]] = [:]
        var newCurrentPages: [String: Int] = [:]
        
        var routeTiming: [String: Date] = [:]
        
        for (routeName, routeStopTimes) in routeGroups {
            let groupsByHeadsign = Dictionary(grouping: routeStopTimes) { $0.headsign ?? "" }
                .map { (headsign, times) -> GroupedStopTime in
                    let sortedTimes = times.sorted {
                        ($0.place.departure ?? Date.distantFuture) < ($1.place.departure ?? Date.distantFuture)
                    }
                    return GroupedStopTime(
                        routeShortName: routeName,
                        headsign: headsign,
                        stopTimes: sortedTimes
                    )
                }
                .sorted {
                    ($0.stopTimes.first?.place.departure ?? Date.distantFuture) <
                        ($1.stopTimes.first?.place.departure ?? Date.distantFuture)
                }
            
            result[routeName] = groupsByHeadsign
            
            newCurrentPages[routeName] = min(currentPages[routeName] ?? 0, groupsByHeadsign.count - 1)
            
            if let firstDeparture = groupsByHeadsign.first?.stopTimes.first?.place.departure {
                routeTiming[routeName] = firstDeparture
            }
        }
        
        let sortedRouteNames = routeGroups.keys.sorted { routeA, routeB in
            if let orderA = routeOrder[routeA], let orderB = routeOrder[routeB] {
                return orderA < orderB
            } else if routeOrder[routeA] != nil {
                return true
            } else if routeOrder[routeB] != nil {
                return false
            } else {
                return routeTiming[routeA] ?? Date.distantFuture < routeTiming[routeB] ?? Date.distantFuture
            }
        }
        
        if routeOrder.isEmpty {
            for (index, name) in sortedRouteNames.enumerated() {
                routeOrder[name] = index
            }
        } else {
            let maxOrder = routeOrder.values.max() ?? -1
            for (offset, name) in sortedRouteNames.filter({ routeOrder[$0] == nil }).enumerated() {
                routeOrder[name] = maxOrder + offset + 1
            }
        }
        
        self.routeNames = sortedRouteNames
        self.routeGroups = result
        self.currentPages = newCurrentPages
    }
}

