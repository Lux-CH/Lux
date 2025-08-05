//
//  HintIndicatorView.swift
//  Lux
//
//  Created by Constantin Clerc on 06.08.2025.
//

import SwiftUI

struct HintIndicatorView: View {
    let icon: String
    let message: String
    let delay: Double
    let duration: Double
    
    @State private var isVisible = false
    @State private var bounceOffset: CGFloat = 0
    @State private var pulseOpacity: Double = 0.3
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.system(size: 20, weight: .bold))
                .offset(y: bounceOffset)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay + 2) {
                        bounce()
                    }
                }
                .onTapGesture {
                    bounce() // fun
                }
                .opacity(isVisible ? pulseOpacity - 0.1 : 0)
            
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .font(.caption)
                .padding(.horizontal, 16)
                .opacity(isVisible ? pulseOpacity : 0)
        }
        
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.75)) {
                    isVisible = true
                }
                startPulsing()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + duration) {
                withAnimation(.easeOut(duration: 0.75)) {
                    isVisible = false
                }
            }
        }
    }
    private func startPulsing() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.6
        }
    }
    private func bounce() {
        withAnimation(.bouncy(duration: 0.3)) {
            bounceOffset = -4
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.bouncy(duration: 0.3)) {
                bounceOffset = 0
            }
        }
    }
}
