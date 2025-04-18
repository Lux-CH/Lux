//
//  LinePill.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct LinePill: View {
    var line: String
    
    var lineColor: Color {
        LineColors.color(for: line) ?? .black
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 50)
                .fill(Color(lineColor.opacity(0.25)))
                .frame(width: 30.1, height: 19)
        }
        Text(line)
            .font(.custom("NimbusSansBeckerPBla", size: 11))
            .foregroundColor(Color(lineColor))
            .multilineTextAlignment(.center)
    }
}
