//
//  StopContentEmptyView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI

struct StopContentEmptyView: View {
    @Binding var animateIn: Bool
    var errorMessage: String?
    
    var body: some View {
        VStack {
            Text("Aucun départ à venir.")
                .foregroundColor(.gray)
                .padding()
                .scaleEffect(animateIn ? 1 : 0.7)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateIn)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
