//
//  TrainFormation.swift
//  Lux
//
//  Created by Constantin Clerc on 24.09.2026.
//

import Foundation

/// Which coaches of a train stop in which platform sector, at one stop (SBB's train
/// formation service, through the relay: `sub_form`).
struct TrainFormation: Decodable, Sendable, Equatable {
    let train: String
    /// Track the formation is planned for; realtime may have moved the train since.
    let track: String?
    let sectors: Sectors
    /// In platform order.
    let coaches: [Coach]

    /// Sectors (sorted) where each thing a rider looks for is.
    struct Sectors: Decodable, Sendable, Equatable {
        let first: [String]
        let second: [String]
        let restaurant: [String]
        let bike: [String]
        let wheelchair: [String]
        let family: [String]
        let business: [String]
    }

    struct Coach: Decodable, Sendable, Equatable {
        /// Sector letter.
        let s: String?
        /// "1", "2", "12", "WR" / "W1" / "W2" (restaurant), "FA" (family), "LK" (locomotive), ...
        let t: String
        let n: String?
        /// bike, wheelchair, family, stroller, business, lowFloor
        let o: [String]
        let closed: Bool

        var isFirstClass: Bool { ["1", "12", "W1"].contains(t) }
        var isRestaurant: Bool { ["WR", "W1", "W2"].contains(t) }
        var isLocomotive: Bool { t == "LK" || t == "D" }
    }

    /// Sectors the train covers (stops alongside), in platform order.
    var coveredSectors: Set<String> {
        Set(coaches.filter { !$0.isLocomotive }.compactMap(\.s))
    }

    /// "E", "C–F", "B, D–E": sector letters with consecutive runs collapsed.
    static func sectorText(_ sectors: [String]) -> String {
        let letters = sectors.compactMap { $0.unicodeScalars.first?.value }.sorted()
        var runs: [(UInt32, UInt32)] = []
        for letter in letters {
            if let last = runs.last, letter == last.1 + 1 {
                runs[runs.count - 1].1 = letter
            } else {
                runs.append((letter, letter))
            }
        }
        return runs.map { run in
            let from = String(UnicodeScalar(run.0).map(Character.init) ?? " ")
            let to = String(UnicodeScalar(run.1).map(Character.init) ?? " ")
            return run.0 == run.1 ? from : "\(from)–\(to)"
        }.joined(separator: ", ")
    }
}
