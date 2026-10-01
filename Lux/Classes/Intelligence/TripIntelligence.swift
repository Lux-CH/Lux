//
//  TripIntelligence.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import Foundation
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

    static func == (lhs: TripSuggestion, rhs: TripSuggestion) -> Bool {
        lhs.itinerary.intelligenceSignature == rhs.itinerary.intelligenceSignature && lhs.reasons == rhs.reasons && lhs.weather == rhs.weather
    }
}

extension Itinerary {
    var intelligenceSignature: String {
        let legs = legs.map { $0.tripId ?? "\($0.mode.rawValue)\(Int($0.startTime.timeIntervalSince1970))" }.joined(separator: ",")
        return "\(Int(startTime.timeIntervalSince1970))|\(Int(endTime.timeIntervalSince1970))|\(legs)"
    }
}

enum TripIntelligence {
    struct Context {
        let profile: IntelligenceProfile
        let weather: WeatherSnapshot?
        let arriveBy: Bool
        let crowd: [String: Double]
    }

    private struct Metrics {
        let itinerary: Itinerary
        let walkMinutes: Double
        let outdoorWaitMinutes: Double
        let tightestSlack: Double?
        let crowdPeak: Double?
        let habitLine: String?
        let habitScore: Double
    }

    static func needsDirectSearch(_ profile: IntelligenceProfile, maxTransfers: Int) -> Bool {
        profile.directness != .never && maxTransfers > 0
    }

    static func needsLessWalkingSearch(_ profile: IntelligenceProfile, weather: WeatherSnapshot?) -> Bool {
        if profile.walking == .minimal { return true }
        guard let weather, weather.isHarsh else { return false }
        return profile.weather != .indifferent
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

    static func suggest(from candidates: [Itinerary], context: Context) -> TripSuggestion? {
        let unique = Dictionary(candidates.map { ($0.intelligenceSignature, $0) }, uniquingKeysWith: { first, _ in first }).values
        let upcoming = unique.filter { context.arriveBy || $0.startTime > Date().addingTimeInterval(-60) }
        guard !upcoming.isEmpty else { return nil }

        let metrics = upcoming.map { metrics(for: $0, context: context) }
        let earliestEnd = upcoming.map(\.endTime).min()!
        let latestStart = upcoming.map(\.startTime).max()!

        func baseMinutes(_ itinerary: Itinerary) -> Double {
            context.arriveBy
                ? latestStart.timeIntervalSince(itinerary.startTime) / 60
                : itinerary.endTime.timeIntervalSince(earliestEnd) / 60
        }

        let scored = metrics.map { ($0, baseMinutes($0.itinerary) + cost($0, context: context)) }
        guard let best = scored.min(by: { $0.1 < $1.1 || ($0.1 == $1.1 && $0.0.itinerary.startTime < $1.0.itinerary.startTime) })?.0,
              let fastest = metrics.min(by: { baseMinutes($0.itinerary) < baseMinutes($1.itinerary) || (baseMinutes($0.itinerary) == baseMinutes($1.itinerary) && $0.itinerary.transfers < $1.itinerary.transfers) }) else { return nil }

        let minutesLater = Int((baseMinutes(best.itinerary) - baseMinutes(fastest.itinerary)).rounded())
        return TripSuggestion(
            itinerary: best.itinerary,
            reasons: reasons(best: best, fastest: fastest, context: context),
            weather: context.weather,
            minutesLater: max(0, minutesLater)
        )
    }

    private static func metrics(for itinerary: Itinerary, context: Context) -> Metrics {
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

        return Metrics(
            itinerary: itinerary,
            walkMinutes: walkMinutes,
            outdoorWaitMinutes: outdoorWait,
            tightestSlack: tightest,
            crowdPeak: crowdPeak,
            habitLine: habitLine,
            habitScore: min(habitScore, 4)
        )
    }

    private static func weatherWeight(_ context: Context) -> Double {
        guard let weather = context.weather, weather.isHarsh else { return 0 }
        let weight: Double = switch context.profile.weather {
        case .indifferent: 0
        case .walkLess: 0.8
        case .avoidWalking: 2
        }
        return weather.isWet ? weight : weight / 2
    }

    private static func cost(_ metrics: Metrics, context: Context) -> Double {
        let profile = context.profile
        let walkWeight: Double = switch profile.walking {
        case .enjoys: 0
        case .neutral: 0.3
        case .minimal: 1
        }
        let weather = weatherWeight(context)

        var cost = metrics.walkMinutes * (walkWeight + weather)
        cost += metrics.outdoorWaitMinutes * weather * 0.4
        cost += Double(metrics.itinerary.transfers) * Double(profile.directness.rawValue)

        if let slack = metrics.tightestSlack {
            let margin = Double(profile.margin.rawValue)
            if slack < margin { cost += (margin - slack) * 1.5 }
            if slack < 1 { cost += 2 }
        }

        if let crowd = metrics.crowdPeak {
            let crowdWeight: Double = switch profile.crowd {
            case .indifferent: 0
            case .avoid: 2.5
            case .avoidStrongly: 6
            }
            cost += max(0, crowd - 2.5) * crowdWeight
        }

        cost -= metrics.habitScore
        return cost
    }

    private static func reasons(best: Metrics, fastest: Metrics, context: Context) -> [TripSuggestion.Reason] {
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

        let walkSaved = Int((fastest.walkMinutes - best.walkMinutes).rounded())
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

        if let bestCrowd = best.crowdPeak {
            if let fastestCrowd = fastest.crowdPeak, fastestCrowd - bestCrowd >= 1 {
                reasons.append(.init(symbol: "person.2.fill", text: String(localized: "Moins de monde à bord")))
            } else if bestCrowd < 2.5, context.profile.crowd != .indifferent {
                reasons.append(.init(symbol: "chair.fill", text: String(localized: "Places assises signalées")))
            }
        }

        let margin = Double(context.profile.margin.rawValue)
        if let bestSlack = best.tightestSlack, let fastestSlack = fastest.tightestSlack,
           fastestSlack < margin, bestSlack >= margin {
            reasons.append(.init(symbol: "checkmark.shield.fill", text: String(localized: "Correspondance moins serrée")))
        }

        if let line = best.habitLine {
            reasons.append(.init(symbol: "heart.fill", text: String(localized: "Votre ligne \(line)")))
        }

        if reasons.isEmpty {
            reasons.append(.init(symbol: "sparkles", text: String(localized: "Le meilleur compromis")))
        }
        return Array(reasons.prefix(3))
    }
}
