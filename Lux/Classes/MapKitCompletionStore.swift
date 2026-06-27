//
//  MapKitCompletionStore.swift
//  Lux
//
//  Created by Constantin Clerc on 27.06.2026.
//

import Foundation
import MapKit

@MainActor
final class MapKitCompletionStore {
    static let shared = MapKitCompletionStore()

    private var completionsByID: [String: MKLocalSearchCompletion] = [:]
    private let maxEntries = 60

    private init() {}

    func setCompletions(_ completions: [String: MKLocalSearchCompletion]) {
        for (id, completion) in completions {
            completionsByID[id] = completion
        }

        if completionsByID.count > maxEntries {
            completionsByID.removeAll(keepingCapacity: true)
            for (id, completion) in completions {
                completionsByID[id] = completion
            }
        }
    }

    func completion(for id: String) -> MKLocalSearchCompletion? {
        completionsByID[id]
    }
}
