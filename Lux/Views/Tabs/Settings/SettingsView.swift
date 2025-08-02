//
//  SettingsView.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var lineScoreManager = LineScoreManager.shared
    @EnvironmentObject private var shortcutManager: ShortcutManager
    @ObservedObject var settings = Settings.shared
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    headerCard
                    
                    VStack(spacing: 16) {
                        shortcutsCard
                        lineScoreCard
                        SettingsCard {
                            Section {
                                NavigationLink(destination: TicketsView()) {
                                    SettingsRow(
                                        icon: "ticket",
                                        title: "Tickets",
                                        subtitle: "Achetez vos tickets ou ajoutez votre SwissPass à Lux.",
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        customizationCard
                        experimentalCard
                        aboutCard
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape")
                .font(.system(size: 40))
                .foregroundColor(accentColorManager.selectedAccentColor)
            
            Text("Paramètres")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Personnalisez votre expérience Lux")
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
    
    // MARK: - Shortcuts Card
    private var shortcutsCard: some View {
        SettingsCard {
            Section {
                let plural = shortcutManager.shortcuts.count > 1 ? "s" : ""
                NavigationLink(destination: ShortcutsListView()) {
                    SettingsRow(
                        icon: "list.bullet",
                        title: "Gérer les raccourcis",
                        subtitle: "\(shortcutManager.shortcuts.count) raccourci\(plural) configuré\(plural)",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                
                SettingsToggle(
                    icon: "textformat",
                    title: "Afficher les titres",
                    subtitle: "Affiche le nom des raccourcis",
                    isOn: $settings.showShortcutLabel
                )
                
                SettingsToggle(
                    icon: "clock.fill",
                    title: "Tri par pertinence",
                    subtitle: "Affiche les raccourcis les plus pertinents en premier",
                    isOn: $settings.useTimeBasedRelevance
                )
            } header: {
                SectionHeader(
                    icon: "location.fill",
                    iconColor: .blue,
                    title: "Raccourcis",
                    subtitle: "Accès rapide à vos destinations"
                )
            }
        }
    }
    
    // MARK: - Customization Card
    private var customizationCard: some View {
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
                
                NavigationLink(destination: AccentColorCustomizerView()) {
                    SettingsRow(
                        icon: "paintpalette",
                        title: "Couleur de l’app",
                        subtitle: "Personnalisez l’apparence de l'application",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                NavigationLink(destination: ColorSchemeSelectionView(dimiss: {dismiss()})) {
                    SettingsRow(
                        icon: "circle.lefthalf.filled",
                        title: "Mode d'affichage",
                        subtitle: "Chosissez la mode d'affichage de l'app (clair, sombre, auto..)",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                NavigationLink(destination: WidgetStopSelectorView()) {
                    SettingsRow(
                        icon: { if #available(iOS 18, *) { "widget.small" } else { "eye" } }(),
                        title: "Widget",
                        subtitle: "Personnalisez le Widget de l'app en sélectionnant un arrêt à afficher",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
            } header: {
                SectionHeader(
                    icon: "paintbrush.fill",
                    iconColor: .red,
                    title: "Personnalisation",
                    subtitle: "Adaptez l'interface à vos préférences"
                )
            }
        }
    }
    
    // MARK: Line Score Card
    private var lineScoreCard: some View {
        SettingsCard {
            Section {
                NavigationLink(destination: LineScoreView()) {
                    SettingsRow(
                        icon: "chart.bar.fill",
                        title: "Lignes préférées",
                        subtitle: {
                            let highScoreLines = lineScoreManager.lineScores.filter { $0.totalScore >= 2.0 }
                            return highScoreLines.isEmpty ? "Aucune ligne enregistrée" :
                            "\(highScoreLines.count) ligne\(highScoreLines.count > 1 ? "s" : "")"
                        }(),
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
            } header: {
                SectionHeader(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: "Lignes",
                    subtitle: "Gérez les lignes que vous fréquentez le plus souvent."
                )
            }
        }
    }
    
    // MARK: - Experimental Card
    private var experimentalCard: some View {
        SettingsCard {
            Section {
                SettingsToggle(
                    icon: "exclamationmark.bubble",
                    title: "Contribuer à CrowdBack",
                    subtitle: "Consultez et partagez des informations en temps réel sur les transports.",
                    isOn: $settings.crowdbackAllowed
                )
                SettingsToggle(
                    icon: "figure.walk",
                    title: "Obtenir les instructions",
                    subtitle: "Calculer les instructions de marche via MKDirection",
                    isOn: $settings.fetchWalkingDirectionsUsingMKDirections
                )
                SettingsPicker(
                    icon: "link",
                    title: "Durée de partage d'itinéraire",
                    subtitle: "Choisissez combien de temps un itinéraire partagé reste accessible \(settings.luxTripShareExpiryTimeH >= 4320 ? "\n⚠︎ Le temps d'expiration sélectionné est élevé. Lux ne peut garantir une telle période de rétention." : "")",
                    selection: $settings.luxTripShareExpiryTimeH,
                    options: [
                        (24, "1 jour"),
                        (168, "7 jours"),
                        (720, "1 mois"),
                        (4320, "6 mois"),
                        (8760, "1 an")
                    ]
                )
            } header: {
                SectionHeader(
                    icon: "flask.fill",
                    iconColor: .purple,
                    title: "Fonctionnalités expérimentales",
                    subtitle: "⚠️ Effectuer des changements n'est pas recommandé"
                )
            }
        }
    }
    
    // MARK: - About Card
    private var aboutCard: some View {
        SettingsCard {
            Section {
                NavigationLink(destination: CreditsView()) {
                    SettingsRow(
                        icon: "heart.fill",
                        title: "Crédits",
                        subtitle: "Liste des modules utilisés dans l'application",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                SettingsRow(
                    icon: "app.badge",
                    title: "Version",
                    // MARK: CHANGE THAT WHEN IN PROD
                    subtitle: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Inconnue") Beta \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Inconnue")",
                    showChevron: false
                )
            } header: {
                SectionHeader(
                    icon: "info.circle.fill",
                    iconColor: .gray,
                    title: "À propos",
                    subtitle: "Informations sur l'application"
                )
            }
        }
    }
}
