//
//  AttributeStepView.swift
//  Lux
//
//  Created by Constantin Clerc on 03.08.2025.
//

import SwiftUI
import LuxCom

struct AttributeStepView: View {
    let attribute: ReportAttribute
    let selectedLevel: Int
    let stepNumber: Int
    let totalSteps: Int
    let onLevelChange: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                
                VStack(spacing: 2) {
                    Text(displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(String(localized: "Évaluez le niveau actuel"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text(lowLevelText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(highLevelText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { level in
                        Button {
                            onLevelChange(level)
                        } label: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(level <= selectedLevel ? colorForLevel(level) : Color(.systemGray5))
                                .frame(height: 8)
                                .animation(.easeInOut(duration: 0.2), value: selectedLevel)
                        }
                    }
                }
                
                HStack {
                    Text("\(selectedLevel)/5")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(colorForLevel(selectedLevel))
                    
                    Spacer()
                    
                    Text(intensityDescription)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(colorForLevel(selectedLevel))
                }
            }
        }
    }
    
    private var iconName: String {
        switch attribute {
        case .crowd: return "person.3.fill"
        case .clean: return "sparkles"
        case .heat: return "thermometer.medium"
        case .noise: return "speaker.wave.2.fill"
        case .smell: return "nose.fill"
        }
    }
    
    private var displayName: String {
        switch attribute {
        case .crowd: return String(localized:"Affluence")
        case .clean: return String(localized:"Propreté")
        case .heat: return String(localized:"Température")
        case .noise: return String(localized:"Bruit")
        case .smell: return String(localized:"Odeur")
        }
    }
    
    private var lowLevelText: String {
        switch attribute {
        case .crowd: return String(localized: "Vide")
        case .clean: return String(localized: "Sale")
        case .heat: return String(localized: "Froid")
        case .noise: return String(localized: "Silencieux")
        case .smell: return String(localized: "Pas d'odeur")
        }
    }

    private var highLevelText: String {
        switch attribute {
        case .crowd: return String(localized: "Bondé")
        case .clean: return String(localized: "Propre")
        case .heat: return String(localized: "Chaud")
        case .noise: return String(localized: "Bruyant")
        case .smell: return String(localized: "Forte odeur")
        }
    }

    private var intensityDescription: String {
        switch attribute {
        case .crowd:
            switch selectedLevel {
            case 1: return String(localized: "Vide")
            case 2: return String(localized: "Peu occupé")
            case 3: return String(localized: "Modéré")
            case 4: return String(localized: "Occupé")
            case 5: return String(localized: "Bondé")
            default: return ""
            }
        case .clean:
            switch selectedLevel {
            case 1: return String(localized: "Très sale")
            case 2: return String(localized: "Sale")
            case 3: return String(localized: "Correct")
            case 4: return String(localized: "Propre")
            case 5: return String(localized: "Très propre")
            default: return ""
            }
        case .heat:
            switch selectedLevel {
            case 1: return String(localized: "Froid")
            case 2: return String(localized: "Frais")
            case 3: return String(localized: "Tempéré")
            case 4: return String(localized: "Chaud")
            case 5: return String(localized: "Très chaud")
            default: return ""
            }
        case .noise:
            switch selectedLevel {
            case 1: return String(localized: "Silencieux")
            case 2: return String(localized: "Calme")
            case 3: return String(localized: "Modéré")
            case 4: return String(localized: "Bruyant")
            case 5: return String(localized: "Très bruyant")
            default: return ""
            }
        case .smell:
            switch selectedLevel {
            case 1: return String(localized: "Pas d'odeur")
            case 2: return String(localized: "Légère")
            case 3: return String(localized: "Perceptible")
            case 4: return String(localized: "Forte")
            case 5: return String(localized: "Très forte")
            default: return ""
            }
        }
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        switch attribute {
        case .heat:
            switch level {
            case 1: return .cyan
            case 2: return .blue
            case 3: return .indigo
            case 4: return .purple
            case 5: return .red
            default: return .blue
            }
        case .clean:
            switch level {
            case 1: return vividRed
            case 2: return .red
            case 3: return .yellow
            case 4: return .green
            case 5: return vividGreen
            default: return .red
            }
        case .crowd, .noise, .smell:
            switch level {
            case 1: return vividGreen
            case 2: return .green
            case 3: return .yellow
            case 4: return .red
            case 5: return vividRed
            default: return .green
            }
        }
    }
}

let vividRed = Color(red: 1.0, green: 0.1, blue: 0.0)
let vividGreen = Color(red: 0.0, green: 0.9, blue: 0.2)
