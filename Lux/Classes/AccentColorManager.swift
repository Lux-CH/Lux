//
//  AccentColorManager.swift
//  Lux
//
//  Created by Constantin Clerc on 30.05.2025.
//

import SwiftUI

class AccentColorManager: ObservableObject {
    static let shared = AccentColorManager()
    
    @AppStorage("selectedAccentColor") private var selectedColorName: String = "Orange Lux"
    
    let availableColors: [(name: String, color: Color)] = [
        ("Orange Lux", .orange),
        ("Bleu SBB CFF", Color(hex: "2d327d")),
        ("Rouge SBB CFF", Color(hex: "EB0000")),
        ("Orange TPG", Color(hex: "FC5412")),
        ("Vert CGTE", Color(hex: "2D8859")),
        ("Jaune Mouettes", .yellow),
        ("Rouge Grenat", Color(hex: "85142B")),
        ("Bleu Ice Tea", Color(hex: "3182DB")),
        ("Rose UNIGE", Color(hex: "D9005D")),
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
