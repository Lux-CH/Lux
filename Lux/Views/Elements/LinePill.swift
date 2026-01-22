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
    let agency: String?
    var width: CGFloat = 30
    var height: CGFloat = 20
    var fontSize: CGFloat = 11
    
    private static let squaredModes: Set<TransportationMode> = [
        .regionalRail, .ferry, .rail, .highSpeedRail,
        .longDistance, .metro, .nightRail, .regionalFastRail
    ]
    
    private static let lausanneAgencies: Set<String> = ["151", "55", "764", "7256", "344", "29"]

    private var isLausanne: Bool {
        return Self.lausanneAgencies.contains(agency ?? "")
    }
    
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
        return (isLausanne ? LineColors.tlColor(for: line) : LineColors.color(for: line)) ?? .accent
    }
    
    private var lineColor: Color {
        if isDarkColor(baseLineColor) && !settings.highContrastButAccurateLinePill {
            return lightenColor(baseLineColor)
        }
        return baseLineColor
    }
    
    var body: some View {
        let fillColor: Color = settings.easyOnTheEyes ?
            .clear :
            (settings.highContrastButAccurateLinePill ? lineColor : baseLineColor.opacity(0.25))

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
                .foregroundColor(settings.highContrastButAccurateLinePill && !isLausanne ? LineColors.textColor(for: line) : (baseLineColor == .black ? .white : lineColor))
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
