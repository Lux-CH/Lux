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
        guard let agencyId = leg.agencyId == "Transports Publics Genevois" ? "881" : leg.agencyId else { return [] }
        let line = leg.routeShortName ?? ""
        let tripKey = Self.tripKey(leg.tripId)
        let stations = Set(([leg.from, leg.to] + (leg.intermediateStops ?? [])).compactMap { Self.station($0.stopId ?? $0.parentId) })

        return disruptions.filter { disruption in
            guard (disruption.agencyId ?? "881") == agencyId,
                  disruption.isActive(from: leg.startTime, to: leg.endTime) else { return false }
            if !line.isEmpty && disruption.line == line { return true }
            if let tripKey, disruption.tripIds?.contains(tripKey) == true { return true }
            return disruption.stopIds?.contains(where: stations.contains) == true
        }
    }

    private static func tripKey(_ tripId: String?) -> String? {
        guard let parts = tripId?.split(separator: "_", maxSplits: 3), parts.count == 4 else { return nil }
        return "\(parts[0])_\(parts[3])"
    }

    private static func station(_ stopId: String?) -> String? {
        guard let stopId, let range = stopId.range(of: #"ch:1:sloid:\d+"#, options: .regularExpression) else { return nil }
        return String(stopId[range])
    }
}
