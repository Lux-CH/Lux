//
//  NearbyIntelligence.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import Foundation
import CoreLocation
import LuxCom

@MainActor
final class NearbyIntelligence: ObservableObject {
    struct Pick: Equatable {
        let stop: SearchResult
        let line: String
        let mode: TransportationMode
        let agencyId: String
        let headsign: String
        let tripId: String
        let departure: Date
        let following: Date?
        let walkSeconds: TimeInterval
        let realTime: Bool
        let crowd: Double?
        let weather: WeatherSnapshot?

        var leaveAt: Date { departure.addingTimeInterval(-walkSeconds - 60) }
        var walkMinutes: Int { max(1, Int((walkSeconds / 60).rounded(.up))) }

        static func == (lhs: Pick, rhs: Pick) -> Bool {
            lhs.tripId == rhs.tripId && lhs.departure == rhs.departure && lhs.following == rhs.following
                && lhs.crowd == rhs.crowd && lhs.weather == rhs.weather && lhs.walkSeconds == rhs.walkSeconds
        }
    }

    @Published private(set) var pick: Pick?

    private var task: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var lastInputs: (stops: [SearchResult], location: CLLocation?)?
    private var lastRefresh = Date.distantPast
    private var lastStopIds: [String] = []

    private static let minimumScore = 1.0
    private static let horizon: TimeInterval = 45 * 60
    private static let maxDistance: CLLocationDistance = 900

    func refresh(stops: [SearchResult], location: CLLocation?, force: Bool = false) {
        lastInputs = (stops, location)
        let candidates = Array(stops.prefix(3))
        let ids = candidates.map(\.id)
        guard let location, !candidates.isEmpty else {
            pick = nil
            return
        }
        guard force || ids != lastStopIds || Date().timeIntervalSince(lastRefresh) > 45 else { return }
        lastStopIds = ids
        lastRefresh = Date()

        let profile = IntelligenceStore.shared.profile
        let usesCrowd = profile.crowd != .indifferent && Settings.shared.crowdbackAllowed && !OfflineRouter.shared.isOfflineActive
        let speed = max(0.6, UserDefaults.standard.object(forKey: "routeOptionsPedestrianSpeed") as? Double ?? 1.2)

        task?.cancel()
        task = Task { [weak self] in
            let now = Date()
            let lineScores = LineScoreManager.shared.lineScores
            let topLineScore = lineScores.map(\.totalScore).max() ?? 0

            var best: (score: Double, stop: SearchResult, times: [StopTime], walk: TimeInterval)?
            await withTaskGroup(of: (SearchResult, [StopTime]).self) { group in
                for stop in candidates {
                    group.addTask {
                        let times = (try? await LuxData.departures(stopId: stop.id, time: now, numberOfEvents: 40))?.stopTimes ?? []
                        return (stop, times)
                    }
                }
                for await (stop, times) in group {
                    let distance = location.distance(from: CLLocation(latitude: stop.lat, longitude: stop.lon))
                    guard distance <= Self.maxDistance else { continue }
                    let walk = distance * 1.3 / speed + 30
                    let groups = Dictionary(grouping: times.filter { !$0.cancelled }) {
                        "\($0.routeShortName)|\($0.headsign?.normalizedHeadsignKey ?? "")"
                    }
                    for (_, groupTimes) in groups {
                        guard let first = groupTimes.first else { continue }
                        let direction = DirectionPreferenceStore.shared.score(
                            stopId: stop.id,
                            route: first.routeShortName,
                            headsignKey: first.headsign?.normalizedHeadsignKey ?? "",
                            at: now
                        )
                        guard direction >= Self.minimumScore else { continue }
                        let line = topLineScore > 0 ? LineScoreManager.shared.getScore(for: first.routeShortName) / topLineScore * 0.5 : 0
                        let score = direction + line - distance / 1000
                        if best.map({ score > $0.score }) ?? true {
                            best = (score, stop, groupTimes, walk)
                        }
                    }
                }
            }

            guard !Task.isCancelled else { return }
            guard let best else {
                self?.pick = nil
                return
            }

            func time(_ stopTime: StopTime) -> Date? { stopTime.place.departure ?? stopTime.place.arrival }
            let catchable = best.times
                .compactMap { stopTime in time(stopTime).map { (stopTime, $0) } }
                .filter { $0.1 >= now.addingTimeInterval(best.walk - 30) }
                .sorted { $0.1 < $1.1 }
            guard let (next, departure) = catchable.first, departure.timeIntervalSince(now) <= Self.horizon else {
                self?.pick = nil
                return
            }

            async let weather = WeatherService.shared.snapshot(latitude: best.stop.lat, longitude: best.stop.lon, at: departure)
            async let crowd: Double? = {
                guard usesCrowd else { return nil }
                let info = try? await getLCBInfo(tripId: next.tripId, routeShortName: next.routeShortName, latitude: best.stop.lat, longitude: best.stop.lon, attribute: .crowd)
                return info?.communityLevel(for: .crowd)?.level
            }()

            let result = Pick(
                stop: best.stop,
                line: next.routeShortName,
                mode: next.mode,
                agencyId: next.agencyId,
                headsign: next.headsign ?? "",
                tripId: next.tripId,
                departure: departure,
                following: catchable.dropFirst().first?.1,
                walkSeconds: best.walk,
                realTime: next.realTime,
                crowd: await crowd,
                weather: await weather
            )
            guard !Task.isCancelled else { return }
            self?.pick = result
            self?.scheduleExpiry(at: departure)
        }
    }

    private func scheduleExpiry(at departure: Date) {
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(1, departure.timeIntervalSinceNow)))
            guard let self, !Task.isCancelled else { return }
            self.pick = nil
            if let inputs = self.lastInputs {
                self.refresh(stops: inputs.stops, location: inputs.location, force: true)
            }
        }
    }
}
