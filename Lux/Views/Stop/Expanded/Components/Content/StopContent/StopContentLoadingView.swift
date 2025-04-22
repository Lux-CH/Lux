//
//  StopContentLoadingView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI

struct StopContentLoadingView: View {
    @Binding var animateIn: Bool
    var errorMessage: String?
    
    var body: some View {
        VStack {
            ProgressView("Chargement des départs...")
                .scaleEffect(animateIn ? 1 : 0.5)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateIn)
                .padding()
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
