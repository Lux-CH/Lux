//
//  SubmittingOverlay.swift
//  Lux
//
//  Created by Constantin Clerc on 03.08.2025.
//

import SwiftUI
import LuxCom

struct SubmittingOverlay: View {
    let currentAttribute: ReportAttribute
    let progress: Float
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 4) {
                Text(String(localized: "Rapport en cours..."))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(String(localized: "Rapport: \(displayName)"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 40)
    }
    
    private var iconName: String {
        switch currentAttribute {
        case .crowd: return "person.3.fill"
        case .clean: return "sparkles"
        case .heat: return "thermometer.medium"
        case .noise: return "speaker.wave.2.fill"
        case .smell: return "nose.fill"
        }
    }
    
    private var displayName: String {
        switch currentAttribute {
        case .crowd: return String(localized:"Affluence")
        case .clean: return String(localized:"Propreté")
        case .heat: return String(localized:"Température")
        case .noise: return String(localized:"Bruit")
        case .smell: return String(localized:"Odeur")
        }
    }
}
