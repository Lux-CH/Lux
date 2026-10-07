//
//  AccentColorManager.swift
//  Lux
//
//  Created by Constantin Clerc on 30.05.2025.
//

import SwiftUI
import Observation

@Observable
final class AccentColorManager {
    struct AccentColorOption: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let color: Color
        let iconName: String?
        let isVisibleInPicker: Bool

        var name: String { String(localized: title) }
    }

    static let shared = AccentColorManager()

    private static let storageKey = "accentColorID"
    private static let legacyStorageKey = "selectedAccentColor"
    private static let defaultID = "lux-orange"

    private static let allColors: [AccentColorOption] = [
        AccentColorOption(id: "sbb-red", title: "Rouge SBB CFF", color: Color(hex: "EB0000"), iconName: "SBB-Red", isVisibleInPicker: true),
        AccentColorOption(id: "garnet-red", title: "Rouge Grenat", color: Color(hex: "85142B"), iconName: "servette", isVisibleInPicker: true),
        AccentColorOption(id: "unige-pink", title: "Rose UNIGE", color: Color(hex: "D9005D"), iconName: "unige", isVisibleInPicker: true),
        AccentColorOption(id: "tpg-orange", title: "Orange TPG", color: Color(hex: "FC5412"), iconName: "tpg", isVisibleInPicker: true),
        AccentColorOption(id: "lux-orange", title: "Orange Lux", color: .orange, iconName: nil, isVisibleInPicker: true),
        AccentColorOption(id: "mouettes-yellow", title: "Jaune Mouettes", color: .yellow, iconName: "mouette", isVisibleInPicker: true),
        AccentColorOption(id: "vaudoise-green", title: "Vert Vaudoise", color: .green, iconName: "vaudoise", isVisibleInPicker: true),
        AccentColorOption(id: "cgte-green", title: "Vert CGTE", color: Color(hex: "2D8859"), iconName: "cgte", isVisibleInPicker: true),
        AccentColorOption(id: "leman-blue", title: "Bleu Léman", color: Color(hex: "2EFEDA"), iconName: "leman", isVisibleInPicker: true),
        AccentColorOption(id: "ice-tea-blue", title: "Bleu Ice Tea", color: Color(hex: "3182DB"), iconName: "icetea", isVisibleInPicker: true),
        AccentColorOption(id: "sbb-blue", title: "Bleu SBB CFF", color: Color(hex: "2d327d"), iconName: "SBB-Blue", isVisibleInPicker: true),
        AccentColorOption(id: "sncf-violet", title: "Violet SCNF", color: .indigo, iconName: "sncf", isVisibleInPicker: true),

        AccentColorOption(id: "pastel-green", title: "Vert Pastel", color: Color(hex: "A8E6CF"), iconName: "vaudoise", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-blue", title: "Bleu Pastel", color: Color(hex: "A7D8FF"), iconName: "leman", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-lavender", title: "Lavande Pastel", color: Color(hex: "CBB9F7"), iconName: "sncf", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-rose", title: "Rose Pastel", color: Color(hex: "F7BDD8"), iconName: "unige", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-peach", title: "Pêche Pastel", color: Color(hex: "FFC8A8"), iconName: "tpg-orange", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-mimosa", title: "Mimosa Pastel", color: Color(hex: "F8E7A2"), iconName: "mouette", isVisibleInPicker: true),

        AccentColorOption(id: "jura-brown", title: "Brun Jura", color: Color(hex: "6B4423"), iconName: "SBB-Red", isVisibleInPicker: false),
        AccentColorOption(id: "rust-brown", title: "Rouille Marronds", color: Color(hex: "954535"), iconName: "servette", isVisibleInPicker: false),
        AccentColorOption(id: "vignes-ocre", title: "Ocre Vignes", color: Color(hex: "B8733E"), iconName: "tpg", isVisibleInPicker: false),
        AccentColorOption(id: "alps-gray", title: "Gris Alpes", color: Color(hex: "7C8B99"), iconName: "SBB-Blue", isVisibleInPicker: false),
        AccentColorOption(id: "glacier-blue", title: "Bleu Glacier", color: Color(hex: "5B7C8D"), iconName: "leman", isVisibleInPicker: false),
        AccentColorOption(id: "snow-white", title: "Blanc Neige", color: Color(hex: "A5C9E1"), iconName: "leman", isVisibleInPicker: false),
        AccentColorOption(id: "festive-red", title: "Rouge Fête", color: Color(hex: "8B1E3F"), iconName: "servette", isVisibleInPicker: false),
        AccentColorOption(id: "fir-green", title: "Vert Sapin", color: Color(hex: "4A5D4F"), iconName: "cgte", isVisibleInPicker: false),
        AccentColorOption(id: "escalade-gold", title: "Or Escalade", color: Color(hex: "C4983C"), iconName: "mouette", isVisibleInPicker: false),
    ]

    private(set) var selectedID: String
    private(set) var selectedAccentColor: Color

    let availableColors = AccentColorManager.allColors.filter(\.isVisibleInPicker)

    private init() {
        let defaults = UserDefaults.standard
        let storedID = defaults.string(forKey: Self.storageKey) ?? Self.migrateLegacySelection(in: defaults)
        let option = Self.allColors.first { $0.id == storedID } ?? Self.allColors.first { $0.id == Self.defaultID }!
        selectedID = option.id
        selectedAccentColor = option.color
    }

    func setAccentColor(_ option: AccentColorOption) {
        guard option.id != selectedID else { return }
        selectedID = option.id
        selectedAccentColor = option.color
        UserDefaults.standard.set(option.id, forKey: Self.storageKey)
        UIApplication.shared.setAlternateIconName(option.iconName)
    }

    private static func migrateLegacySelection(in defaults: UserDefaults) -> String? {
        guard let legacyName = defaults.string(forKey: legacyStorageKey) else { return nil }
        let match = allColors.first { option in
            var englishTitle = option.title
            englishTitle.locale = Locale(identifier: "en")
            return [option.title.key, option.name, String(localized: englishTitle)].contains(legacyName)
        }
        guard let match else { return nil }
        defaults.set(match.id, forKey: storageKey)
        return match.id
    }
}

extension Color {
    static var luxAccent: Color { AccentColorManager.shared.selectedAccentColor }
}

private struct LuxAccentTint: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(Color.luxAccent)
            // i am fully aware this will deprecated in the future; however not putting it doesn't apply the accent everywhere; same if you only leave accentColor
            .accentColor(Color.luxAccent)
    }
}

extension View {
    func luxAccentTint() -> some View {
        modifier(LuxAccentTint())
    }
}
