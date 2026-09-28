//
//  ConnectionService.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import Foundation

final class ConnectionService {
    static let shared = ConnectionService()

    private let extractor: ConnectionExtractor?

    private init() {
        do {
            self.extractor = try ConnectionExtractor()
        } catch {
            print(error)
            self.extractor = nil
        }
    }

    func getConnections(for stopId: String, completion: @escaping @MainActor ([StopConnection]) -> Void) {
        let cleanStopId = stopId
            .replacingOccurrences(of: "ch-opentransportdataswiss26", with: "ch")
            .replacingOccurrences(of: "ch_Parent", with: "ch_")

        Task(priority: .userInitiated) {
            let connections: [StopConnection]
            do {
                connections = try await extractor?.extractSpecificKey(cleanStopId) ?? []
            } catch {
                print("\(cleanStopId) \(error)")
                connections = []
            }
            let sortedConnections = await MainActor.run { sorted(connections) }
            await completion(sortedConnections)
        }
    }

    @MainActor
    private func sorted(_ connections: [StopConnection]) -> [StopConnection] {
        let order = LineScoreManager.shared.getSortedRouteNames(connections.map(\.line))
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return connections.sorted { (rank[$0.line] ?? .max) < (rank[$1.line] ?? .max) }
    }
}
