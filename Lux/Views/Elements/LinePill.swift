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
    
    private var lineColor: Color {
        if isSquared && LineColors.color(for: line) == nil {
            return Color(hex: "EA0706")
        }
        return LineColors.color(for: line) ?? .accent
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
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: isSquared ? 2 : 50)
                        .stroke(strokeColor, lineWidth: 0.5)
                )
            
            Text(formattedLine)
                .font(.custom("NimbusSansBeckerPBla", size: fontSize))
                .foregroundColor(settings.highContrastButAccurateLinePill ? LineColors.textColor(for: line) : (lineColor == .black ? .white : lineColor))
                .multilineTextAlignment(.center)
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
                .frame(width: 30, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(strokeColor, lineWidth: 0.5)
                )
            Image(systemName: "ellipsis")
                .foregroundColor(Color.accentColor)
                .multilineTextAlignment(.center)
                .font(.system(size: 11))
        }
    }
}

