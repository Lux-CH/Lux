//
//  LinePill.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct LinePill: View {
    @ObservedObject var settings = Settings.shared
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
    
    private var baseLineColor: Color {
        if isSquared && LineColors.color(for: line) == nil {
            return Color(hex: "EA0706")
        }
        return LineColors.color(for: line) ?? .accent
    }
    
    private var lineColor: Color {
        if isDarkColor() {
            return lightenColor(baseLineColor)
        }
        return baseLineColor
    }
    
    var body: some View {
        let fillColor: Color = settings.easyOnTheEyes ?
            .clear :
            (settings.highContrastButAccurateLinePill ? lineColor : lineColor.opacity(0.25))

        let strokeColor: Color = settings.easyOnTheEyes ?
            lineColor :
            Color.primary.opacity(0.1)
        ZStack {
            RoundedRectangle(cornerRadius: isSquared ? 2 : 50)
                .fill(fillColor)
                .stroke(strokeColor, lineWidth: 0.5)
                .frame(width: width, height: height)
            
            Text(formattedLine)
                .font(.custom("NimbusSansBeckerPBla", size: fontSize))
                .foregroundColor(settings.highContrastButAccurateLinePill ? LineColors.textColor(for: line) : (lineColor == .black ? .white : lineColor))
                .multilineTextAlignment(.center)
        }
    }
    
    private func isDarkColor() -> Bool {
        guard !settings.highContrastButAccurateLinePill else {
            return false
        }
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

struct MorePill: View {
    @ObservedObject var settings = Settings.shared
    var body: some View {
        let fillColor: Color = settings.easyOnTheEyes ?
            .clear :
            (settings.highContrastButAccurateLinePill ? Color(.secondarySystemFill) : Color.accentColor.opacity(0.25))
        
        let strokeColor: Color = settings.easyOnTheEyes ?
            Color.accentColor.opacity(0.1) :
            Color.primary.opacity(0.1)
        
        ZStack {
            RoundedRectangle(cornerRadius: 50)
                .fill(fillColor)
                .stroke(strokeColor, lineWidth: 0.5)
                .frame(width: 30, height: 20)
            Image(systemName: "ellipsis")
                .foregroundColor(Color.accentColor)
                .multilineTextAlignment(.center)
                .font(.system(size: 11))
        }
    }
}

