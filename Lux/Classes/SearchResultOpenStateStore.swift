//
//  SearchResultOpenStateStore.swift
//  Lux
//
//  Created by Constantin Clerc on 28.06.2026.
//

import SwiftUI

enum POIOpenState: Sendable {
    case open(until: String?)
    case openAllDay
    case closingSoon(at: String?)
    case openingSoon(at: String?)
    case closed(opensAt: String?)
    case temporarilyClosed
    case permanentlyClosed

    var label: String {
        switch self {
        case .open(let until):
            return until.map { "Ouvert jusqu'à \($0)" } ?? "Ouvert"
        case .openAllDay:
            return "Ouvert 24/24"
        case .closingSoon(let at):
            return at.map { "Ferme bientôt (à \($0))" } ?? "Ferme bientôt"
        case .openingSoon(let at):
            return at.map { "Ouvre bientôt (à \($0))" } ?? "Ouvre bientôt"
        case .closed(let opensAt):
            return opensAt.map { "Fermé (ouvre à \($0))" } ?? "Fermé"
        case .temporarilyClosed:
            return "Temporairement fermé"
        case .permanentlyClosed:
            return "Définitivement fermé"
        }
    }

    var color: Color {
        switch self {
        case .open, .openAllDay:                         return .green
        case .closingSoon:                               return .orange
        case .openingSoon:                               return .yellow
        case .closed, .temporarilyClosed, .permanentlyClosed: return .red
        }
    }
}

@MainActor
final class SearchResultOpenStateStore: ObservableObject {
    static let shared = SearchResultOpenStateStore()

    @Published private var states: [String: POIOpenState] = [:]

    private init() {}

    func openState(for resultID: String) -> POIOpenState? {
        states[resultID]
    }

    func setOpenStates(_ newStates: [String: POIOpenState]) {
        guard !newStates.isEmpty else { return }
        for (id, state) in newStates {
            states[id] = state
        }
    }
}
