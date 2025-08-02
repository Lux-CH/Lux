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
    
    let availableColors: [(name: String, color: Color)] = [
        (String(localized: "Orange Lux"), .orange),
        (String(localized: "Bleu SBB CFF"), Color(hex: "2d327d")),
        (String(localized: "Rouge SBB CFF"), Color(hex: "EB0000")),
        (String(localized: "Orange TPG"), Color(hex: "FC5412")),
        (String(localized: "Vert CGTE"), Color(hex: "2D8859")),
        (String(localized: "Jaune Mouettes"), .yellow),
        (String(localized: "Rouge Grenat"), Color(hex: "85142B")),
        (String(localized: "Bleu Ice Tea"), Color(hex: "3182DB")),
        (String(localized: "Rose UNIGE"), Color(hex: "D9005D")),
    ]
    
    var selectedAccentColor: Color {
        availableColors.first(where: { $0.name == selectedColorName })?.color ?? .orange
    }
    
    func setAccentColor(_ color: Color) {
        if let colorData = availableColors.first(where: { $0.color == color }) {
            selectedColorName = colorData.name
        }
    }
}
