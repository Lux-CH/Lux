//
//  LineInfo.swift
//  Lux
//
//  Created by Constantin Clerc on 27.06.2025.
//

import SwiftUI
import LuxCom

struct LineInfoView: View {
    let info: InfoResponse?
    
    var body: some View {
        HStack(spacing: 8) {
            if let info = info {
                if info.rt != nil {
                    Image(systemName: "wave.3.forward")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                ForEach(AttributeType.allCases, id: \.self) { attributeType in
                    AttributeIndicator(
                        type: attributeType,
                        info: info,
                        isRealtime: info.rt?[attributeType.rawValue] != nil
                    )
                }
            }
        }
    }
}

struct AttributeIndicator: View {
    let type: AttributeType
    let info: InfoResponse
    let isRealtime: Bool
    
    private var attributeData: (level: Double, trustLevel: Double)? {
        if isRealtime, let rtData = info.rt?[type.rawValue] {
            return (Double(rtData.level), Double(rtData.trustLevel))
        } else if let avgData = info.average[type.rawValue] {
            return (avgData.level, avgData.trustLevel)
        }
        return nil
    }
    
    var body: some View {
        if let data = attributeData, data.trustLevel >= 2.0 {
            HStack(spacing: 2) {
                Image(systemName: type.iconName)
                    .font(.system(size: 11))
                    .foregroundColor(type.color(for: data.level))
                    .frame(height: 12)
                
                HStack(spacing: 1) {
                    ForEach(1...5, id: \.self) { level in
                        Circle()
                            .fill(level <= Int(data.level.rounded()) ?
                                  type.color(for: data.level) :
                                  Color.secondary.opacity(0.3))
                            .frame(width: 3, height: 3)
                    }
                }
                
//                if data.trustLevel > 3 {
//                    Image(systemName: "checkmark.circle.fill")
//                        .font(.system(size: 8))
//                        .foregroundColor(.green)
//                } else if data.trustLevel > 1 {
//                    Image(systemName: "questionmark.circle.fill")
//                        .font(.system(size: 8))
//                        .foregroundColor(.orange)
//                }
                
//                if isRealtime {
//                    Circle()
//                        .fill(Color.green)
//                        .frame(width: 4, height: 4)
//                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
    }
}

enum AttributeType: String, CaseIterable {
    case crowd = "crowd"
    case smell = "smell"
    case clean = "clean"
    case heat = "heat"
    case noise = "noise"
    
    var iconName: String {
        switch self {
        case .crowd:
            return "person.3.fill"
        case .smell:
            return "nose.fill"
        case .clean:
            return "sparkles"
        case .heat:
            return "thermometer.medium"
        case .noise:
            return "speaker.wave.2.fill"
        }
    }
    func color(for level: Double) -> Color {
        switch self {
        case .heat:
            switch level {
            case 0.0..<1.5: return .cyan
            case 1.5..<2.5: return .blue
            case 2.5..<3.5: return .indigo
            case 3.5..<4.5: return .purple
            case 4.5...5.0: return .red
            default: return .blue
            }
            
        case .clean:
            switch level {
            case 0.0..<1.5: return intermediaryRedColor
            case 1.5..<2.5: return .red
            case 2.5..<3.5: return .yellow
            case 3.5..<4.5: return .green
            case 4.5...5.0: return intermediaryGreenColor
            default: return .red
            }
            
        case .crowd, .noise, .smell:
            switch level {
            case 0.0..<1.5: return intermediaryGreenColor
            case 1.5..<2.5: return .green
            case 2.5..<3.5: return .yellow
            case 3.5..<4.5: return .red
            case 4.5...5.0: return intermediaryRedColor
            default: return .green
            }
        }
    }
}
