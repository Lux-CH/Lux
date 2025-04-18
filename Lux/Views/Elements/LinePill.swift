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
                .frame(width: 30, height: 20)
            Text(line)
                .font(.custom("NimbusSansBeckerPBla", size: 11))
                .foregroundColor(lineColor)
                .multilineTextAlignment(.center)
        }

    }
}

struct MorePill: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 50)
                .fill(Color.accentColor.opacity(0.25))
                .frame(width: 30, height: 20)
            Image(systemName: "ellipsis")
                .foregroundColor(Color.accentColor)
                .multilineTextAlignment(.center)
                .font(.system(size: 11))
        }
    }
}

