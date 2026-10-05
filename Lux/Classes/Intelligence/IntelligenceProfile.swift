//
//  IntelligenceProfile.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import SwiftUI
import Combine

struct IntelligenceProfile: Codable, Equatable {
    enum Weather: String, Codable, CaseIterable {
        case indifferent, walkLess, avoidWalking
    }

    enum Directness: Int, Codable, CaseIterable {
        case never = 2, five = 5, ten = 10, fifteen = 15
    }

    enum Walking: String, Codable, CaseIterable {
        case enjoys, neutral, minimal
    }

    enum Crowd: String, Codable, CaseIterable {
        case indifferent, avoid, avoidStrongly
    }

    enum Margin: Int, Codable, CaseIterable {
        case tight = 0, comfortable = 3, generous = 6
    }

    var weather: Weather = .walkLess
    var directness: Directness = .five
    var walking: Walking = .neutral
    var crowd: Crowd = .avoid
    var margin: Margin = .comfortable
    var usesHabits = true
    var isConfigured = false
}

struct IntelligenceLearning: Codable, Equatable {
    var isEnabled = true
    var walk = 0.0
    var weather = 0.0
    var transfer = 0.0
    var margin = 0.0
    var crowd = 0.0
    var observations = 0
    var updatedAt: Date?

    static let limits: [WritableKeyPath<IntelligenceLearning, Double>: ClosedRange<Double>] = [
        \.walk: -0.3...0.7,
        \.weather: -0.6...1.2,
        \.transfer: -1.5...8,
        \.margin: -2...3,
        \.crowd: -2...3
    ]

    mutating func nudge(_ key: WritableKeyPath<IntelligenceLearning, Double>, by delta: Double) {
        guard let range = Self.limits[key] else { return }
        self[keyPath: key] = min(range.upperBound, max(range.lowerBound, self[keyPath: key] + delta))
    }

    func erased() -> IntelligenceLearning {
        IntelligenceLearning(isEnabled: isEnabled)
    }
}

final class IntelligenceStore: ObservableObject {
    static let shared = IntelligenceStore()

    @Published var profile: IntelligenceProfile {
        didSet { persist(profile, key: Self.profileKey) }
    }

    @Published var learning: IntelligenceLearning {
        didSet { persist(learning, key: Self.learningKey) }
    }

    @Published var departureAlerts: Bool {
        didSet { UserDefaults.standard.set(departureAlerts, forKey: Self.alertsKey) }
    }

    private static let profileKey = "intelligenceProfile"
    private static let learningKey = "intelligenceLearning"
    private static let alertsKey = "intelligenceDepartureAlerts"

    static var isIntelligentMode: Bool {
        (UserDefaults.standard.string(forKey: "routePreset") ?? "intelligent") == "intelligent"
    }

    private init() {
        let defaults = UserDefaults.standard
        profile = defaults.data(forKey: Self.profileKey).flatMap { try? JSONDecoder().decode(IntelligenceProfile.self, from: $0) } ?? IntelligenceProfile()
        learning = defaults.data(forKey: Self.learningKey).flatMap { try? JSONDecoder().decode(IntelligenceLearning.self, from: $0) } ?? IntelligenceLearning()
        departureAlerts = defaults.bool(forKey: Self.alertsKey)
    }

