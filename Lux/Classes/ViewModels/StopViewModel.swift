//
//  StopViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import SwiftUI
import LuxCom
import LuxComHAFAS
import Combine

class StopViewModel: ObservableObject {
    @Published var stopTimes: StopTimes?
    @Published var routeGroups: [String: [GroupedStopTime]] = [:]
    @Published var isLoading = false
    @Published var routeNames: [String] = []
    @Published var currentPages: [String: Int] = [:]
    @Published var errorMessage: String?
    
    @ObservedObject var lineScoreManager = LineScoreManager.shared
    @ObservedObject var settings = Settings.shared
    
    let stop: SearchResult
    
    private var refreshTimer: AnyCancellable?
    private var departureCheckTimer: AnyCancellable?
    private var backgroundRefreshTask: Task<Void, Never>?
    private var fromStops: Bool
    private var currentTime: Date = Date()
    private var isCustomTimeSelected: Bool = false
    @Published var shouldLoadViaLC: Bool
    
    init(stop: SearchResult, fromStops: Bool) {
        self.stop = stop
        self.fromStops = fromStops
        self.shouldLoadViaLC = false
    }
    
    init(stop: SearchResult, fromStops: Bool, isLC: Bool, time: Date?) {
        self.stop = stop
        self.fromStops = fromStops
        self.shouldLoadViaLC = isLC
        if let selectedTime = time {
            isCustomTimeSelected = true
            currentTime = selectedTime
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
        await refreshDepartures(forTime: getReferenceTime(), showLoading: showLoading)
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
                let (departuresData, arrivalsData) = try await fetchDeparturesAndArrivals(for: time)
                
                if Task.isCancelled { return }
                
                let allStopTimes = departuresData.stopTimes + arrivalsData.stopTimes
                let combinedStopTimes = Array(Set(allStopTimes))
                
                let freshStopTimes = StopTimes(
                    stopTimes: combinedStopTimes,
                    previousPageCursor: departuresData.previousPageCursor,
                    nextPageCursor: departuresData.nextPageCursor
                )
                
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
        backgroundRefreshTask = nil
    }
    
    private func fetchDeparturesAndArrivals(for time: Date) async throws -> (departures: StopTimes, arrivals: StopTimes) {
        if settings.dataSource == .luxCom || shouldLoadViaLC {
            async let departuresTask = getDeparturesForStop(
                stopId: stop.id,
                time: time,
                arriveBy: false,
                numberOfEvents: fromStops ? 100 : 50
            )
            
            async let arrivalsTask = getDeparturesForStop(
                stopId: stop.id,
                time: time,
                arriveBy: true,
                direction: "LATER",
                numberOfEvents: fromStops ? 100 : 50
            )
            return try await (departuresTask, arrivalsTask)
        }
        async let departuresTask = citaDepartures(
            stopId: stop.id,
            time: time,
            arriveBy: false,
            numberOfEvents: fromStops ? 100 : 50
        )
        let emptyArrivals = StopTimes(stopTimes: [], previousPageCursor: "", nextPageCursor: "")
        
        return try await (departuresTask, emptyArrivals)
    }

    private func refreshDeparturesInBackground() async {
        guard backgroundRefreshTask == nil || backgroundRefreshTask?.isCancelled == true else {
            return
        }
        let refreshTime = getReferenceTime()
        
        backgroundRefreshTask = Task {
            do {
                let (departuresData, arrivalsData) = try await fetchDeparturesAndArrivals(for: refreshTime)
                if Task.isCancelled {
                    backgroundRefreshTask = nil
                    return
                }
                
                let allStopTimes = departuresData.stopTimes + arrivalsData.stopTimes
                let combinedStopTimes = Array(Set(allStopTimes))
                
                await MainActor.run {
                    self.stopTimes = StopTimes(
                        stopTimes: combinedStopTimes,
                        previousPageCursor: departuresData.previousPageCursor,
                        nextPageCursor: departuresData.nextPageCursor
                    )
                    let times = self.stopTimes?.stopTimes ?? []
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
            return 50.0
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
                    let eventTime = stopTime.place.departure ?? stopTime.place.arrival
                    guard let eventTime = eventTime else { return true }
                    return eventTime.addingTimeInterval(bufferTimeForTransport(stopTime)) > referenceTime
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
                   let eventTime = firstStopTime.place.departure ?? firstStopTime.place.arrival,
                   let bufferTime = group.stopTimes.first.map(bufferTimeForTransport),
                   eventTime.addingTimeInterval(bufferTime) < referenceTime {
                    needsRefresh = true
                    break outerLoop
                }
            }
        }
        
        if needsRefresh {
            let currentRouteNames = Set(routeGroups.keys)
            let previousRouteNames = Set(routeNames)
            
            if currentRouteNames != previousRouteNames {
                self.routeNames = lineScoreManager.getSortedRouteNames(Array(currentRouteNames))
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
    func sortStopTimes(_ stopTimes: [StopTime]) -> [StopTime] {
        let referenceTime = getReferenceTime()
        
        return stopTimes
            .filter { stopTime in
                guard !isCustomTimeSelected else { return true }
                
                let eventTime = stopTime.place.departure ?? stopTime.place.arrival
                guard let eventTime = eventTime else { return true }
                
                return eventTime.addingTimeInterval(bufferTimeForTransport(stopTime)) > referenceTime
            }
            .sorted { lhs, rhs in
                let timeA = lhs.place.departure ?? lhs.place.arrival ?? Date.distantFuture
                let timeB = rhs.place.departure ?? rhs.place.arrival ?? Date.distantFuture
                return timeA < timeB
            }
    }

    @MainActor
    private func groupStopTimes(_ stopTimes: [StopTime]) {
        let filteredStopTimes = isCustomTimeSelected ?
        stopTimes :
        stopTimes.filter { stopTime in
            let eventTime = stopTime.place.departure ?? stopTime.place.arrival
            guard let eventTime = eventTime else { return true }
            return eventTime.addingTimeInterval(bufferTimeForTransport(stopTime)) > getReferenceTime()
        }
        
        let routeGroups = Dictionary(grouping: filteredStopTimes) { $0.routeShortName }
        
        var result: [String: [GroupedStopTime]] = [:]
        var newCurrentPages: [String: Int] = [:]
                
        for (routeName, routeStopTimes) in routeGroups {
            let groupsByHeadsign = Dictionary(grouping: routeStopTimes) { $0.headsign ?? "" }
                .map { (headsign, times) -> GroupedStopTime in
                    let sortedTimes = times.sorted { lhs, rhs in
                        let timeA = lhs.place.departure ?? lhs.place.arrival ?? Date.distantFuture
                        let timeB = rhs.place.departure ?? rhs.place.arrival ?? Date.distantFuture
                        return timeA < timeB
                    }
                    return GroupedStopTime(
                        routeShortName: routeName,
                        headsign: headsign,
                        stopTimes: sortedTimes
                    )
                }
                .sorted { $0.headsign < $1.headsign }
            
            result[routeName] = groupsByHeadsign
            newCurrentPages[routeName] = min(currentPages[routeName] ?? 0, max(0, groupsByHeadsign.count - 1))
        }
        
        let sortedRouteNames = lineScoreManager.getSortedRouteNames(Array(routeGroups.keys))
        
        self.routeNames = sortedRouteNames
        self.routeGroups = result
        self.currentPages = newCurrentPages
    }
    
    
    func userSelectedLine(_ routeShortName: String) {
        let trimmedLine = routeShortName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        lineScoreManager.addScore(to: trimmedLine)
    }
}
