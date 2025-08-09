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
                                        title: String(localized: "Tickets"),
                                        subtitle: String(localized: "Achetez vos tickets ou ajoutez votre SwissPass à Lux."),
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
    
    private var shortcutsCard: some View {
        SettingsCard {
            Section {
                let plural = shortcutManager.shortcuts.count > 1 ? "s" : ""
                NavigationLink(destination: ShortcutsListView()) {
                    SettingsRow(
                        icon: "list.star",
                        title: String(localized: "Gérer les raccourcis"),
                        subtitle: "\(shortcutManager.shortcuts.count) \(String(localized: "raccourci"))\(plural) \(String(localized: "configuré"))\(plural)",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                
                SettingsToggle(
                    icon: "textformat",
                    title: String(localized: "Afficher les titres"),
                    subtitle: String(localized: "Affiche le nom des raccourcis"),
                    isOn: $settings.showShortcutLabel
                )
                
                SettingsToggle(
                    icon: "clock.fill",
                    title: String(localized: "Tri par pertinence"),
                    subtitle: String(localized: "Affiche les raccourcis les plus pertinents en premier"),
                    isOn: $settings.useTimeBasedRelevance
                )
            } header: {
                SectionHeader(
                    icon: "link",
                    iconColor: .blue,
                    title: String(localized: "Raccourcis"),
                    subtitle: String(localized: "Accès rapide à vos destinations")
                )
            }
        }
    }
    
    private var customizationCard: some View {
        SettingsCard {
            Section {
                SettingsToggle(
                    icon: "clock.badge",
                    title: String(localized: "Afficher le retard exact"),
                    subtitle: String(localized: "Affiche le retard à côté de l'heure prévue (sinon, inclus dans l'heure)"),
                    isOn: $settings.showDelayInsteadOfDirectTime
                )
                
                if UIDevice.current.userInterfaceIdiom == .phone {
                    SettingsToggle(
                        icon: "rectangle.compress.vertical",
                        title: String(localized: "Interface compacte"),
                        subtitle: String(localized: "Réduire l'espacement dans l'onglet des arrêts"),
                        isOn: $settings.reduceSpacerBtwnStopContentView
                    )
                }
                
                SettingsToggle(
                    icon: "lightspectrum.horizontal",
                    title: String(localized: "Contraste plus important"),
                    subtitle: settings.easyOnTheEyes ? String(localized: "Cette option est indisponible lorsque \"Mode confort\" est activée.") : String(localized: "Augmente la lisibilité de l'interface"),
                    isOn: $settings.highContrastButAccurateLinePill
                )
                .disabled(settings.easyOnTheEyes)
                
                SettingsToggle(
                    icon: "eyeglasses",
                    title: String(localized: "Mode confort"),
                    subtitle: settings.highContrastButAccurateLinePill ? String(localized: "Cette option est indisponible lorsque \"Contraste plus important\" est activé.") : String(localized: "Réduit la variété de couleurs dans l'application."),
                    isOn: $settings.easyOnTheEyes
                )
                .disabled(settings.highContrastButAccurateLinePill)
                
                NavigationLink(destination: AccentColorCustomizerView()) {
                    SettingsRow(
                        icon: "paintpalette",
                        title: String(localized: "Couleur de l'app"),
                        subtitle: String(localized: "Personnalisez l'apparence de l'application"),
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                NavigationLink(destination: ColorSchemeSelectionView(dimiss: {dismiss()})) {
                    SettingsRow(
                        icon: "circle.lefthalf.filled",
                        title: String(localized: "Mode d'affichage"),
                        subtitle: String(localized: "Chosissez la mode d'affichage de l'app (clair, sombre, auto..)"),
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                NavigationLink(destination: WidgetStopSelectorView()) {
                    SettingsRow(
                        icon: { if #available(iOS 18, *) { "widget.small" } else { "eye" } }(),
                        title: String(localized: "Widget"),
                        subtitle: String(localized: "Personnalisez le Widget de l'app en sélectionnant un arrêt à afficher"),
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
            } header: {
                SectionHeader(
                    icon: "paintbrush.fill",
                    iconColor: .red,
                    title: String(localized: "Personnalisation"),
                    subtitle: String(localized: "Adaptez l'interface à vos préférences")
                )
            }
        }
    }
    
    private var lineScoreCard: some View {
        SettingsCard {
            Section {
                NavigationLink(destination: LineScoreView()) {
                    SettingsRow(
                        icon: "chart.bar.fill",
                        title: String(localized: "Lignes préférées"),
                        subtitle: {
                            let highScoreLines = lineScoreManager.lineScores.filter { $0.totalScore >= 2.0 }
                            return highScoreLines.isEmpty ? String(localized: "Aucune ligne enregistrée") :
                            "\(highScoreLines.count) \(String(localized: "ligne"))\(highScoreLines.count > 1 ? String(localized: "s") : "")"
                        }(),
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
            } header: {
                SectionHeader(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: String(localized: "Lignes"),
                    subtitle: String(localized: "Gérez les lignes que vous fréquentez le plus souvent.")
                )
            }
        }
    }
    
    private var experimentalCard: some View {
        SettingsCard {
            Section {
                SettingsToggle(
                    icon: "exclamationmark.bubble",
                    title: String(localized: "Contribuer à CrowdBack"),
                    subtitle: String(localized: "Consultez et partagez des informations en temps réel sur les transports."),
                    isOn: $settings.crowdbackAllowed
                )
                SettingsToggle(
                    icon: "figure.walk",
                    title: String(localized: "Obtenir les instructions"),
                    subtitle: String(localized: "Calculer les instructions de marche via MKDirection"),
                    isOn: $settings.fetchWalkingDirectionsUsingMKDirections
                )
                SettingsPicker(
                    icon: { if #available(iOS 17.2, *) { "square.and.arrow.up.badge.clock" } else { "square.and.arrow.up" } }(),
                    title: String(localized: "Durée de partage d'itinéraire"),
                    subtitle: String(localized: "Choisissez combien de temps un itinéraire partagé reste accessible") + (settings.luxTripShareExpiryTimeH >= 4320 ? "\n⚠︎ " + String(localized: "Le temps d'expiration sélectionné est élevé. Lux ne peut garantir une telle période de rétention.") : ""),
                    selection: $settings.luxTripShareExpiryTimeH,
                    options: [
                        (24, String(localized: "1 jour")),
                        (168, String(localized: "7 jours")),
                        (720, String(localized: "1 mois")),
                        (4320, String(localized: "6 mois")),
                        (8760, String(localized: "1 an"))
                    ]
                )
            } header: {
                SectionHeader(
                    icon: "flask.fill",
                    iconColor: .purple,
                    title: String(localized: "Fonctionnalités expérimentales"),
                    subtitle: "⚠️ " + String(localized: "Effectuer des changements n'est pas recommandé")
                )
            }
        }
    }
    
    private var aboutCard: some View {
        SettingsCard {
            Section {
                NavigationLink(destination: CreditsView()) {
                    SettingsRow(
                        icon: "heart.fill",
                        title: String(localized: "Crédits"),
                        subtitle: String(localized: "Liste des modules utilisés dans l'application"),
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                SettingsRow(
                    icon: "lock.shield",
                    title: String(localized: "Politique de confidentialité"),
                    subtitle: String(localized: "Consultez la politique de confidentialité en ligne"),
                    showChevron: true
                )
                .onTapGesture {
                    if Locale.current.language.languageCode == "fr", let url = URL(string: "https://lux.cclerc.ch/privacy/fr.html") {
                        UIApplication.shared.open(url)
                    } else if let url = URL(string: "https://lux.cclerc.ch/privacy/en.html") {
                        UIApplication.shared.open(url)
                    }
                }
                SettingsRow(
                    icon: "app.badge",
                    title: String(localized: "Version"),
                    // MARK: CHANGE THAT WHEN IN PROD
                    subtitle: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? String(localized: "Inconnue")) Beta \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? String(localized: "Inconnue"))",
                    showChevron: false
                )
            } header: {
                SectionHeader(
                    icon: "info.circle.fill",
                    iconColor: .gray,
                    title: String(localized: "À propos"),
                    subtitle: String(localized: "Informations sur l'application")
                )
            }
        }
    }
}
