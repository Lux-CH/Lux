//
//  IntelligenceLearner.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import Foundation
import LuxCom

@MainActor
enum IntelligenceLearner {
    enum Signal: Double {
        case opened = 0.2
        case transferOption = 0.6
        case started = 1
    }

    private struct Session {
        let candidates: [Itinerary]
        let context: TripIntelligence.Context
        var credited: [String: Double] = [:]
    }

    private static var lastSearch: Session?

    static func remember(candidates: [Itinerary], context: TripIntelligence.Context) {
        guard !candidates.isEmpty else { return }
        lastSearch = Session(candidates: candidates, context: context)
    }

    static func forget() {
        lastSearch = nil
    }

    static func observe(_ chosen: Itinerary, signal: Signal) {
        guard var session = lastSearch else { return }
        let key = matchKey(chosen)
        guard let match = session.candidates.first(where: { matchKey($0) == key }) else { return }
        let already = session.credited[key] ?? 0
        let strength = min(1, already + signal.rawValue) - already
        guard strength > 0 else { return }
        session.credited[key] = already + strength
        lastSearch = session
        learn(chosen: match, among: session.candidates, context: session.context, strength: strength)
    }

    private static func matchKey(_ itinerary: Itinerary) -> String {
        let trips = itinerary.legs.compactMap(\.tripId)
        return trips.isEmpty ? itinerary.intelligenceSignature : trips.joined(separator: ",")
    }

    static func observe(_ chosen: Itinerary, among alternatives: [Itinerary], context: TripIntelligence.Context, signal: Signal) {
        learn(chosen: chosen, among: alternatives + [chosen], context: context, strength: signal.rawValue)
    }

    private static func learn(chosen: Itinerary, among candidates: [Itinerary], context: TripIntelligence.Context, strength: Double) {
        let store = IntelligenceStore.shared
        guard store.learning.isEnabled, candidates.count > 1 else { return }

        let ranked = TripIntelligence.rank(candidates, context: context)
        guard let pick = ranked.first else { return }
        let signature = chosen.intelligenceSignature
        guard pick.itinerary.intelligenceSignature != signature,
              let mine = ranked.first(where: { $0.itinerary.intelligenceSignature == signature }) else { return }

        let timingGap = context.arriveBy
            ? pick.itinerary.startTime.timeIntervalSince(mine.itinerary.startTime)
            : mine.itinerary.startTime.timeIntervalSince(pick.itinerary.startTime)
        guard timingGap < 10 * 60 else { return }

        func pull(_ chosenValue: Double, _ pickedValue: Double, scale: Double) -> Double {
            max(-1, min(1, (chosenValue - pickedValue) / scale))
        }

        var learning = store.learning
        let harsh = context.weather?.isHarsh == true
        let walkDelta = pull(mine.features.walkMinutes, pick.features.walkMinutes, scale: 5)
        if harsh {
            learning.nudge(\.weather, by: -0.04 * strength * walkDelta)
        } else {
            learning.nudge(\.walk, by: -0.02 * strength * walkDelta)
        }

        learning.nudge(\.transfer, by: -0.3 * strength * pull(Double(mine.features.transfers), Double(pick.features.transfers), scale: 1))

        func shortfall(_ slack: Double?) -> Double { max(0, 6 - (slack ?? 6)) }
        learning.nudge(\.margin, by: -0.15 * strength * pull(shortfall(mine.features.tightestSlack), shortfall(pick.features.tightestSlack), scale: 3))

        if let mineCrowd = mine.features.crowdPeak, let pickCrowd = pick.features.crowdPeak {
            learning.nudge(\.crowd, by: -0.1 * strength * pull(max(0, mineCrowd - 2.5), max(0, pickCrowd - 2.5), scale: 1.5))
        }

        learning.observations += 1
        learning.updatedAt = Date()
        store.learning = learning
    }

    static func summary(of learning: IntelligenceLearning) -> [TripSuggestion.Reason] {
        var lines: [TripSuggestion.Reason] = []
        if learning.transfer > 1.5 {
            lines.append(.init(symbol: "arrow.right", text: String(localized: "Vous attendez volontiers un trajet direct")))
        } else if learning.transfer < -1 {
            lines.append(.init(symbol: "arrow.triangle.swap", text: String(localized: "Les correspondances vous gênent peu")))
        }
        if learning.walk > 0.15 {
            lines.append(.init(symbol: "figure.stand", text: String(localized: "Vous préférez marcher moins")))
        } else if learning.walk < -0.15 {
            lines.append(.init(symbol: "figure.walk", text: String(localized: "La marche ne vous dérange pas")))
        }
        if learning.weather > 0.3 {
            lines.append(.init(symbol: "umbrella.fill", text: String(localized: "Par mauvais temps, vous évitez la marche")))
        } else if learning.weather < -0.3 {
            lines.append(.init(symbol: "cloud.rain.fill", text: String(localized: "La pluie ne vous arrête pas")))
        }
        if learning.margin > 1 {
            lines.append(.init(symbol: "tortoise.fill", text: String(localized: "Vous aimez les correspondances larges")))
        } else if learning.margin < -1 {
            lines.append(.init(symbol: "hare.fill", text: String(localized: "Les correspondances serrées ne vous font pas peur")))
        }
        if learning.crowd > 1 {
            lines.append(.init(symbol: "person.fill", text: String(localized: "Vous évitez les véhicules bondés")))
        } else if learning.crowd < -1 {
            lines.append(.init(symbol: "person.3.fill", text: String(localized: "L'affluence ne vous dérange pas")))
        }
        return lines
    }
}
