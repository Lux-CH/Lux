//
//  BikeMode.swift
//  Lux
//
//  Created by Constantin Clerc on 27.10.2026.
//

import SwiftUI
import LuxCom

enum BikeMode: String, CaseIterable, Identifiable {
    case off, own, shared

    static let storageKey = "routeOptionsBikeMode"
    static let onBoardStorageKey = "routeOptionsBikeOnBoard"
    static let speedStorageKey = "routeOptionsCyclingSpeed"
    static let defaultSpeed = 4.2

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .off: "Sans vélo"
        case .own: "Mon vélo"
        case .shared: "Vélo partagé"
        }
    }

    var chipTitle: LocalizedStringKey {
        switch self {
        case .off: "Vélo"
        case .own: "Mon vélo"
        case .shared: "Vélo partagé"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .off: "À pied entre les arrêts"
        case .own: "Itinéraires avec votre propre vélo"
        case .shared: "Donkey Republic"
        }
    }

    var symbol: String {
        switch self {
        case .off: "figure.walk"
        case .own: "bicycle"
        case .shared: "bicycle.circle"
        }
    }

    static var stored: BikeMode {
        BikeMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .off
    }

    static var storedOnBoard: Bool {
        UserDefaults.standard.object(forKey: onBoardStorageKey) as? Bool ?? true
    }

    static var storedSpeed: Double {
        let speed = UserDefaults.standard.double(forKey: speedStorageKey)
        return speed > 0 ? speed : defaultSpeed
    }

    func apply(to options: inout RouteOptions, onBoard: Bool, speed: Double = BikeMode.storedSpeed) {
        options.cyclingSpeed = self == .off || speed == Self.defaultSpeed ? nil : speed
        switch self {
        case .off:
            options.directModes = nil
            options.preTransitModes = nil
            options.postTransitModes = nil
            options.requireBikeTransport = false
        case .own:
            options.directModes = [.walk, .bike]
            options.preTransitModes = [.bike]
            options.postTransitModes = onBoard ? [.bike] : [.walk]
            options.requireBikeTransport = onBoard
        case .shared:
            options.directModes = [.walk, .rental]
            options.preTransitModes = [.walk, .rental]
            options.postTransitModes = [.walk, .rental]
            options.requireBikeTransport = false
        }
    }
}

extension Color {
    static let bikeLeg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.84, blue: 0.70, alpha: 1)
            : UIColor(red: 0.00, green: 0.64, blue: 0.52, alpha: 1)
    })
}

extension Leg {
    var bikeSymbol: String {
        rental?.isElectric == true ? "bicycle.circle.fill" : "bicycle"
    }
}
