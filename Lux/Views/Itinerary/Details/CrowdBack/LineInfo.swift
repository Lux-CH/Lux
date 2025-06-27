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
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Chargement...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if let info = info {
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
                
                HStack(spacing: 1) {
                    ForEach(1...5, id: \.self) { level in
                        Circle()
                            .fill(level <= Int(data.level.rounded()) ?
                                  type.color(for: data.level) :
                                  Color.gray.opacity(0.3))
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
            .background(Color.gray.opacity(0.1))
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
        case .crowd:
            return crowdColor(for: level)
        case .smell:
            return negativeAttributeColor(for: level)
        case .clean:
            return positiveAttributeColor(for: level)
        case .heat:
            return heatColor(for: level)
        case .noise:
            return negativeAttributeColor(for: level)
        }
    }
    
    private func crowdColor(for level: Double) -> Color {
        switch level {
        case 0...1: return .green
        case 1...2: return .yellow
        case 2...3: return .orange
        case 3...4: return .red
        default: return .purple
        }
    }
    
    private func negativeAttributeColor(for level: Double) -> Color {
        switch level {
        case 0...1: return .green
        case 1...2: return .yellow
        case 2...3: return .orange
        case 3...4: return .red
        default: return .purple
        }
    }
    
    private func positiveAttributeColor(for level: Double) -> Color {
        switch level {
        case 0...1: return .red
        case 1...2: return .orange
        case 2...3: return .yellow
        case 3...4: return .green
        default: return .blue
        }
    }
    
    private func heatColor(for level: Double) -> Color {
        switch level {
        case 0...1: return .blue
        case 1...2: return .green
        case 2...3: return .yellow
        case 3...4: return .orange
        default: return .red
        }
    }
}
