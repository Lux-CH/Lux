//
//  SearchResultScorer.swift
//  Lux
//
//  Created by Constantin Clerc on 13.06.2026.
//
//  was actually super interesting to implement

import Foundation
import CoreLocation
import LuxCom

struct SearchResultScorer {
    private static let tokenSynonyms: [String: String] = [
        "st": "saint", "ste": "sainte", "sts": "saints", "stes": "saintes",
        "av": "avenue", "ave": "avenue",
        "bd": "boulevard", "blvd": "boulevard",
        "rte": "route",
        "ch": "chemin",
        "mt": "mont",
    ]

    private let textWeight = 0.55
    private let proximityWeight = 0.30
    private let sourceRankWeight = 0.15
    private let stopWeight = 0.08
    private let proximityHorizonKilometers = 300.0
    private let unknownPlaceProximity = 0.3

    func ranked(
        _ sources: [[SearchResult]],
        query: String,
        userLocation: CLLocationCoordinate2D?
    ) -> [SearchResult] {
        let entries = sources.flatMap { source in
            source.enumerated().map { (result: $0.element, sourceRank: $0.offset) }
        }

        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else {
            return entries.map(\.result)
        }

        let userCLLocation = userLocation.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }

        let scored = entries.map { entry -> (result: SearchResult, score: Double, distance: CLLocationDistance) in
            let textScore = textScore(for: entry.result, queryTokens: queryTokens)
            let distance = distance(from: userCLLocation, to: entry.result)
            let proximityScore = proximityScore(for: distance, hasUserLocation: userCLLocation != nil)

            var composite = textWeight * textScore
                + proximityWeight * proximityScore
                + sourceRankWeight * sourceRankScore(for: entry.sourceRank)
            if entry.result.type == .stop {
                composite += stopWeight * textScore
            }

            return (entry.result, composite, distance)
        }

        let sorted = scored.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }

            if lhs.distance != rhs.distance {
                return lhs.distance < rhs.distance
            }

            return lhs.result.name.localizedCaseInsensitiveCompare(rhs.result.name) == .orderedAscending
        }

        return sorted.map(\.result)
    }

    private func textScore(for result: SearchResult, queryTokens: [String]) -> Double {
        let nameTokens = tokenize(result.name)
        guard !nameTokens.isEmpty else {
            return 0
        }

        let localNameTokens = localNameTokens(for: result, nameTokens: nameTokens)
        let phraseScore = max(
            phraseScore(candidate: localNameTokens, queryTokens: queryTokens),
            phraseScore(candidate: nameTokens, queryTokens: queryTokens)
        )

        let areaTokens = Set(result.areas.flatMap { tokenize($0.name) })
        var matchTotal = 0.0
        for queryToken in queryTokens {
            let nameMatch = nameTokens.map { tokenSimilarity(query: queryToken, candidate: $0) }.max() ?? 0
            let areaMatch = areaTokens.map { tokenSimilarity(query: queryToken, candidate: $0) }.max() ?? 0
            matchTotal += max(nameMatch, 0.9 * areaMatch)
        }
        let coverageScore = 0.85 * matchTotal / Double(queryTokens.count)

        return max(phraseScore, coverageScore)
    }

    private func localNameTokens(for result: SearchResult, nameTokens: [String]) -> [String] {
        if let commaIndex = result.name.firstIndex(of: ",") {
            let localTokens = tokenize(String(result.name[result.name.index(after: commaIndex)...]))
            if !localTokens.isEmpty {
                return localTokens
            }
        }

        for area in result.areas {
            let areaTokens = tokenize(area.name)
            if !areaTokens.isEmpty, nameTokens.count > areaTokens.count, nameTokens.starts(with: areaTokens) {
                return Array(nameTokens.dropFirst(areaTokens.count))
            }
        }

        return nameTokens
    }

    private func phraseScore(candidate: [String], queryTokens: [String]) -> Double {
        guard !candidate.isEmpty else {
            return 0
        }

        let candidatePhrase = candidate.joined(separator: " ")
        let queryPhrase = queryTokens.joined(separator: " ")

        if candidatePhrase == queryPhrase {
            return 1.0
        }
        if candidatePhrase.hasPrefix(queryPhrase) {
            return 0.95
        }
        if (" " + candidatePhrase).contains(" " + queryPhrase) {
            return 0.85
        }
        return 0
    }

    private func tokenSimilarity(query: String, candidate: String) -> Double {
        if candidate == query {
            return 1.0
        }
        if candidate.hasPrefix(query) {
            return query.count >= 2 ? 0.9 : 0.5
        }
        return 0
    }

    private func proximityScore(for distance: CLLocationDistance, hasUserLocation: Bool) -> Double {
        guard hasUserLocation else {
            return 0
        }
        guard distance < .greatestFiniteMagnitude else {
            return unknownPlaceProximity
        }

        let kilometers = distance / 1_000
        return max(0, 1 - log10(1 + kilometers) / log10(1 + proximityHorizonKilometers))
    }

    private func sourceRankScore(for rank: Int) -> Double {
        1 / (1 + 0.35 * Double(rank))
    }

    private func distance(from userLocation: CLLocation?, to result: SearchResult) -> CLLocationDistance {
        guard let userLocation else {
            return .greatestFiniteMagnitude
        }

        let coordinate = CLLocationCoordinate2D(latitude: result.lat, longitude: result.lon)
        if !CLLocationCoordinate2DIsValid(coordinate) || (result.lat == 0.0 && result.lon == 0.0) {
            return .greatestFiniteMagnitude
        }

        let resultLocation = CLLocation(latitude: result.lat, longitude: result.lon)
        return userLocation.distance(from: resultLocation)
    }

    private func tokenize(_ text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        var tokens: [String] = []
        var current = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.append(scalar)
            } else if !current.isEmpty {
                tokens.append(canonical(String(current)))
                current = String.UnicodeScalarView()
            }
        }
        if !current.isEmpty {
            tokens.append(canonical(String(current)))
        }
        return tokens
    }

    private func canonical(_ token: String) -> String {
        Self.tokenSynonyms[token] ?? token
    }
}
