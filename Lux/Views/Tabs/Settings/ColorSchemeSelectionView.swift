//
//  ColorSchemeSelectionView.swift
//  Lux
//
//  Created by Constantin Clerc on 30.05.2025.
//

import SwiftUI

struct ColorSchemeSelectionView: View {
    @ObservedObject var settings = Settings.shared
    var dimiss: () -> Void
    
    private let themeOptions = [
        ThemeOption(id: "system", title: "Système", subtitle: "Suit les réglages système", icon: "iphone", isDefault: true),
        ThemeOption(id: "automatic", title: "Automatique", subtitle: "Basé sur l'heure", icon: "clock.arrow.2.circlepath"),
        ThemeOption(id: "light", title: "Clair", subtitle: "Toujours en mode clair", icon: "sun.max"),
        ThemeOption(id: "dark", title: "Sombre", subtitle: "Toujours en mode sombre", icon: "moon")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerCard
                    VStack {
                        themeSelectionCards
                            .padding(.bottom)
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text("Mode d'affichage")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choisissez le mode d'affichage de l'app")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }
    
    private var themeSelectionCards: some View {
        VStack(spacing: 12) {
            ForEach(themeOptions, id: \.id) { option in
                ThemeSelectionCard(
                    option: option,
                    isSelected: isSelected(option),
                    action: { selectTheme(option) }
                )
            }
        }
    }
    
    private func isSelected(_ option: ThemeOption) -> Bool {
        switch option.id {
        case "system":
            return !settings.autoColorScheme && !settings.customScheme
        case "automatic":
            return settings.autoColorScheme
        case "light":
            return settings.customScheme && settings.customSchemeSelection == "light"
        case "dark":
            return settings.customScheme && settings.customSchemeSelection == "dark"
        default:
            return false
        }
    }
    
    private func selectTheme(_ option: ThemeOption) {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch option.id {
            case "system":
                settings.autoColorScheme = false
                settings.customScheme = false
                settings.customSchemeSelection = ""
            case "automatic":
                settings.autoColorScheme = true
                settings.customScheme = false
                settings.customSchemeSelection = ""
            case "light":
                settings.autoColorScheme = false
                settings.customScheme = true
                settings.customSchemeSelection = "light"
            case "dark":
                settings.autoColorScheme = false
                settings.customScheme = true
                settings.customSchemeSelection = "dark"
            default:
                break
            }
        }
        
        dimiss()
    }
}

struct ThemeOption {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let isDefault: Bool
    
    init(id: String, title: String, subtitle: String, icon: String, isDefault: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDefault = isDefault
    }
}

struct ThemeSelectionCard: View {
    let option: ThemeOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(option.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if option.isDefault {
                            Text("Par Défaut")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                        }
                        
                        Spacer()
                    }
                    
                    Text(option.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    ColorSchemeSelectionView(dimiss: {print("dismissing parent settignsview")})
}
