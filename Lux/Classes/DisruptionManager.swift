//
//  DisruptionManager.swift
//  Lux
//
//  Created by Constantin Clerc on 27.05.2025.
//

import Foundation
import LuxCom

@MainActor
final class DisruptionManager: ObservableObject {
    @Published var disruptions: [Disruption] = []
    // Pushed by the relay WebSocket when the feed changes; the 1min HTTP poll
    // only runs while the socket is down.
    private let liveFeed = RelayLiveFeed<[Disruption]>()

    init() {
        Task {
            await fetchDisruptions()
        }
        liveFeed.start(
            fallbackInterval: .seconds(60),
            stream: {
                await RelayClient.shared.disruptions()
            },
            fallbackFetch: {
                try? await getDisruptions()
            },
            onUpdate: { [weak self] fetched in
                self?.disruptions = Array(Set(fetched))
            }
        )
    }

    func fetchDisruptions() async {
        do {
            let fetchedDisruptions = try await getDisruptions()
            self.disruptions = Array(Set(fetchedDisruptions))
        } catch {
            print(error)
        }
    }

    func disruptions(for leg: Leg) -> [Disruption] {
        let agencyId = leg.agencyId == "Transports Publics Genevois" ? "881" : leg.agencyId
        var result: [Disruption] = []
        if let line = leg.routeShortName, let agencyId {
            result += disruptions.filter { $0.line == line && ($0.agencyId ?? "881") == agencyId }
        }
        if let tripKey = Self.tripKey(leg.tripId) {
            result += disruptions.filter { $0.tripIds?.contains(tripKey) == true }
        }
        return result
    }

    private static func tripKey(_ tripId: String?) -> String? {
        guard let parts = tripId?.split(separator: "_", maxSplits: 3), parts.count == 4 else { return nil }
        return "\(parts[0])_\(parts[3])"
    }
}
