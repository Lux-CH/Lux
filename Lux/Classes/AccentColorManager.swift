//
//  AccentColorManager.swift
//  Lux
//
//  Created by Constantin Clerc on 30.05.2025.
//

import SwiftUI

class AccentColorManager: ObservableObject {
    struct AccentColorOption: Identifiable {
        let id: String
        let name: String
        let color: Color
        let iconName: String?
        let isVisibleInPicker: Bool
    }
    
    static let shared = AccentColorManager()
    
    @AppStorage("selectedAccentColor") private var selectedColorName: String = String(localized: "Orange Lux")
    
    private let allColors: [AccentColorOption] = [
        // Permanent collection
        AccentColorOption(id: "sbb-red", name: String(localized: "Rouge SBB CFF"), color: Color(hex: "EB0000"), iconName: "SBB-Red", isVisibleInPicker: true),
        AccentColorOption(id: "garnet-red", name: String(localized: "Rouge Grenat"), color: Color(hex: "85142B"), iconName: "servette", isVisibleInPicker: true),
        AccentColorOption(id: "unige-pink", name: String(localized: "Rose UNIGE"), color: Color(hex: "D9005D"), iconName: "unige", isVisibleInPicker: true),
        AccentColorOption(id: "tpg-orange", name: String(localized: "Orange TPG"), color: Color(hex: "FC5412"), iconName: "tpg", isVisibleInPicker: true),
        AccentColorOption(id: "lux-orange", name: String(localized: "Orange Lux"), color: .orange, iconName: nil, isVisibleInPicker: true),
        AccentColorOption(id: "mouettes-yellow", name: String(localized: "Jaune Mouettes"), color: .yellow, iconName: "mouette", isVisibleInPicker: true),
        AccentColorOption(id: "vaudoise-green", name: String(localized: "Vert Vaudoise"), color: .green, iconName: "vaudoise", isVisibleInPicker: true),
        AccentColorOption(id: "cgte-green", name: String(localized: "Vert CGTE"), color: Color(hex: "2D8859"), iconName: "cgte", isVisibleInPicker: true),
        AccentColorOption(id: "leman-blue", name: String(localized: "Bleu Léman"), color: Color(hex: "2EFEDA"), iconName: "leman", isVisibleInPicker: true),
        AccentColorOption(id: "ice-tea-blue", name: String(localized: "Bleu Ice Tea"), color: Color(hex: "3182DB"), iconName: "icetea", isVisibleInPicker: true),
        AccentColorOption(id: "sbb-blue", name: String(localized: "Bleu SBB CFF"), color: Color(hex: "2d327d"), iconName: "SBB-Blue", isVisibleInPicker: true),
        AccentColorOption(id: "sncf-violet", name: String(localized: "Violet SCNF"), color: .indigo, iconName: "sncf", isVisibleInPicker: true),
        
        // Spring pastel collection
        AccentColorOption(id: "pastel-green", name: String(localized: "Vert Pastel"), color: Color(hex: "A8E6CF"), iconName: "vaudoise", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-blue", name: String(localized: "Bleu Pastel"), color: Color(hex: "A7D8FF"), iconName: "leman", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-lavender", name: String(localized: "Lavande Pastel"), color: Color(hex: "CBB9F7"), iconName: "sncf", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-rose", name: String(localized: "Rose Pastel"), color: Color(hex: "F7BDD8"), iconName: "unige", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-peach", name: String(localized: "Pêche Pastel"), color: Color(hex: "FFC8A8"), iconName: "tpg-orange", isVisibleInPicker: true),
        AccentColorOption(id: "pastel-mimosa", name: String(localized: "Mimosa Pastel"), color: Color(hex: "F8E7A2"), iconName: "mouette", isVisibleInPicker: true),
        
        // legacy seasonal colors
        AccentColorOption(id: "jura-brown", name: String(localized: "Brun Jura"), color: Color(hex: "6B4423"), iconName: "SBB-Red", isVisibleInPicker: false),
        AccentColorOption(id: "rust-brown", name: String(localized: "Rouille Marronds"), color: Color(hex: "954535"), iconName: "servette", isVisibleInPicker: false),
        AccentColorOption(id: "vignes-ocre", name: String(localized: "Ocre Vignes"), color: Color(hex: "B8733E"), iconName: "tpg", isVisibleInPicker: false),
        AccentColorOption(id: "alps-gray", name: String(localized: "Gris Alpes"), color: Color(hex: "7C8B99"), iconName: "SBB-Blue", isVisibleInPicker: false),
        AccentColorOption(id: "glacier-blue", name: String(localized: "Bleu Glacier"), color: Color(hex: "5B7C8D"), iconName: "leman", isVisibleInPicker: false),
        AccentColorOption(id: "snow-white", name: String(localized: "Blanc Neige"), color: Color(hex: "A5C9E1"), iconName: "leman", isVisibleInPicker: false),
        AccentColorOption(id: "festive-red", name: String(localized: "Rouge Fête"), color: Color(hex: "8B1E3F"), iconName: "servette", isVisibleInPicker: false),
        AccentColorOption(id: "fir-green", name: String(localized: "Vert Sapin"), color: Color(hex: "4A5D4F"), iconName: "cgte", isVisibleInPicker: false),
        AccentColorOption(id: "escalade-gold", name: String(localized: "Or Escalade"), color: Color(hex: "C4983C"), iconName: "mouette", isVisibleInPicker: false),
    ]
    
    var availableColors: [AccentColorOption] {
        allColors.filter(\.isVisibleInPicker)
    }
    
    var selectedAccentColor: Color {
        allColors.first(where: { $0.name == selectedColorName })?.color ?? .orange
    }
    
    func setAccentColor(_ color: Color) {
        if let colorData = availableColors.first(where: { $0.color == color }) {
            selectedColorName = colorData.name
            UIApplication.shared.setAlternateIconName(colorData.iconName)
        }
    }
}
