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
        
        (String(localized: "Brun Jura"), Color(hex: "6B4423"), "SBB-Red"),
        (String(localized: "Rouille Marronds"), Color(hex: "954535"), "servette"),
        (String(localized: "Ocre Vignes"), Color(hex: "B8733E"), "tpg"),
        
        (String(localized: "Gris Alpes"), Color(hex: "7C8B99"), "SBB-Blue"),
        (String(localized: "Bleu Glacier"), Color(hex: "5B7C8D"), "leman"),
        (String(localized: "Blanc Neige"), Color(hex: "A5C9E1"), "leman"),
        
        (String(localized: "Rouge Fête"), Color(hex: "8B1E3F"), "servette"),
        (String(localized: "Vert Sapin"), Color(hex: "4A5D4F"), "cgte"),
        (String(localized: "Or Escalade"), Color(hex: "C4983C"), "mouette"),
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
