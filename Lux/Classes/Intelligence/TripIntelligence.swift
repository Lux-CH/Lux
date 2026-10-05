//
//  TripIntelligence.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import Foundation
import CoreLocation
import LuxCom

struct TripSuggestion: Equatable {
    struct Reason: Hashable {
        let symbol: String
        let text: String
    }

    let itinerary: Itinerary
    let reasons: [Reason]
    let weather: WeatherSnapshot?
    let minutesLater: Int
    let chosen: RankedTrip
    let fastest: RankedTrip

    static func == (lhs: TripSuggestion, rhs: TripSuggestion) -> Bool {
        lhs.itinerary.intelligenceSignature == rhs.itinerary.intelligenceSignature && lhs.reasons == rhs.reasons && lhs.weather == rhs.weather
    }
}

struct TripFeatures {
    let walkMinutes: Double
    let outdoorWaitMinutes: Double
    let tightestSlack: Double?
    let crowdPeak: Double?
    let habitLine: String?
    let habitScore: Double
    let transfers: Int
}

struct CostBreakdown {
    var time = 0.0
    var transfers = 0.0
    var walking = 0.0
    var weather = 0.0
    var margin = 0.0
    var crowd = 0.0
    var habits = 0.0

    var total: Double { time + transfers + walking + weather + margin + crowd + habits }
}

struct RankedTrip {
    let itinerary: Itinerary
    let features: TripFeatures
    let cost: CostBreakdown
}

extension Itinerary {
    var intelligenceSignature: String {
        let legs = legs.map { $0.tripId ?? "\($0.mode.rawValue)\(Int($0.startTime.timeIntervalSince1970))" }.joined(separator: ",")
        return "\(Int(startTime.timeIntervalSince1970))|\(Int(endTime.timeIntervalSince1970))|\(legs)"
    }

    init(legs: [Leg]) {
        let start = legs.first?.startTime ?? Date()
        let end = legs.last?.endTime ?? start
        self.init(
            duration: Int(end.timeIntervalSince(start)),
            startTime: start,
            endTime: end,
            transfers: max(0, legs.filter(\.isTransit).count - 1),
            legs: legs
        )
    }
}

enum TripIntelligence {
    struct Context {
        let profile: IntelligenceProfile
        let learning: IntelligenceLearning
        let weather: WeatherSnapshot?
        let arriveBy: Bool
        let crowd: [String: Double]

        init(profile: IntelligenceProfile = IntelligenceStore.shared.profile,
             learning: IntelligenceLearning = IntelligenceStore.shared.learning,
             weather: WeatherSnapshot?,
             arriveBy: Bool,
             crowd: [String: Double]) {
            self.profile = profile
            self.learning = learning.isEnabled ? learning : learning.erased()
            self.weather = weather
            self.arriveBy = arriveBy
            self.crowd = crowd
        }
    }

    struct Weights {
        let walk: Double
        let weather: Double
        let transfer: Double
        let margin: Double
        let crowd: Double
    }

    static func weights(for context: Context) -> Weights {
        let profile = context.profile
        let learning = context.learning
        let walk: Double = switch profile.walking {
        case .enjoys: 0
        case .neutral: 0.3
        case .minimal: 1
        }
        let weatherBase: Double = switch profile.weather {
        case .indifferent: 0
        case .walkLess: 0.8
        case .avoidWalking: 2
        }
        var weather = 0.0
        if let snapshot = context.weather, snapshot.isHarsh {
            weather = max(0, weatherBase + learning.weather)
            if !snapshot.isWet { weather /= 2 }
        }
        let crowd: Double = switch profile.crowd {
        case .indifferent: 0
        case .avoid: 2.5
        case .avoidStrongly: 6
        }
        return Weights(
            walk: max(0, walk + learning.walk),
            weather: weather,
            transfer: max(0, Double(profile.directness.rawValue) + learning.transfer),
            margin: max(0, Double(profile.margin.rawValue) + learning.margin),
            crowd: max(0, crowd + learning.crowd)
        )
    }

    static func needsDirectSearch(_ profile: IntelligenceProfile, maxTransfers: Int) -> Bool {
        profile.directness != .never && maxTransfers > 0
    }

    static func needsLessWalkingSearch(_ profile: IntelligenceProfile, weather: WeatherSnapshot?) -> Bool {
        if profile.walking == .minimal { return true }
        guard let weather, weather.isHarsh else { return false }
        return profile.weather != .indifferent
    }

    @MainActor
    static func liveContext(near coordinate: CLLocationCoordinate2D?, at date: Date, candidates: [Itinerary], arriveBy: Bool = false, includeCrowd: Bool = true) async -> Context {
        let profile = IntelligenceStore.shared.profile
        let isOffline = OfflineRouter.shared.isOfflineActive
        async let weather: WeatherSnapshot? = {
            guard let coordinate, !isOffline else { return nil }
            return await WeatherService.shared.snapshot(latitude: coordinate.latitude, longitude: coordinate.longitude, at: date)
        }()
        let usesCrowd = includeCrowd && profile.crowd != .indifferent && Settings.shared.crowdbackAllowed && !isOffline
        let crowd = usesCrowd ? await crowdLevels(for: candidates) : [:]
        return Context(weather: await weather, arriveBy: arriveBy, crowd: crowd)
    }

