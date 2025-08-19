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
    @State private var showWelcome: Bool = false
    @State private var displayMode: Int = 0
    
    @State private var showSafari = false
    @State private var safariURL: URL?
    @State private var showMailComposer = false
    
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
            .sheet(isPresented: $showSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(
                    recipients: ["lux-help@cclerc.ch"],
                    subject: "Aide Lux",
                    messageBody: "\n\n---\nVeuillez ne pas supprimer le texte ci-dessous\nv\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "UNKNOWN")"
                )
                .ignoresSafeArea()
            }
        }
    }
    
    private func openInSafari(_ url: URL) {
        safariURL = url
        showSafari = true
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
                
                LineStylePicker(
                    icon: "lightspectrum.horizontal",
                    title: String(localized: "Affichage des lignes"),
                    subtitle: String(localized: "Choisissez comment les lignes sont affichées dans l'application"),
                    selection: $displayMode,
                    options: [
                        (0, String(localized: "Standard")),
                        (2, String(localized: "Confort")),
                        (1, String(localized: "Réaliste"))
                    ]
                )
                .onChange(of: displayMode) {
                    switch displayMode {
                    case 1:
                        settings.highContrastButAccurateLinePill = true
                        settings.easyOnTheEyes = false
                    case 2:
                        settings.highContrastButAccurateLinePill = false
                        settings.easyOnTheEyes = true
                    default:
                        settings.highContrastButAccurateLinePill = false
                        settings.easyOnTheEyes = false
                    }
                }
                .onAppear {
                    if settings.highContrastButAccurateLinePill {
                        displayMode = 1
                    } else if settings.easyOnTheEyes {
                        displayMode = 2
                    } else {
                        displayMode = 0
                    }
                }
                
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
                SettingsRow(
                    icon: "hand.wave",
                    title: String(localized: "Afficher l'écran de bienvenue"),
                    subtitle: String(localized: "Réaffiche l'écran initial visible lors de la première ouverture de l'app"),
                    showChevron: true,
                    external: true)
                .onTapGesture {
                    showWelcome = true
                }
                .fullScreenCover(isPresented: $showWelcome) {
                    WelcomeView()
                }
            } header: {
                SectionHeader(
                    icon: "flask.fill",
                    iconColor: .purple,
                    title: String(localized: "Fonctionnalités avancées"),
                    subtitle: String(localized: "Options pour les utilisateurs expérimentés")
                )
            }
        }
    }
    
    private var aboutCard: some View {
        SettingsCard {
            Section {
                NavigationLink(destination: CreditsView()) {
                    SettingsRow(
                        icon: "heart",
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
                    showChevron: true,
                    external: true
                )
                .onTapGesture {
                    if Locale.current.language.languageCode == "fr", let url = URL(string: "https://lux.cclerc.ch/privacy/fr.html") {
                        openInSafari(url)
                    } else if let url = URL(string: "https://lux.cclerc.ch/privacy/en.html") {
                        openInSafari(url)
                    }
                }
                
                // Modified help row to use MailComposerView instead of mailto
                SettingsRow(
                    icon: "questionmark.circle",
                    title: String(localized: "Aide"),
                    subtitle: String(localized: "Une question, un bug ou une suggestion ? Cliquez ici."),
                    showChevron: true,
                    external: true
                )
                .onTapGesture {
                    showMailComposer = true
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
