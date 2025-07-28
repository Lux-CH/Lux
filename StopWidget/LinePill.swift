//
//  LinePill.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct LinePill: View {
    let line: String
    let mode: TransportationMode
    var width: CGFloat = 30
    var height: CGFloat = 20
    var fontSize: CGFloat = 11
    
    private static let squaredModes: Set<TransportationMode> = [
        .regionalRail, .ferry, .rail, .highSpeedRail,
        .longDistance, .metro, .nightRail, .regionalFastRail
    ]
    
    private var isTrainDetected: Bool {
        line.hasPrefix("RL") || line.hasPrefix("IR") || line.hasPrefix("RE") || line.hasPrefix("IC") || line == "R"
    }

    private var isSquared: Bool {
        if Self.squaredModes.contains(mode) {
            return true
        }
        else if isTrainDetected {
            return true
        }
        else {
            return false
        }
    }
    
    private var formattedLine: String {
        line.hasPrefix("RL") ? String(line.dropFirst(1)) : line
    }
    
    private var lineColor: Color {
        if isSquared && LineColors.color(for: line) == nil {
            return Color(hex: "EA0706")
        }
        return LineColors.color(for: line) ?? .accentColor
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isSquared ? 2 : 50)
                .fill(lineColor.opacity(0.25))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: isSquared ? 2 : 50)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
            
            Text(formattedLine)
                .font(.custom("NimbusSansBeckerPBla", size: fontSize))
                .foregroundColor(lineColor == .black ? .white : lineColor)
                .multilineTextAlignment(.center)
        }
    }
}
