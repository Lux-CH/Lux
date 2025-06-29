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
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var shortcutManager: ShortcutManager
    @ObservedObject var settings = Settings.shared
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    @State private var showAddShortcutSheet = false
    @State private var editingShortcut: UserShortcut? = nil
    @State private var isReordering = false
    
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
            .sheet(item: $editingShortcut) { shortcut in
                ShortcutEditorView(shortcutToEdit: shortcut)
            }
            .sheet(isPresented: $showAddShortcutSheet) {
                ShortcutEditorView(shortcutToEdit: nil)
            }
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
                
                SettingsToggle(
                    icon: "rectangle.compress.vertical",
                    title: "Interface compacte",
                    subtitle: "Réduire l'espacement dans l'onglet des arrêts",
                    isOn: $settings.reduceSpacerBtwnStopContent
                )
    
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
//                SettingsRow(
//                    icon: "antenna.radiowaves.left.and.right",
//                    title: "Origine des perturbations",
//                    subtitle: "Les perturbations sont obtenues depuis l'API de l'application TPGMax. Nous vous invitons à tester cette autre alternative !",
//                    showChevron: false
//                )
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

// MARK: - Supporting Views

struct SettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SectionHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(iconColor)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

struct SettingsRow: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared

    let icon: String
    let title: String
    let subtitle: String
    let showChevron: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(accentColorManager.selectedAccentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct SettingsToggle: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(accentColorManager.selectedAccentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Shortcuts List View
struct ShortcutsListView: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    @EnvironmentObject private var shortcutManager: ShortcutManager
    @ObservedObject var settings = Settings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddShortcutSheet = false
    @State private var editingShortcut: UserShortcut? = nil
    
    var body: some View {
        List {
            Section {
                ForEach(shortcutManager.shortcuts) { shortcut in
                    Button {
                        editingShortcut = shortcut
                    } label: {
                        shortcutRow(for: shortcut)
                    }
                    .buttonStyle(.plain)
                }
                .onMove { from, to in
                    if let index = from.first {
                        shortcutManager.moveShortcut(fromIndex: index, toIndex: to)
                    }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        let shortcutId = shortcutManager.shortcuts[index].id
                        shortcutManager.deleteShortcut(withId: shortcutId)
                    }
                }
                
                Button {
                    showAddShortcutSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(accentColorManager.selectedAccentColor)
                        Text("Ajouter un raccourci")
                            .foregroundColor(accentColorManager.selectedAccentColor)
                    }
                    .padding(.vertical, 8)
                }
                
            } header: {
                HStack {
                    Text("Raccourcis")
                    
                    if !shortcutManager.shortcuts.isEmpty {
                        Spacer()
                        
                        Text("\(shortcutManager.visibleShortcuts.count)/\(shortcutManager.shortcuts.count) affichés")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            } footer: {
                if !shortcutManager.shortcuts.isEmpty {
                    if settings.useTimeBasedRelevance {
                        Text("Les raccourcis seront triés par pertinence temporelle. Les plus proches en termes d'horaire et de jour seront affichés en premier, sauf si vous êtes très proche de la destination.")
                    } else {
                        Text("Les deux premiers raccourcis seront affichés sur l'écran d'accueil.")
                    }
                }
            }
        }
        .navigationTitle("Raccourcis")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editingShortcut) { shortcut in
            ShortcutEditorView(shortcutToEdit: shortcut)
        }
        .sheet(isPresented: $showAddShortcutSheet) {
            ShortcutEditorView(shortcutToEdit: nil)
        }
    }
    
    private func shortcutRow(for shortcut: UserShortcut) -> some View {
        HStack {
            Button {
                editingShortcut = shortcut
            } label: {
                Image(systemName: shortcut.symbol)
                    .foregroundColor(accentColorManager.selectedAccentColor)
                    .font(.title3)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(shortcut.name)
                        .fontWeight(.medium)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                    
                    Text(shortcut.coordinates.locationName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let schedule = shortcut.timeSchedule {
                        HStack {
                            ForEach(Array(schedule.daysOfWeek.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { day in
                                Text(day.displayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(accentColorManager.selectedAccentColor.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            Text(schedule.time.displayString)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "pencil")
                    .foregroundColor(accentColorManager.selectedAccentColor)
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
