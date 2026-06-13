//
//  OfflineSettingsView.swift
//  Lux
//
//  Created by Constantin Clerc on 13.06.2026.
//

import SwiftUI

struct OfflineSettingsView: View {
    @EnvironmentObject private var offline: OfflineManager
    @ObservedObject var settings = Settings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDeleteConfirm = false
    @State private var showDisableConfirm = false
    @State private var showCellularWarning = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                enableCard

                if settings.offlineModeEnabled {
                    statusCard
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    if offline.datasetReady {
                        optionsCard
                            .transition(.opacity)
                    }
                }

                footnote
            }
            .padding(.vertical)
            .animation(.easeInOut(duration: 0.25), value: settings.offlineModeEnabled)
            .animation(.easeInOut(duration: 0.25), value: offline.datasetReady)
            .animation(.easeInOut(duration: 0.25), value: offline.state)
        }
        .background(colorScheme == .light ? Color(.secondarySystemBackground) : Color(.systemBackground))
        .navigationTitle("Mode hors ligne")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            String(localized: "Supprimer les données hors ligne ?"),
            isPresented: $showDisableConfirm, titleVisibility: .visible
        ) {
            Button(String(localized: "Supprimer"), role: .destructive) { offline.disable() }
            Button(String(localized: "Annuler"), role: .cancel) {}
        } message: {
            Text("Les horaires téléchargés seront supprimés de votre appareil.")
        }
        .alert(String(localized: "Données cellulaires"), isPresented: $showCellularWarning) {
            Button(String(localized: "Télécharger quand même")) { offline.startImport() }
            Button(String(localized: "Annuler"), role: .cancel) {}
        } message: {
            Text("Vous êtes en données cellulaires. Le téléchargement des horaires peut consommer plusieurs Mo de votre forfait. Préférez une connexion Wi-Fi.")
        }
    }

    private var enableCard: some View {
        SettingsCard {
            Section {
                SettingsToggle(
                    icon: "icloud.slash",
                    title: String(localized: "Mode hors ligne"),
                    subtitle: String(localized: "Téléchargez les horaires de la région pour consulter les départs et itinéraires sans connexion."),
                    isOn: Binding(
                        get: { settings.offlineModeEnabled },
                        set: { isOn in
                            if isOn {
                                offline.enable()
                                if offline.needsInitialDownload { requestDownload() }
                            } else {
                                showDisableConfirm = true
                            }
                        }
                    )
                )
            } header: {
                SectionHeader(
                    icon: "wifi.slash",
                    iconColor: .gray,
                    title: String(localized: "Hors ligne"),
                    subtitle: String(localized: "Accès aux horaires sans connexion Internet")
                )
            }
        }
        .padding(.horizontal)
    }

    private var statusCard: some View {
        VStack(spacing: 16) {
            Image(systemName: status.icon)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(status.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(height: 66)

            VStack(spacing: 4) {
                Text(status.title)
                    .font(.headline)
                if !status.subtitle.isEmpty {
                    Text(status.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if status.isBusy {
                VStack(spacing: 6) {
                    ProgressView(value: status.fraction, total: 1)
                        .progressViewStyle(.linear)
                        .tint(status.tint)
                    if let pct = status.percentText {
                        Text(pct)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            } else if let action = status.action {
                Button(action: action.run) {
                    Label(action.title, systemImage: action.icon)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(status.tint, in: Capsule())
                .foregroundStyle(.white)
                .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(colorScheme == .light ? Color.white : Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(colorScheme == .light ? 0.06 : 0), radius: 10, y: 4)
        .padding(.horizontal)
    }

    private var optionsCard: some View {
        SettingsCard {
            Section {
                SettingsToggle(
                    icon: "airplane",
                    title: String(localized: "Forcer le mode hors ligne"),
                    subtitle: String(localized: "Utiliser les données locales même lorsqu’une connexion est disponible."),
                    isOn: Binding(
                        get: { settings.offlineForceOffline },
                        set: { offline.setForceOffline($0) }
                    )
                )
                Button { showDeleteConfirm = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.title3).foregroundColor(.red).frame(width: 24, height: 24)
                        Text("Supprimer les données hors ligne")
                            .font(.body).foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    String(localized: "Supprimer les données hors ligne ?"),
                    isPresented: $showDeleteConfirm, titleVisibility: .visible
                ) {
                    Button(String(localized: "Supprimer"), role: .destructive) { offline.disable() }
                    Button(String(localized: "Annuler"), role: .cancel) {}
                } message: {
                    Text("Les horaires téléchargés seront supprimés de votre appareil.")
                }
            }
        }
        .padding(.horizontal)
    }

    private var footnote: some View {
        Text("Hors ligne, les horaires affichés sont théoriques (sans temps réel) et la planification, le partage et l’enregistrement d’itinéraires sont indisponibles.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 4)
    }

    private func requestDownload() {
        if offline.isOnWiFi || !offline.isOnline {
            offline.startImport()
        } else {
            showCellularWarning = true
        }
    }

    private struct Action { let title: String; let icon: String; let run: () -> Void }

    private struct Status {
        var icon: String
        var tint: Color
        var title: String
        var subtitle: String
        var isBusy: Bool
        var fraction: Double?
        var percentText: String?
        var action: Action?
    }

    private var status: Status {
        switch offline.state {
        case .absent:
            return Status(
                icon: "arrow.down.circle", tint: .accentColor,
                title: String(localized: "Télécharger les horaires"),
                subtitle: String(localized: "~450Mo · connexion Wi-Fi recommandée"),
                isBusy: false, fraction: nil, percentText: nil,
                action: Action(title: String(localized: "Télécharger"),
                               icon: "arrow.down", run: requestDownload)
            )
        case .downloading(let p):
            return Status(
                icon: "arrow.down.circle", tint: .accentColor,
                title: String(localized: "Téléchargement…"),
                subtitle: String(localized: "Récupération des horaires de la région"),
                isBusy: true, fraction: min(max(p, 0), 1),
                percentText: "\(Int(min(max(p, 0), 1) * 100)) %", action: nil
            )
        case .extracting:
            return Status(
                icon: "shippingbox", tint: .accentColor,
                title: String(localized: "Installation…"),
                subtitle: String(localized: "Mise en place de la base de données"),
                isBusy: true, fraction: nil, percentText: nil, action: nil
            )
        case .ready:
            return Status(
                icon: "checkmark.circle.fill", tint: .green,
                title: String(localized: "Horaires disponibles"),
                subtitle: readySubtitle, isBusy: false, fraction: nil, percentText: nil,
                action: Action(title: String(localized: "Mettre à jour"),
                               icon: "arrow.clockwise", run: requestDownload)
            )
        case .failed(let message):
            return Status(
                icon: "exclamationmark.triangle.fill", tint: .orange,
                title: String(localized: "Échec du téléchargement"),
                subtitle: message, isBusy: false, fraction: nil, percentText: nil,
                action: Action(title: String(localized: "Réessayer"),
                               icon: "arrow.clockwise", run: requestDownload)
            )
        }
    }

    private var readySubtitle: String {
        var parts: [String] = []
        if let date = offline.lastImportDate {
            let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .none
            parts.append(String(localized: "Mis à jour le ") + fmt.string(from: date))
        }
        if offline.bytesOnDisk > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(offline.bytesOnDisk), countStyle: .file))
        }
        return parts.joined(separator: " · ")
    }
}
