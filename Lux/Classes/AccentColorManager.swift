//
//  AccentColorManager.swift
//  Lux
//
//  Created by Constantin Clerc on 30.05.2025.
//

import SwiftUI

class AccentColorManager: ObservableObject {
    static let shared = AccentColorManager()
    
    @AppStorage("selectedAccentColor") private var selectedColorName: String = String(localized: "Orange Lux")
    
    let availableColors: [(name: String, color: Color, iconName: String?)] = [
        (String(localized: "Rouge SBB CFF"), Color(hex: "EB0000"), "SBB-Red"),
        (String(localized: "Rouge Grenat"), Color(hex: "85142B"), "servette"),
        (String(localized: "Rose UNIGE"), Color(hex: "D9005D"), "unige"),
        (String(localized: "Orange TPG"), Color(hex: "FC5412"), "tpg"),
        (String(localized: "Orange Lux"), .orange, nil),
        (String(localized: "Jaune Mouettes"), .yellow, "mouette"),
        (String(localized: "Vert Vaudoise"), .green, "vaudoise"),
        (String(localized: "Vert CGTE"), Color(hex: "2D8859"), "cgte"),
        (String(localized: "Bleu Léman"), Color(hex: "2EFEDA"), "leman"),
        (String(localized: "Bleu Ice Tea"), Color(hex: "3182DB"), "icetea"),
        (String(localized: "Bleu SBB CFF"), Color(hex: "2d327d"), "SBB-Blue"),
        (String(localized: "Violet SCNF"), .indigo, "sncf"),

    ]
    
    var selectedAccentColor: Color {
        availableColors.first(where: { $0.name == selectedColorName })?.color ?? .orange
    }
    
    func setAccentColor(_ color: Color) {
        if let colorData = availableColors.first(where: { $0.color == color }) {
            selectedColorName = colorData.name
            UIApplication.shared.setAlternateIconName(colorData.iconName)
        }
    }
}
