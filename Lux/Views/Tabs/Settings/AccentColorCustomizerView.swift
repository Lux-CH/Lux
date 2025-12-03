//
//  AccentColorCustomizerView.swift
//  Lux
//
//  Created by Constantin Clerc on 30.05.2025.
//

import SwiftUI

struct AccentColorCustomizerView: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedColorScale: CGFloat = 1.0
    @State private var selectedColorName = ""
    @State private var showDarkColorAlert: Bool = false
        
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        accentColorManager.selectedAccentColor.opacity(0.1),
                        Color.clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(accentColorManager.selectedAccentColor)
                                    .frame(width: 65, height: 65)
                                
                                Image(systemName: "paintpalette")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(selectedColorScale)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedColorScale)
                            
                            VStack(spacing: 8) {
                                Text("Couleur de l'app")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                
                                Text("Séléctionnez la couleur de l'application et de l'icône")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 15)
                        }
                        .padding(.top, 15)
                        
                        VStack(spacing: 20) {
                            HStack {
                                Text("Couleurs disponibles")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                                if (accentColorManager.selectedAccentColor == Color(hex: "2d327d") || accentColorManager.selectedAccentColor == Color(hex: "6B4423")) && colorScheme == .dark {
                                    Button {showDarkColorAlert = true} label: {
                                        Text("\(Image(systemName: "exclamationmark.triangle")) Couleur Sombre")
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(Capsule(style: .continuous))
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .alert("Couleur Sombre", isPresented: $showDarkColorAlert) {
                                        Button("OK", role: .cancel) { }
                                    } message: {
                                        Text("La couleur séléctionnée n'est pas bien visible en mode sombre. Pensez à passer en mode clair dans les paramètres \"Mode d'Affichage\"")
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 20) {
                                ForEach(Array(accentColorManager.availableColors.enumerated()), id: \.element.name) { index, colorData in
                                    ModernColorOptionView(
                                        color: colorData.color,
                                        name: colorData.name,
                                        isSelected: colorData.color == accentColorManager.selectedAccentColor,
                                        index: index
                                    ) {
                                        selectColor(colorData)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 20)
                    }
                }
                
            }
        }
    }
    
    private func selectColor(_ colorData: (name: String, color: Color, iconName: String?)) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            accentColorManager.setAccentColor(colorData.color)
            selectedColorName = colorData.name
        }
        
        selectedColorScale = 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedColorScale = 1.0
        }
        
        HapticFeedback.lightImpact()
    }
}

struct ModernColorOptionView: View {
    let color: Color
    let name: String
    let isSelected: Bool
    let index: Int
    let action: () -> Void
    
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(color)
                        .stroke(Color.primary.opacity(0.1), lineWidth: !isSelected ? 0.5 : 0.0)
                        .frame(width: 70, height: 70)
//                        .shadow(
//                            color: color.opacity(0.3),
//                            radius: isSelected ? 15 : 8,
//                            x: 0,
//                            y: isSelected ? 8 : 4
//                        )
                    
                    if isSelected {
                        Circle()
                            .stroke(color, lineWidth: 4)
                            .frame(width: 84, height: 84)
                            .background(
                                Circle()
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    .frame(width: 84, height: 84)
                            )
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
            
            Text(name)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? color : .secondary)
                .animation(.bouncy(duration: 0.2), value: isSelected)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.05)) {
                hasAppeared = true
            }
        }
    }
}
