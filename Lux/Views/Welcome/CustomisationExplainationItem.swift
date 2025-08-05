//
//  CustomisationExplainationItem.swift
//  Lux
//
//  Created by Constantin Clerc on 30.07.2025.
//

import SwiftUI

struct CustomisationExplainationItem: View {
    let title: String
    let description: String
    let color: Color
    let icon: String
    let action: () -> Void
        
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 24, weight: .bold))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomisationQuickView: View {
    @ObservedObject var settings = Settings.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "swatchpalette")
                .font(.system(size: 40))
                .foregroundColor(Color.accentColor)
            
            Text("Personnalisation")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Ajustez le style de Lux selon vos préférences")
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
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal)
        SettingsCard {
            Section {
                SettingsToggle(
                    icon: "clock.badge",
                    title: "Afficher le retard exact",
                    subtitle: "Affiche le retard à côté de l'heure prévue (sinon, inclus dans l'heure)",
                    isOn: $settings.showDelayInsteadOfDirectTime
                )
                
                if UIDevice.current.userInterfaceIdiom == .phone {
                    SettingsToggle(
                        icon: "rectangle.compress.vertical",
                        title: "Interface compacte",
                        subtitle: "Réduire l'espacement dans l'onglet des arrêts",
                        isOn: $settings.reduceSpacerBtwnStopContentView
                    )
                }
                
                SettingsToggle(
                    icon: "lightspectrum.horizontal",
                    title: "Contraste plus important",
                    subtitle: "Augmente la lisibilité de l'interface",
                    isOn: $settings.highContrastButAccurateLinePill
                )
                
                settingsNavigationLink(
                    destination: AccentColorCustomizerView(),
                    icon: "paintpalette",
                    title: "Couleur de l'app",
                    subtitle: "Personnalisez l'apparence de l'application"
                )
                
                settingsNavigationLink(
                    destination: ColorSchemeSelectionView(dimiss: { dismiss() }),
                    icon: "circle.lefthalf.filled",
                    title: "Mode d'affichage",
                    subtitle: "Choisissez le mode d'affichage de l'app (clair, sombre, auto..)"
                )
                
                settingsNavigationLink(
                    destination: WidgetStopSelectorView(),
                    icon: widgetIcon,
                    title: "Widget",
                    subtitle: "Personnalisez le Widget de l'app en sélectionnant un arrêt à afficher"
                )
            } header: {
                SectionHeader(
                    icon: "paintbrush.fill",
                    iconColor: .red,
                    title: "Personnalisation",
                    subtitle: "Adaptez l'interface à vos préférences. Plus de paramètres sont disponible dans la page à cet effet."
                )
            }
        }
        .padding(.horizontal, 15)
    }
    
    private func settingsNavigationLink<Destination: View>(
        destination: Destination,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        NavigationLink(destination: destination) {
            SettingsRow(
                icon: icon,
                title: title,
                subtitle: subtitle,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }
    
    private var widgetIcon: String {
        if #available(iOS 18, *) {
            return "widget.small"
        } else {
            return "eye"
        }
    }
}
