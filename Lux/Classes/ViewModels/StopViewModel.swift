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
    let track: String?
    
    private let liveFeed = RelayLiveFeed<StopTimes>()
    private var departureCheckTimer: AnyCancellable?
    private var backgroundRefreshTask: Task<Void, Never>?
    private var fromStops: Bool
    private var currentTime: Date = Date()
    private var isCustomTimeSelected: Bool = false
    private var needsStartPagePick = true
    private var lastMonitoringStop: Date?
    private var dwellTask: Task<Void, Never>?
    private let directionPreferences = DirectionPreferenceStore.shared

    private static let startPagePickCooldown: TimeInterval = 5 * 60
    private static let dwellDuration: Duration = .seconds(2)
    private static let dwellPoints = 0.3
    private static let selectionPoints = 1.0
    private static let minimumFavoriteScore = 1.0
    private static let favoriteHorizon: TimeInterval = 40 * 60

    init(stop: SearchResult, fromStops: Bool, track: String? = nil) {
        self.stop = stop
        self.fromStops = fromStops
        self.track = track
    }

    init(stop: SearchResult, fromStops: Bool, time: Date?, track: String? = nil) {
        self.stop = stop
        self.fromStops = fromStops
        self.track = track
        if let selectedTime = time {
            isCustomTimeSelected = true
            currentTime = selectedTime
        }
    }
    
    func startMonitoring() {
        if let lastMonitoringStop, Date().timeIntervalSince(lastMonitoringStop) > Self.startPagePickCooldown {
            needsStartPagePick = true
        }

        Task { @MainActor in
            if needsStartPagePick && !routeGroups.isEmpty {
                pickStartPages()
            }
            let relayEligible = !fromStops
                && !OfflineRouter.shared.isOfflineActive
                && !isCustomTimeSelected
            let relayCoversInitialLoad = relayEligible ? await RelayClient.shared.isConnected : false
            if relayCoversInitialLoad {
                if stopTimes == nil { isLoading = true }
            } else if stopTimes == nil {
                isLoading = true
                await refreshDepartures(showLoading: true)
            } else {
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
        dwellTask?.cancel()
        lastMonitoringStop = Date()
    }

    /// Live departures via the relay WebSocket. The relay pushes a new
    /// StopTimes payload only when it changed; the legacy 5s HTTP poll runs as
    /// fallback while the socket is down, and exclusively in offline mode or
    /// when browsing a custom time (the relay only serves "now").
    @MainActor
    private func startLiveFeed() {
        let fallbackOnly = OfflineRouter.shared.isOfflineActive || isCustomTimeSelected
        let stopId = stop.id
        let count = departureCount
        let radius = departureRadius

        liveFeed.start(
            fallbackOnly: fallbackOnly,
            fallbackInterval: .seconds(5),
            stream: {
                await RelayClient.shared.departures(
                    stopId: stopId,
                    n: count,
                    radius: radius
                )
            },
            fallbackFetch: { [weak self] in
                guard let self else { return nil }
                let fetchTime = await self.isCustomTimeSelected ? self.currentTime : Date()
                do {
                    return try await self.fetchDeparturesAndArrivals(for: fetchTime)
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                    return nil
                }
            },
            onUpdate: { [weak self] freshStopTimes in
                self?.applyStopTimes(freshStopTimes)
            }
        )
    }

    private var departureCount = 50
    private var hasWidenedDepartureWindow = false

    private var departureRadius: Int? {
        if stop.servesMainlineRail { return Int(departureRadiusMeters) }
        if stop.groupedStopIds.count > 1 { return Int(departureRadiusMeters) }
        guard StopGrouping.isStationForecourt(stop.name) else { return nil }
        return stop.hasRailNeighbour == false ? nil : Int(departureRadiusMeters)
    }

    private var thinDepartureThreshold: Int {
        stop.servesMainlineRail ? 45 : 30
    }

    @MainActor
    private func widenDepartureWindowIfNeeded(raw: StopTimes, filtered: StopTimes) {
        guard !fromStops, !isCustomTimeSelected, !hasWidenedDepartureWindow,
              raw.stopTimes.count >= departureCount,
              filtered.stopTimes.count < thinDepartureThreshold
        else { return }

        hasWidenedDepartureWindow = true
        departureCount = 100

        Task { @MainActor in
            startLiveFeed()
        }
    }

    private func filteredForStation(_ stopTimes: StopTimes) -> StopTimes {
        let station = stopTimes.filteredToStation(stopId: stop.id, name: stop.name, lat: stop.lat, lon: stop.lon, servesMainlineRail: stop.servesMainlineRail)
        guard let track else { return station }
        let wanted = StationLayout.normalizedTrack(track)
        return StopTimes(
            stopTimes: station.stopTimes.filter { stopTime in
                (stopTime.place.track ?? stopTime.place.scheduledTrack).map(StationLayout.normalizedTrack) == wanted
            },
            previousPageCursor: station.previousPageCursor,
            nextPageCursor: station.nextPageCursor
        )
    }

    @MainActor
    private func applyStopTimes(_ rawStopTimes: StopTimes) {
        let freshStopTimes = filteredForStation(rawStopTimes)
        self.isLoading = false
        self.errorMessage = nil
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

        widenDepartureWindowIfNeeded(raw: rawStopTimes, filtered: freshStopTimes)
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

                self.applyStopTimes(freshStopTimes)
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
    private func fetchDeparturesAndArrivals(for time: Date) async throws -> StopTimes {
        try await LuxData.departures(
            stopId: stop.id,
            time: time,
            both: true,
            direction: "LATER",
            numberOfEvents: fromStops ? 100 : departureCount,
            radius: departureRadius
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
                    self.applyStopTimes(freshStopTimes)
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
        stopTime.displayBufferTime
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
                        if let page = currentPages[routeName], page > groupIndex {
                            currentPages[routeName] = page - 1
                        }
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

    private static let duplicateWindow: TimeInterval = 3 * 60

    private func deduplicatedByTrip(_ stopTimes: [StopTime]) -> [StopTime] {
        var indicesByTrip: [String: [Int]] = [:]
        for (index, stopTime) in stopTimes.enumerated() {
            indicesByTrip[stopTime.tripId, default: []].append(index)
        }

        var kept = Set<Int>()
        for (_, indices) in indicesByTrip {
            let ordered = indices.sorted { eventTime(stopTimes[$0]) < eventTime(stopTimes[$1]) }
            var cluster: [Int] = []
            func keepClosestOfCluster() {
                if let closest = cluster.min(by: {
                    distanceToStop(stopTimes[$0].place) < distanceToStop(stopTimes[$1].place)
                }) {
                    kept.insert(closest)
                }
                cluster.removeAll()
            }
            for index in ordered {
                if let first = cluster.first,
                   eventTime(stopTimes[index]).timeIntervalSince(eventTime(stopTimes[first])) > Self.duplicateWindow {
                    keepClosestOfCluster()
                }
                cluster.append(index)
            }
            keepClosestOfCluster()
        }

        return stopTimes.enumerated()
            .filter { kept.contains($0.offset) }
            .map(\.element)
    }

    private func eventTime(_ stopTime: StopTime) -> Date {
        stopTime.place.departure ?? stopTime.place.arrival ?? .distantFuture
    }

    private func distanceToStop(_ place: Place) -> Double {
        let deltaLat = place.lat - stop.lat
        let deltaLon = (place.lon - stop.lon) * cos(stop.lat * .pi / 180)
        return deltaLat * deltaLat + deltaLon * deltaLon
    }

    @MainActor
    private func groupStopTimes(_ rawStopTimes: [StopTime]) {
        let stopTimes = deduplicatedByTrip(rawStopTimes)
        let referenceTime = getReferenceTime()
        let filteredStopTimes = isCustomTimeSelected ?
        stopTimes :
        stopTimes.filter { stopTime in
            let eventTime = stopTime.place.departure ?? stopTime.place.arrival
            guard let eventTime = eventTime else { return true }
            return eventTime.addingTimeInterval(bufferTimeForTransport(stopTime)) > referenceTime
        }
        
        let routeGroups = Dictionary(grouping: filteredStopTimes) { $0.routeShortName }
        let viewedStopKey = stop.name.normalizedHeadsignKey

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
                .sorted { lhs, rhs in
                    let lhsEndsHere = lhs.headsign.normalizedHeadsignKey == viewedStopKey
                    let rhsEndsHere = rhs.headsign.normalizedHeadsignKey == viewedStopKey
                    if lhsEndsHere != rhsEndsHere { return rhsEndsHere }
                    return lhs.headsign < rhs.headsign
                }

            result[routeName] = groupsByHeadsign
            newCurrentPages[routeName] = startPage(for: routeName, in: groupsByHeadsign)
        }

        needsStartPagePick = false
        
        let sortedRouteNames = lineScoreManager.getSortedRouteNames(Array(routeGroups.keys))
        
        self.routeNames = sortedRouteNames
        self.routeGroups = result
        self.currentPages = newCurrentPages
    }
    
    
    @MainActor
    private func startPage(for routeName: String, in groups: [GroupedStopTime]) -> Int {
        guard !needsStartPagePick, let previousGroups = self.routeGroups[routeName] else {
            return preferredStartPage(for: groups)
        }

        let previousPage = currentPages[routeName] ?? 0
        if previousGroups.indices.contains(previousPage) {
            let previousKey = previousGroups[previousPage].headsign.normalizedHeadsignKey
            if let index = groups.firstIndex(where: { $0.headsign.normalizedHeadsignKey == previousKey }) {
                return index
            }
        }
        return min(previousPage, max(0, groups.count - 1))
    }

    @MainActor
    private func pickStartPages() {
        for routeName in routeNames {
            if let groups = routeGroups[routeName] {
                currentPages[routeName] = preferredStartPage(for: groups)
            }
        }
        needsStartPagePick = false
    }

    @MainActor
    private func preferredStartPage(for groups: [GroupedStopTime]) -> Int {
        let referenceTime = getReferenceTime()
        let viewedStopKey = stop.name.normalizedHeadsignKey
        let candidates = groups.indices.filter { groups[$0].headsign.normalizedHeadsignKey != viewedStopKey }
        guard !candidates.isEmpty else { return 0 }

        func nextDeparture(_ index: Int) -> Date {
            groups[index].stopTimes.first.map(eventTime) ?? .distantFuture
        }

        let favorite = candidates
            .map { index in
                (index: index, score: directionPreferences.score(
                    stopId: stop.id,
                    route: groups[index].routeShortName,
                    headsignKey: groups[index].headsign.normalizedHeadsignKey,
                    at: referenceTime
                ))
            }
            .filter { $0.score >= Self.minimumFavoriteScore }
            .max { $0.score < $1.score }

        if let favorite, nextDeparture(favorite.index).timeIntervalSince(referenceTime) <= Self.favoriteHorizon {
            return favorite.index
        }

        return candidates.min { nextDeparture($0) < nextDeparture($1) } ?? 0
    }

    @MainActor
    func userChangedPage(_ page: Int, for routeName: String) {
        currentPages[routeName] = page
        dwellTask?.cancel()

        guard let group = routeGroups[routeName], group.indices.contains(page) else { return }
        let headsignKey = group[page].headsign.normalizedHeadsignKey

        dwellTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.dwellDuration)
            guard let self, !Task.isCancelled, self.currentPages[routeName] == page else { return }
            self.recordDirection(route: routeName, headsignKey: headsignKey, points: Self.dwellPoints)
        }
    }

    @MainActor
    func userSelectedGroup(_ group: GroupedStopTime) {
        userSelectedLine(group.routeShortName)
        recordDirection(route: group.routeShortName, headsignKey: group.headsign.normalizedHeadsignKey, points: Self.selectionPoints)
    }

    @MainActor
    private func recordDirection(route: String, headsignKey: String, points: Double) {
        directionPreferences.record(stopId: stop.id, route: route, headsignKey: headsignKey, at: getReferenceTime(), points: points)
    }

    func userSelectedLine(_ routeShortName: String) {
        let trimmedLine = routeShortName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        lineScoreManager.addScore(to: trimmedLine)
    }
}

extension String {
    var normalizedHeadsignKey: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
