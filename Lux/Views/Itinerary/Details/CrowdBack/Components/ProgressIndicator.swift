//
//  ProgressIndicator.swift
//  Lux
//
//  Created by Constantin Clerc on 03.08.2025.
//

import SwiftUI

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color(.systemGray4))
                        .frame(width: step == currentStep ? 10 : 8, height: step == currentStep ? 10 : 8)
                        .scaleEffect(step == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStep)
                }
            }
            
            HStack(spacing: 4) {
                Text("\(currentStep + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
                
                Text(String(localized: "sur"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(totalSteps)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
            )
        }
    }
}
