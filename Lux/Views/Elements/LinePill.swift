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
    @ObservedObject var settings = Settings.shared
    let line: String
    let mode: TransportationMode
    let agency: String?
    var width: CGFloat = 30
    var height: CGFloat = 20
    var fontSize: CGFloat = 11
    
    private var isTrainDetected: Bool {
        ["RL", "IR", "RE", "IC", "EC", "EXT", "ICE", "TGV", "RJ", "SN", "R"].contains {
            line.hasPrefix($0)
        }
    }

    private var isMetro: Bool {
        mode == .subway || mode == .metro || ["m1", "m2"].contains(line.lowercased())
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
    
    private var resolved: LineColors.ResolvedLineColor {
        LineColors.resolve(line: line, agency: agency, isSquared: isSquared)
    }

    private var baseLineColor: Color {
        resolved.color
    }
    
    private var lineColor: Color {
        if isDarkColor(baseLineColor) && !settings.highContrastButAccurateLinePill {
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

    private var textColor: Color {
        if isMainlineRail || isMetro { return .white.opacity(0.85) }
        if settings.highContrastButAccurateLinePill && resolved.isBranded {
            return resolved.textColor
        }
        return baseLineColor == .black ? .white : lineColor
    }
    
    var body: some View {
        let isEmphasizedService = isMainlineRail || isMetro
        let fillColor: Color = settings.easyOnTheEyes ?
            .clear :
            (settings.highContrastButAccurateLinePill ? lineColor : baseLineColor.opacity(isEmphasizedService ? emphasizedFillOpacity : 0.25))

        let strokeColor: Color = settings.easyOnTheEyes ?
            lineColor :
            Color.primary.opacity(0.1)
        ZStack {
            RoundedRectangle(cornerRadius: isSquared ? 2 : 50)
                .fill(fillColor)
                .stroke(strokeColor, lineWidth: 0.5)
                .frame(width: pillWidth, height: pillHeight)
            
            Text(formattedLine)
                .font(.custom("NimbusSansBeckerPBla", size: labelFontSize))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
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


struct SamplePill: View {
    var line: String = "18"
    let isEasyOnTheEyes: Bool
    let isRealistic: Bool
    
    private var baseLineColor: Color {
        return LineColors.color(for: line) ?? .accent
    }
    
    private var lineColor: Color {
        if isDarkColor(baseLineColor) && !isRealistic {
            return lightenColor(baseLineColor)
        }
        return baseLineColor
    }
    
    var body: some View {
        let fillColor: Color = isEasyOnTheEyes ?
            .clear :
            (isRealistic ? lineColor : baseLineColor.opacity(0.25))

        let strokeColor: Color = isEasyOnTheEyes ?
            lineColor :
            Color.primary.opacity(0.1)
        ZStack {
            RoundedRectangle(cornerRadius: line == "RL4" ? 2 : 50)
                .fill(fillColor)
                .stroke(strokeColor, lineWidth: 0.5)
                .frame(width: 30, height: 20)
            
            Text(line.replacingOccurrences(of: "RL4", with: "L4"))
                .font(.custom("NimbusSansBeckerPBla", size: 11))
                .foregroundColor(isRealistic ? LineColors.textColor(for: line) : (baseLineColor == .black ? .white : lineColor))
                .multilineTextAlignment(.center)
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
    }
}
