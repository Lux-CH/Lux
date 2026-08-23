//
//  LinePill.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct LinePill: View {
    @Environment(\.colorScheme) private var colorScheme
    let line: String
    let mode: TransportationMode
    let agency: String
    var width: CGFloat = 30
    var height: CGFloat = 20
    var fontSize: CGFloat = 11
    
    private var isTrainDetected: Bool {
        ["RL", "IR", "RE", "IC", "EC", "EXT", "ICE", "TGV", "RJ", "SN", "R"].contains {
            line.hasPrefix($0)
        }
    }

    private var isMetro: Bool {
        mode == .subway || ["m1", "m2"].contains(line.lowercased())
    }

    private var isMainlineRail: Bool {
        (mode.isMainlineRail || isTrainDetected) && !isMetro
    }
    
    private var isSquared: Bool {
        if isMetro {
            return false
        } else if mode.usesSquaredPill {
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
        if isMetro, line.count == 2, line.lowercased().hasPrefix("m") {
            return String(line.dropFirst())
        }
        return line.hasPrefix("RL") ? String(line.dropFirst(1)) : line
    }
    
    private var baseLineColor: Color {
        LineColors.resolve(line: line, agency: agency, isSquared: isSquared).color
    }
    
    private var lineColor: Color {
        if isDarkColor() {
            return lightenColor(baseLineColor)
        }
        return baseLineColor
    }

    private var pillWidth: CGFloat {
        if isMetro { return pillHeight }
        guard isMainlineRail else { return width }
        let textWidth = CGFloat(formattedLine.count) * fontSize * 0.7 + 12
        return max(width, textWidth)
    }

    private var pillHeight: CGFloat {
        isMetro ? height + 4 : height
    }

    private var labelFontSize: CGFloat {
        isMetro ? fontSize + 2 : fontSize
    }

    private var emphasizedFillOpacity: Double {
        colorScheme == .light ? 0.7 : 0.45
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isSquared ? 2 : 50)
                .fill(lineColor.opacity((isMainlineRail || isMetro) ? emphasizedFillOpacity : 0.25))
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                .frame(width: pillWidth, height: pillHeight)
            
            Text(formattedLine)
                .font(.custom("NimbusSansBeckerPBla", size: labelFontSize))
                .foregroundColor((isMainlineRail || isMetro) ? .white.opacity(0.85) : (baseLineColor == .black ? .white : lineColor))
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
