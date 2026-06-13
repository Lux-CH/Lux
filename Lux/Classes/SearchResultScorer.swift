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
    private let proximityHalfDistance: CLLocationDistance = 4_000


    private static let tokenSynonyms: [String: String] = [
        "st": "saint", "ste": "sainte", "sts": "saints", "stes": "saintes",
        "av": "avenue", "ave": "avenue",
        "bd": "boulevard", "blvd": "boulevard",
        "rte": "route",
        "ch": "chemin",
        "mt": "mont",
    ]

    private let textWeight = 0.60
    private let proximityWeight = 0.25
    private let stopRelevanceWeight = 0.20

    func ranked(
        _ results: [SearchResult],
        query: String,
        userLocation: CLLocationCoordinate2D?
    ) -> [SearchResult] {
        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else {
            return results
        }

        let normalizedQuery = queryTokens.joined(separator: " ")
        let userCLLocation = userLocation.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }

        let scored = results.map { result -> (result: SearchResult, score: Double, distance: CLLocationDistance) in
            let textScore = textScore(
                for: result.name,
                queryTokens: queryTokens,
                normalizedQuery: normalizedQuery
            )
            let distance = distance(from: userCLLocation, to: result)
            let proximityScore = proximityScore(for: distance)

            var composite = textWeight * textScore + proximityWeight * proximityScore
            if result.type == .stop {
                composite += stopRelevanceWeight * textScore
            }

            return (result, composite, distance)
        }

        let sorted = scored.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }

            if lhs.result.type != rhs.result.type {
                return lhs.result.type == .stop
            }

            if lhs.distance != rhs.distance {
                return lhs.distance < rhs.distance
            }

            return lhs.result.name.localizedCaseInsensitiveCompare(rhs.result.name) == .orderedAscending
        }

        return sorted.map(\.result)
    }

    private func textScore(for name: String, queryTokens: [String], normalizedQuery: String) -> Double {
        let nameTokens = tokenize(name)
        guard !nameTokens.isEmpty else {
            return 0
        }

        let normalizedName = nameTokens.joined(separator: " ")

        if normalizedName == normalizedQuery {
            return 1.0
        }
        if normalizedName.hasPrefix(normalizedQuery) {
            return 0.95
        }
        if normalizedName.contains(normalizedQuery) {
            return 0.85
        }

        var matchTotal = 0.0
        for queryToken in queryTokens {
            var best = 0.0
            for nameToken in nameTokens {
                best = max(best, tokenSimilarity(query: queryToken, candidate: nameToken))
                if best == 1.0 {
                    break
                }
            }
            matchTotal += best
        }

        let coverageScore = matchTotal / Double(queryTokens.count)

        if let firstQueryToken = queryTokens.first,
           let firstNameToken = nameTokens.first,
           firstNameToken.hasPrefix(firstQueryToken) {
            return min(1.0, coverageScore + 0.05)
        }

        return coverageScore
    }

    private func tokenSimilarity(query: String, candidate: String) -> Double {
        if candidate == query {
            return 1.0
        }
        if candidate.hasPrefix(query) {
            return 0.9
        }
        if query.hasPrefix(candidate) {
            return 0.75
        }
        if candidate.contains(query) {
            return 0.6
        }
        return 0
    }

    private func proximityScore(for distance: CLLocationDistance) -> Double {
        guard distance < .greatestFiniteMagnitude else {
            return 0
        }
        return proximityHalfDistance / (proximityHalfDistance + distance)
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