    func reset() {
        profile = IntelligenceProfile()
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct IntelligenceQuestion: Identifiable {
    struct Option: Identifiable {
        let id: String
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        let isSelected: (IntelligenceProfile) -> Bool
        let apply: (inout IntelligenceProfile) -> Void
    }

    let id: String
    let label: LocalizedStringKey
    let symbol: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let options: [Option]

    static let all: [IntelligenceQuestion] = [
        IntelligenceQuestion(
            id: "weather",
            label: "Météo",
            symbol: "cloud.rain.fill",
            title: "Quand il pleut ou qu'il fait très froid",
            subtitle: "Lux consulte la météo au départ de chaque recherche.",
            options: [
                Option(id: "indifferent", symbol: "figure.walk", title: "Je marche quand même", detail: "La météo ne change rien",
                       isSelected: { $0.weather == .indifferent }, apply: { $0.weather = .indifferent }),
                Option(id: "walkLess", symbol: "umbrella.fill", title: "Je préfère marcher moins", detail: "Quelques minutes de plus pour rester au sec",
                       isSelected: { $0.weather == .walkLess }, apply: { $0.weather = .walkLess }),
                Option(id: "avoidWalking", symbol: "cloud.heavyrain.fill", title: "J'évite de marcher au maximum", detail: "Même si le trajet est plus long",
                       isSelected: { $0.weather == .avoidWalking }, apply: { $0.weather = .avoidWalking })
            ]
        ),
        IntelligenceQuestion(
            id: "directness",
            label: "Correspondances",
            symbol: "arrow.triangle.swap",
            title: "Pour éviter une correspondance, vous attendriez",
            subtitle: "Un bus direct qui arrive un peu plus tard peut valoir le coup.",
            options: [
                Option(id: "never", symbol: "bolt.fill", title: "Pas du tout", detail: "Le plus rapide, peu importe les changements",
                       isSelected: { $0.directness == .never }, apply: { $0.directness = .never }),
                Option(id: "five", symbol: "clock", title: "Jusqu'à 5 minutes", detail: "Un petit détour pour rester assis",
                       isSelected: { $0.directness == .five }, apply: { $0.directness = .five }),
                Option(id: "ten", symbol: "clock.fill", title: "Jusqu'à 10 minutes", detail: "Je préfère nettement les trajets directs",
                       isSelected: { $0.directness == .ten }, apply: { $0.directness = .ten }),
                Option(id: "fifteen", symbol: "hourglass", title: "Jusqu'à 15 minutes", detail: "Les correspondances, très peu pour moi",
                       isSelected: { $0.directness == .fifteen }, apply: { $0.directness = .fifteen })
            ]
        ),
        IntelligenceQuestion(
            id: "walking",
            label: "Marche",
            symbol: "figure.walk",
            title: "La marche, pour vous, c'est",
            subtitle: "Par beau temps, sur les trajets à pied et les correspondances.",
            options: [
                Option(id: "enjoys", symbol: "figure.hiking", title: "Un plaisir", detail: "Marcher plutôt qu'attendre",
                       isSelected: { $0.walking == .enjoys }, apply: { $0.walking = .enjoys }),
                Option(id: "neutral", symbol: "figure.walk", title: "Un moyen comme un autre", detail: "Tant que ça reste raisonnable",
                       isSelected: { $0.walking == .neutral }, apply: { $0.walking = .neutral }),
                Option(id: "minimal", symbol: "figure.stand", title: "À limiter", detail: "Bagages, poussette ou simplement pas envie",
                       isSelected: { $0.walking == .minimal }, apply: { $0.walking = .minimal })
            ]
        ),
        IntelligenceQuestion(
            id: "crowd",
            label: "Affluence",
            symbol: "person.3.fill",
            title: "Face à un véhicule bondé",
            subtitle: "D'après les signalements des autres voyageurs Lux.",
            options: [
                Option(id: "indifferent", symbol: "person.3.fill", title: "Ça ne me dérange pas", detail: "Je monte quand même",
                       isSelected: { $0.crowd == .indifferent }, apply: { $0.crowd = .indifferent }),
                Option(id: "avoid", symbol: "person.2.fill", title: "J'évite si possible", detail: "À durée à peu près égale",
                       isSelected: { $0.crowd == .avoid }, apply: { $0.crowd = .avoid }),
                Option(id: "avoidStrongly", symbol: "person.fill", title: "J'attends le suivant", detail: "Une place assise avant tout",
                       isSelected: { $0.crowd == .avoidStrongly }, apply: { $0.crowd = .avoidStrongly })
            ]
        ),
        IntelligenceQuestion(
            id: "margin",
            label: "Marge",
            symbol: "arrow.triangle.2.circlepath",
            title: "En correspondance, il vous faut",
            subtitle: "Lux écarte les changements trop serrés pour vous.",
            options: [
                Option(id: "tight", symbol: "hare.fill", title: "Peu de marge", detail: "Je cours s'il le faut",
                       isSelected: { $0.margin == .tight }, apply: { $0.margin = .tight }),
                Option(id: "comfortable", symbol: "figure.walk", title: "Quelques minutes", detail: "Environ 3 minutes",
                       isSelected: { $0.margin == .comfortable }, apply: { $0.margin = .comfortable }),
                Option(id: "generous", symbol: "tortoise.fill", title: "Une marge large", detail: "Je ne cours jamais",
                       isSelected: { $0.margin == .generous }, apply: { $0.margin = .generous })
            ]
        ),
        IntelligenceQuestion(
            id: "habits",
            label: "Habitudes",
            symbol: "heart.fill",
            title: "Vos lignes habituelles",
            subtitle: "Lux apprend les lignes et directions que vous consultez le plus.",
            options: [
                Option(id: "yes", symbol: "heart.fill", title: "Les privilégier", detail: "À temps de trajet comparable",
                       isSelected: { $0.usesHabits }, apply: { $0.usesHabits = true }),
                Option(id: "no", symbol: "circle.dashed", title: "Peu importe", detail: "Seul le trajet compte",
                       isSelected: { !$0.usesHabits }, apply: { $0.usesHabits = false })
            ]
        )
    ]
}