    static func crowdLevels(for itineraries: [Itinerary]) async -> [String: Double] {
        var requests: [(tripId: String, line: String, lat: Double, lon: Double)] = []
        var seen = Set<String>()
        for itinerary in itineraries {
            for leg in itinerary.legs where leg.isTransit {
                guard let tripId = leg.tripId, let line = leg.routeShortName, seen.insert(tripId).inserted else { continue }
                requests.append((tripId, line, leg.from.lat, leg.from.lon))
            }
        }

        enum Outcome {
            case level(String, Double?)
            case timeout
        }

        let batch = Array(requests.prefix(12))
        guard !batch.isEmpty else { return [:] }
        return await withTaskGroup(of: Outcome.self) { group in
            for request in batch {
                group.addTask {
                    let info = try? await getLCBInfo(tripId: request.tripId, routeShortName: request.line, latitude: request.lat, longitude: request.lon, attribute: .crowd)
                    return .level(request.tripId, info?.communityLevel(for: .crowd)?.level)
                }
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(2500))
                return .timeout
            }
            var levels: [String: Double] = [:]
            var pending = batch.count
            while pending > 0, let outcome = await group.next() {
                guard case .level(let tripId, let level) = outcome else { break }
                pending -= 1
                if let level { levels[tripId] = level }
            }
            group.cancelAll()
            return levels
        }
    }

    static func rank(_ candidates: [Itinerary], context: Context) -> [RankedTrip] {
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0.intelligenceSignature).inserted }
        let upcoming = unique.filter { context.arriveBy || $0.startTime > Date().addingTimeInterval(-60) }
        guard !upcoming.isEmpty else { return [] }

        let earliestEnd = upcoming.map(\.endTime).min()!
        let latestStart = upcoming.map(\.startTime).max()!
        let weights = weights(for: context)

        return upcoming.map { itinerary in
            let features = features(for: itinerary, context: context)
            var cost = breakdown(features, weights: weights, context: context)
            cost.time = context.arriveBy
                ? latestStart.timeIntervalSince(itinerary.startTime) / 60
                : itinerary.endTime.timeIntervalSince(earliestEnd) / 60
            return RankedTrip(itinerary: itinerary, features: features, cost: cost)
        }
        .sorted { lhs, rhs in
            if abs(lhs.cost.total - rhs.cost.total) > 0.001 { return lhs.cost.total < rhs.cost.total }
            return lhs.itinerary.startTime < rhs.itinerary.startTime
        }
    }

    static func fastest(in ranked: [RankedTrip]) -> RankedTrip? {
        ranked.min { lhs, rhs in
            if abs(lhs.cost.time - rhs.cost.time) > 0.001 { return lhs.cost.time < rhs.cost.time }
            return lhs.itinerary.transfers < rhs.itinerary.transfers
        }
    }

    static func suggest(from candidates: [Itinerary], context: Context) -> TripSuggestion? {
        let ranked = rank(candidates, context: context)
        guard let best = ranked.first, let fastest = fastest(in: ranked) else { return nil }
        return TripSuggestion(
            itinerary: best.itinerary,
            reasons: reasons(best: best, fastest: fastest, context: context),
            weather: context.weather,
            minutesLater: max(0, Int((best.cost.time - fastest.cost.time).rounded())),
            chosen: best,
            fastest: fastest
        )
    }

    static func features(for itinerary: Itinerary, context: Context) -> TripFeatures {
        let walkMinutes = Double(itinerary.legs.filter { $0.mode == .walk }.reduce(0) { $0 + $1.duration }) / 60

        var outdoorWait = 0.0
        var tightest: Double?
        var previousTransit: Leg?
        var walkSinceTransit = 0.0
        for leg in itinerary.legs {
            if leg.isTransit {
                if let previous = previousTransit, leg.interlineWithPreviousLeg != true {
                    let slack = (leg.startTime.timeIntervalSince(previous.endTime) - walkSinceTransit) / 60
                    outdoorWait += max(0, slack)
                    tightest = min(tightest ?? slack, slack)
                }
                previousTransit = leg
                walkSinceTransit = 0
            } else {
                walkSinceTransit += Double(leg.duration)
            }
        }

        let transitLegs = itinerary.legs.filter(\.isTransit)
        let crowdPeak = transitLegs.compactMap { $0.tripId.flatMap { context.crowd[$0] } }.max()

        var habitScore = 0.0
        var habitLine: String?
        if context.profile.usesHabits {
            let lineScores = LineScoreManager.shared.lineScores
            let topScore = lineScores.map(\.totalScore).max() ?? 0
            var bestLeg = 0.0
            for leg in transitLegs {
                guard let line = leg.routeShortName else { continue }
                var legScore = 0.0
                if topScore > 0 {
                    legScore += min(1, LineScoreManager.shared.getScore(for: line) / topScore) * 1.5
                }
                if let headsign = leg.headsign {
                    let key = headsign.normalizedHeadsignKey
                    let direction = [leg.from.parentId, leg.from.stopId].compactMap { $0 }.map {
                        DirectionPreferenceStore.shared.score(stopId: $0, route: line, headsignKey: key, at: leg.startTime)
                    }.max() ?? 0
                    legScore += min(1, direction / 3) * 2
                }
                habitScore += legScore
                if legScore > bestLeg, legScore >= 1 {
                    bestLeg = legScore
                    habitLine = line
                }
            }
        }

        return TripFeatures(
            walkMinutes: walkMinutes,
            outdoorWaitMinutes: outdoorWait,
            tightestSlack: tightest,
            crowdPeak: crowdPeak,
            habitLine: habitLine,
            habitScore: min(habitScore, 4),
            transfers: itinerary.transfers
        )
    }

    private static func breakdown(_ features: TripFeatures, weights: Weights, context: Context) -> CostBreakdown {
        var cost = CostBreakdown()
        cost.walking = features.walkMinutes * weights.walk
        cost.weather = features.walkMinutes * weights.weather + features.outdoorWaitMinutes * weights.weather * 0.4
        cost.transfers = Double(features.transfers) * weights.transfer
        if let slack = features.tightestSlack {
            if slack < weights.margin { cost.margin += (weights.margin - slack) * 1.5 }
            if slack < 1 { cost.margin += 2 }
        }
        if let crowd = features.crowdPeak {
            cost.crowd = max(0, crowd - 2.5) * weights.crowd
        }
        cost.habits = -features.habitScore
        return cost
    }

    static func reasons(best: RankedTrip, fastest: RankedTrip, context: Context) -> [TripSuggestion.Reason] {
        var reasons: [TripSuggestion.Reason] = []
        let isFastest = best.itinerary.intelligenceSignature == fastest.itinerary.intelligenceSignature

        if isFastest {
            reasons.append(.init(symbol: "bolt.fill", text: String(localized: "Le plus rapide")))
        }

        if best.itinerary.transfers < fastest.itinerary.transfers {
            let saved = fastest.itinerary.transfers - best.itinerary.transfers
            reasons.append(best.itinerary.transfers == 0
                ? .init(symbol: "arrow.right", text: String(localized: "Direct, sans correspondance"))
                : .init(symbol: "arrow.triangle.swap", text: String(localized: "\(saved) correspondance(s) en moins")))
        } else if best.itinerary.transfers == 0, isFastest, best.itinerary.legs.contains(where: \.isTransit) {
            reasons.append(.init(symbol: "arrow.right", text: String(localized: "Direct, sans correspondance")))
        }

        let walkSaved = Int((fastest.features.walkMinutes - best.features.walkMinutes).rounded())
        if walkSaved >= 2 {
            let text: String
            if let weather = context.weather, weather.isWet {
                text = String(localized: "\(walkSaved) min de marche en moins sous la pluie")
            } else if let weather = context.weather, weather.isCold {
                text = String(localized: "\(walkSaved) min de marche en moins dans le froid")
            } else if let weather = context.weather, weather.isHot {
                text = String(localized: "\(walkSaved) min de marche en moins sous la chaleur")
            } else {
                text = String(localized: "\(walkSaved) min de marche en moins")
            }
            reasons.append(.init(symbol: context.weather?.isWet == true ? "umbrella.fill" : "figure.walk", text: text))
        }

        if let bestCrowd = best.features.crowdPeak {
            if let fastestCrowd = fastest.features.crowdPeak, fastestCrowd - bestCrowd >= 1 {
                reasons.append(.init(symbol: "person.2.fill", text: String(localized: "Moins de monde à bord")))
            } else if bestCrowd < 2.5, context.profile.crowd != .indifferent {
                reasons.append(.init(symbol: "chair.fill", text: String(localized: "Places assises signalées")))
            }
        }

        let margin = weights(for: context).margin
        if let bestSlack = best.features.tightestSlack, let fastestSlack = fastest.features.tightestSlack,
           fastestSlack < margin, bestSlack >= margin {
            reasons.append(.init(symbol: "checkmark.shield.fill", text: String(localized: "Correspondance moins serrée")))
        }

        if let line = best.features.habitLine {
            reasons.append(.init(symbol: "heart.fill", text: String(localized: "Votre ligne \(line)")))
        }

        if reasons.isEmpty {
            reasons.append(.init(symbol: "sparkles", text: String(localized: "Le meilleur compromis")))
        }
        return Array(reasons.prefix(3))
    }

    static func insight(for ranked: [RankedTrip], context: Context) -> TripSuggestion.Reason? {
        guard let best = ranked.first, let fastest = fastest(in: ranked),
              best.itinerary.intelligenceSignature != fastest.itinerary.intelligenceSignature else { return nil }
        return reasons(best: best, fastest: fastest, context: context).first
    }
}
