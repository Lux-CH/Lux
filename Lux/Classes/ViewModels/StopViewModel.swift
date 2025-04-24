//
//  StopViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import SwiftUI
import LuxCom
import Combine

class StopViewModel: ObservableObject {
    @Published var stopTimes: StopTimes?
    @Published var routeGroups: [String: [GroupedStopTime]] = [:]
    @Published var connections: [String] = []
    @Published var isLoading = false
    @Published var routeNames: [String] = []
    @Published var currentPages: [String: Int] = [:]
    @Published var errorMessage: String?
    
    let stop: SearchResult
    
    private var routeOrder: [String: Int] = [:]
    private var refreshTimer: AnyCancellable?
    private var departureCheckTimer: AnyCancellable?
    private var backgroundRefreshTask: Task<Void, Never>?
    private var fromStops: Bool
    private var currentTime: Date = Date()
    
    init(stop: SearchResult, fromStops: Bool) {
        self.stop = stop
        self.fromStops = fromStops
        loadConnections()
    }
    
    private func loadConnections() {
        ConnectionService.shared.getConnections(for: stop.id) { [weak self] connections in
            guard let self = self else { return }
            self.connections = connections
        }
    }
    
    func startMonitoring() {
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
        
        if !fromStops {
            refreshTimer = Timer.publish(every: 7.5, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    Task {
                        await self?.refreshDeparturesInBackground()
                    }
                }
            
            departureCheckTimer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.checkAndHandleDepartures()
                    }
                }
        }
    }
    
    func stopMonitoring() {
        refreshTimer?.cancel()
        departureCheckTimer?.cancel()
        backgroundRefreshTask?.cancel()
    }
    
    @MainActor
    func refreshDepartures(showLoading: Bool) async {
        await refreshDepartures(forTime: currentTime, showLoading: showLoading)
    }
    
    @MainActor
    func refreshDepartures(forTime time: Date, showLoading: Bool) async {
        if showLoading { isLoading = true }
        backgroundRefreshTask?.cancel()
        currentTime = time
        
        backgroundRefreshTask = Task {
            defer {
                if showLoading {
                    self.isLoading = false
                }
            }
            
            do {
                let freshStopTimes = try await getDeparturesForStop(
                    stopId: stop.id,
                    time: time,
                    numberOfEvents: fromStops ? 100 : 50
                )
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
    
    @MainActor
    func loadPaginatedDepartures(cursor: String) async {
        isLoading = true
        backgroundRefreshTask?.cancel()
        
        backgroundRefreshTask = Task {
            defer {
                self.isLoading = false
            }
            
            do {
                let freshStopTimes = try await getDeparturesForStop(
                    stopId: stop.id,
                    time: currentTime,
                    numberOfEvents: fromStops ? 100 : 50,
                    pageCursor: cursor
                )
                if Task.isCancelled { return }
                
                self.stopTimes = freshStopTimes
                let times = freshStopTimes.stopTimes
                if !times.isEmpty {
                    self.groupStopTimes(times)
                } else {
                    if self.routeGroups.isEmpty {
                        self.routeGroups = [:]
                        self.routeNames = []
                        self.currentPages = [:]
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    print("Failed to load paginated departures: \(error)")
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
                let freshStopTimes = try await getDeparturesForStop(
                    stopId: stop.id,
                    time: currentTime,
                    numberOfEvents: fromStops ? 100 : 50
                )
                if Task.isCancelled { return }
                
                await MainActor.run {
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
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            backgroundRefreshTask = nil
        }
    }
    
    private func bufferTimeForTransport(_ stopTime: StopTime) -> TimeInterval {
        switch stopTime.mode {
        case .rail, .highSpeedRail, .regionalRail, .regionalFastRail:
            return 50.0
        default:
            return 20.0
        }
    }
    
    @MainActor
    func checkAndHandleDepartures() {
        if fromStops {
            return
        }
        
        let now = Date()
        var needsRefresh = false

        for routeName in routeNames {
            guard var groups = routeGroups[routeName], !groups.isEmpty else { continue }
            
            var groupsModified = false
            
            for groupIndex in 0..<groups.count {
                let group = groups[groupIndex]
                
                let filteredStopTimes = group.stopTimes.filter { stopTime in
                    guard let departure = stopTime.place.departure else { return true }
                    return departure.addingTimeInterval(bufferTimeForTransport(stopTime)) > now
                }
                
                if filteredStopTimes.count != group.stopTimes.count {
                    if !filteredStopTimes.isEmpty {
                        groups[groupIndex] = GroupedStopTime(
                            routeShortName: group.routeShortName,
                            headsign: group.headsign,
                            stopTimes: filteredStopTimes
                        )
                        groupsModified = true
                    } else {
                        groups.remove(at: groupIndex)
                        groupsModified = true
                        break
                    }
                }
            }
            
            if groupsModified {
                if groups.isEmpty {
                    routeGroups.removeValue(forKey: routeName)
                    needsRefresh = true
                } else {
                    routeGroups[routeName] = groups
                }
            }
        }
        
        outerLoop: for (_, groups) in routeGroups {
            guard !groups.isEmpty else { continue }
            
            for group in groups {
                if let firstStopTime = group.stopTimes.first,
                   let departure = firstStopTime.place.departure,
                   let bufferTime = group.stopTimes.first.map(bufferTimeForTransport),
                   departure.addingTimeInterval(bufferTime) < now {
                    needsRefresh = true
                    break outerLoop
                }
            }
        }
        
        if needsRefresh {
            let currentRouteNames = Set(routeGroups.keys)
            let previousRouteNames = Set(routeNames)
            
            if currentRouteNames != previousRouteNames {
                self.routeNames = Array(currentRouteNames).sorted { routeA, routeB in
                    routeOrder[routeA] ?? Int.max < routeOrder[routeB] ?? Int.max
                }
            }
            
            for routeName in currentRouteNames {
                if let groupCount = routeGroups[routeName]?.count,
                   let currentPage = currentPages[routeName],
                   currentPage >= groupCount && groupCount > 0 {
                    currentPages[routeName] = groupCount - 1
                }
            }
        }
    }
    
    @MainActor
    private func groupStopTimes(_ stopTimes: [StopTime]) {
        let now = Date()
        let filteredStopTimes = stopTimes.filter { stopTime in
            guard let departure = stopTime.place.departure else { return true }
            return departure.addingTimeInterval(bufferTimeForTransport(stopTime)) > now
        }
        
        let routeGroups = Dictionary(grouping: filteredStopTimes) { $0.routeShortName }
        
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
                .sorted { $0.headsign < $1.headsign }
            
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
