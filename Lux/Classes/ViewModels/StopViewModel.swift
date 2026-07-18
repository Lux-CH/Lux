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
    @Published var isLoading = false
    @Published var routeNames: [String] = []
    @Published var currentPages: [String: Int] = [:]
    @Published var errorMessage: String?
    
    @ObservedObject var lineScoreManager = LineScoreManager.shared
    @ObservedObject var settings = Settings.shared
    
    let stop: SearchResult
    
    private let liveFeed = RelayLiveFeed<StopTimes>()
    private var departureCheckTimer: AnyCancellable?
    private var backgroundRefreshTask: Task<Void, Never>?
    private var fromStops: Bool
    private var currentTime: Date = Date()
    private var isCustomTimeSelected: Bool = false
    init(stop: SearchResult, fromStops: Bool) {
        self.stop = stop
        self.fromStops = fromStops
    }

    init(stop: SearchResult, fromStops: Bool, time: Date?) {
        self.stop = stop
        self.fromStops = fromStops
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
            Task { @MainActor in
                self.startLiveFeed()
            }

            departureCheckTimer = Timer.publish(every: 10, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.checkAndHandleDepartures()
                    }
                }
        }
    }
    
    func stopMonitoring() {
        Task { @MainActor in
            self.liveFeed.stop()
        }
        departureCheckTimer?.cancel()
        backgroundRefreshTask?.cancel()
    }

    /// Live departures via the relay WebSocket. The relay pushes a new
    /// StopTimes payload only when it changed; the legacy 5s HTTP poll runs as
    /// fallback while the socket is down, and exclusively in offline mode or
    /// when browsing a custom time (the relay only serves "now").
    @MainActor
    private func startLiveFeed() {
        let fallbackOnly = OfflineRouter.shared.isOfflineActive || isCustomTimeSelected
        let stopId = stop.id

        liveFeed.start(
            fallbackOnly: fallbackOnly,
            fallbackInterval: .seconds(5),
            stream: {
                await RelayClient.shared.departures(
                    stopId: stopId,
                    n: 50,
                    radius: 200
                )
            },
            fallbackFetch: { [weak self] in
                guard let self else { return nil }
                let fetchTime = self.isCustomTimeSelected ? self.currentTime : Date()
                return try? await self.fetchDeparturesAndArrivals(for: fetchTime)
            },
            onUpdate: { [weak self] freshStopTimes in
                self?.applyStopTimes(freshStopTimes)
            }
        )
    }

    @MainActor
    private func applyStopTimes(_ freshStopTimes: StopTimes) {
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
    
    @MainActor
    func refreshDepartures(showLoading: Bool) async {
        let timeToUse = isCustomTimeSelected ? currentTime : Date()
        await refreshDepartures(forTime: timeToUse, showLoading: showLoading)
    }
    
    @MainActor
    func refreshDepartures(forTime time: Date, showLoading: Bool) async {
        if showLoading { isLoading = true }
        backgroundRefreshTask?.cancel()
        
        let now = Date()
        let isSignificantDifference = abs(time.timeIntervalSince(now)) > 60
        let customTimeChanged = isCustomTimeSelected != isSignificantDifference
        isCustomTimeSelected = isSignificantDifference
        currentTime = time

        // Entering/leaving custom-time browsing switches between the relay
        // stream (live "now" data) and local polling at the selected time.
        if customTimeChanged && !fromStops {
            startLiveFeed()
        }

        backgroundRefreshTask = Task {
            defer {
                if showLoading {
                    self.isLoading = false
                }
            }
            
            do {
                let freshStopTimes = try await fetchDeparturesAndArrivals(for: time)
                
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
    
    private func fetchDeparturesAndArrivals(for time: Date) async throws -> StopTimes {
        try await LuxData.departures(
            stopId: stop.id,
            time: time,
            both: true,
            direction: "LATER",
            numberOfEvents: fromStops ? 100 : 50,
            radius: 200
        )
    }

    private func refreshDeparturesInBackground() async {
        backgroundRefreshTask?.cancel()
        
        let fetchTime = isCustomTimeSelected ? currentTime : Date()
        if !isCustomTimeSelected {
            currentTime = fetchTime
        }
        
        backgroundRefreshTask = Task {
            do {
                let freshStopTimes = try await fetchDeparturesAndArrivals(for: fetchTime)
                if Task.isCancelled {
                    backgroundRefreshTask = nil
                    return
                }
                
                await MainActor.run {
                    self.stopTimes = freshStopTimes
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
            let groupsByHeadsign = Dictionary(grouping: routeStopTimes) { $0.headsign?.normalizedHeadsignKey ?? "" }
                .map { (_, times) -> GroupedStopTime in
                    let sortedTimes = times.sorted { lhs, rhs in
                        let timeA = lhs.place.departure ?? lhs.place.arrival ?? Date.distantFuture
                        let timeB = rhs.place.departure ?? rhs.place.arrival ?? Date.distantFuture
                        return timeA < timeB
                    }
                    return GroupedStopTime(
                        routeShortName: routeName,
                        headsign: sortedTimes.first?.headsign ?? "",
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

private extension String {
    var normalizedHeadsignKey: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
