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
    // Pushed by the relay WebSocket when the feed changes; the 5min HTTP poll
    // only runs while the socket is down.
    private let liveFeed = RelayLiveFeed<[Disruption]>()

    init() {
        Task {
            await fetchDisruptions()
        }
        liveFeed.start(
            fallbackInterval: .seconds(300),
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

    func disruptions(for line: String) -> [Disruption] {
        disruptions.filter { $0.line == line }
    }
}
