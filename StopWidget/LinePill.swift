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
    let agency: String
    var width: CGFloat = 30
    var height: CGFloat = 20
    var fontSize: CGFloat = 11
    
    private var isTrainDetected: Bool {
        line.hasPrefix("RL") || line.hasPrefix("IR") || line.hasPrefix("RE") || line.hasPrefix("IC") || line == "R"
    }
    
    private static let lausanneAgencies: Set<String> = ["151", "55", "764", "7256", "344", "29"]

    private var isLausanne: Bool {
        return Self.lausanneAgencies.contains(agency)
    }

    private var isSquared: Bool {
        if mode.usesSquaredPill {
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
    
    private var baseLineColor: Color {
        if isSquared && LineColors.color(for: line) == nil {
            return Color(hex: "EA0706")
        }
        return (isLausanne ? LineColors.tlColor(for: line) : LineColors.color(for: line)) ?? .accentColor
    }
    
    private var lineColor: Color {
        if isDarkColor() {
            return lightenColor(baseLineColor)
        }
        return baseLineColor
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isSquared ? 2 : 50)
                .fill(lineColor.opacity(0.25))
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                .frame(width: width, height: height)
            
            Text(formattedLine)
                .font(.custom("NimbusSansBeckerPBla", size: fontSize))
                .foregroundColor(baseLineColor == .black ? .white : lineColor)
                .multilineTextAlignment(.center)
        }
    }
    
    private func isDarkColor() -> Bool {
        let uiColor = UIColor(baseLineColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // ITU-R BT.709, https://stackoverflow.com/a/596243
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        
        return luminance < 0.35
    }
    
    private func lightenColor(_ color: Color, by factor: Double = 0.25) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newBrightness = min(1.0, brightness + CGFloat(factor))
        let newSaturation = max(0.3, saturation * 0.8)
        
        return Color(hue: Double(hue), saturation: Double(newSaturation), brightness: Double(newBrightness))
    }
}
