//
//  HomeStopViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import SwiftUI
import LuxCom
import Combine

class HomeStopViewModel: ObservableObject {
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
        
        refreshTimer = Timer.publish(every: 7.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshDeparturesInBackground()
                }
            }
            
        departureCheckTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkAndHandleDepartures()
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
        if showLoading { isLoading = true }
        backgroundRefreshTask?.cancel()
        
        backgroundRefreshTask = Task {
            defer {
                if showLoading {
                    self.isLoading = false
                }
            }
            
            do {
                let freshStopTimes = try await getDeparturesForStop(stopId: stop.id, numberOfEvents: fromStops ? 100 : 50)
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
                let freshStopTimes = try await getDeparturesForStop(stopId: stop.id, numberOfEvents: fromStops ? 100 : 50)
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
    
    @MainActor
    func checkAndHandleDepartures() {
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
    
    @MainActor
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
