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
    
    @ObservedObject var lineScoreManager = LineScoreManager.shared
    
    let stop: SearchResult
    
    private var routeOrder: [String: Int] = [:]
    private var refreshTimer: AnyCancellable?
    private var departureCheckTimer: AnyCancellable?
    private var backgroundRefreshTask: Task<Void, Never>?
    private var fromStops: Bool
    private var currentTime: Date = Date()
    private var isCustomTimeSelected: Bool = false
    
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
            refreshTimer = Timer.publish(every: 5, on: .main, in: .common)
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
        
        let now = Date()
        isCustomTimeSelected = abs(time.timeIntervalSince(now)) > 60
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
    
    private func refreshDeparturesInBackground() async {
        backgroundRefreshTask?.cancel()
        
        backgroundRefreshTask = Task {
            do {
                let freshStopTimes = try await getDeparturesForStop(
                    stopId: stop.id,
                    time: currentTime,
                    numberOfEvents: fromStops ? 100 : 50
                )
                if Task.isCancelled {
                    backgroundRefreshTask = nil
                    return
                }
                
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
        case .rail, .highSpeedRail, .regionalRail, .regionalFastRail, .ferry:
            if let arrival = stopTime.place.arrival,
                  let departure = stopTime.place.departure,
               arrival != departure {
                let timeDifference = departure.timeIntervalSince(arrival)
                if timeDifference > 0 {
                    return timeDifference
                }
            }
            return 60.0
        default:
            return 40.0
        }
    }
    
    private func getReferenceTime() -> Date {
        return isCustomTimeSelected ? currentTime : Date()
    }
    
    @MainActor
    func checkAndHandleDepartures() {
        if fromStops {
            return
        }
        
        let referenceTime = getReferenceTime()
        var needsRefresh = false

        for routeName in routeNames {
            guard var groups = routeGroups[routeName], !groups.isEmpty else { continue }
            
            var groupsModified = false
            
            for groupIndex in 0..<groups.count {
                let group = groups[groupIndex]
                
                let filteredStopTimes = group.stopTimes.filter { stopTime in
                    guard let departure = stopTime.place.departure else { return true }
                    return departure.addingTimeInterval(bufferTimeForTransport(stopTime)) > referenceTime
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
                   departure.addingTimeInterval(bufferTime) < referenceTime {
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
        let referenceTime = getReferenceTime()
        
        let filteredStopTimes: [StopTime]
        if isCustomTimeSelected {
            filteredStopTimes = stopTimes
        } else {
            filteredStopTimes = stopTimes.filter { stopTime in
                guard let departure = stopTime.place.departure else { return true }
                return departure.addingTimeInterval(bufferTimeForTransport(stopTime)) > referenceTime
            }
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
        
        let sortedRouteNames = lineScoreManager.getSortedRouteNames(Array(routeGroups.keys))
        
        for (index, name) in sortedRouteNames.enumerated() {
            routeOrder[name] = index
        }
        
        self.routeNames = sortedRouteNames
        self.routeGroups = result
        self.currentPages = newCurrentPages
    }
    
    
    func userSelectedLine(_ routeShortName: String) {
        let trimmedLine = routeShortName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        lineScoreManager.addScore(to: trimmedLine)
    }
}
