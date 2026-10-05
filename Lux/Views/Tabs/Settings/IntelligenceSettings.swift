//
//  IntelligenceSettings.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import SwiftUI
import EventKit

struct IntelligenceSettingsCard: View {
    @ObservedObject private var store = IntelligenceStore.shared
    @State private var showsSetup = false
    @State private var calendarStatus = EKEventStore.authorizationStatus(for: .event)

    var body: some View {
        SettingsCard {
            Section {
                Button {
                    showsSetup = true
                } label: {
                    SettingsRow(
                        icon: "sparkles",
                        title: String(localized: "Préférences"),
                        subtitle: store.profile.isConfigured
                            ? String(localized: "Météo, affluence, marche et habitudes")
                            : String(localized: "Quelques questions pour l'adapter à vous"),
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)

                SettingsToggle(
                    icon: "bell.badge.fill",
                    title: String(localized: "Alertes de départ"),
                    subtitle: String(localized: "Une notification au bon moment pour vos raccourcis programmés et vos rendez-vous."),
                    isOn: Binding(
                        get: { store.departureAlerts },
                        set: { enabled in Task { await DepartureAlertPlanner.shared.setEnabled(enabled) } }
                    )
                )

                if store.departureAlerts && calendarStatus != .fullAccess {
                    Button {
                        Task {
                            _ = try? await EKEventStore().requestFullAccessToEvents()
                            calendarStatus = EKEventStore.authorizationStatus(for: .event)
                            DepartureAlertPlanner.shared.refresh(force: true)
                        }
                    } label: {
                        SettingsRow(
                            icon: "calendar.badge.plus",
                            title: String(localized: "Inclure le calendrier"),
                            subtitle: String(localized: "Prévenir aussi pour les rendez-vous qui ont un lieu"),
                            showChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                SettingsToggle(
                    icon: "brain",
                    title: String(localized: "Apprendre de mes choix"),
                    subtitle: String(localized: "Intelligent s'ajuste doucement d'après les trajets que vous choisissez vraiment."),
                    isOn: Binding(
                        get: { store.learning.isEnabled },
                        set: { store.learning.isEnabled = $0 }
                    )
                )

                if store.learning.isEnabled {
                    NavigationLink(destination: IntelligenceLearningView()) {
                        SettingsRow(
                            icon: "list.bullet.rectangle",
                            title: String(localized: "Ce que Lux a appris"),
                            subtitle: store.learning.observations == 0
                                ? String(localized: "Rien pour l'instant")
                                : String(localized: "D'après \(store.learning.observations) choix"),
                            showChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                SectionHeader(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: String(localized: "Intelligent"),
                    subtitle: String(localized: "Suggestions selon la météo, l'affluence et vos habitudes")
                )
            }
        }
        .sheet(isPresented: $showsSetup) {
            IntelligenceSetupView()
                .presentationCornerRadius(36)
        }
        .onAppear {
            calendarStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
}

struct IntelligenceLearningView: View {
    @ObservedObject private var store = IntelligenceStore.shared
    @State private var confirmsReset = false

    var body: some View {
        let learned = IntelligenceLearner.summary(of: store.learning)
        ScrollView {
            VStack(spacing: 16) {
                SettingsCard {
                    Section {
                        if learned.isEmpty {
                            SettingsRow(
                                icon: "hourglass",
                                title: store.learning.observations == 0
                                    ? String(localized: "Rien pour l'instant")
                                    : String(localized: "Rien de marquant"),
                                subtitle: store.learning.observations == 0
                                    ? String(localized: "Choisissez quelques trajets, Lux prend des notes.")
                                    : String(localized: "Vos réponses font foi."),
                                showChevron: false
                            )
                        } else {
                            ForEach(learned, id: \.self) { line in
                                SettingsRow(icon: line.symbol, title: line.text, subtitle: "", showChevron: false)
                            }
                        }
                    } header: {
                        SectionHeader(
                            icon: "brain",
                            iconColor: .purple,
                            title: String(localized: "Ce que Lux a appris"),
                            subtitle: String(localized: "D'après \(store.learning.observations) choix")
                        )
                    }
                }

                if store.learning.observations > 0 {
                    SettingsCard {
                        Button {
                            confirmsReset = true
                        } label: {
                            HStack {
                                Text("Effacer l'apprentissage")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Apprentissage")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Effacer l'apprentissage", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) {
                store.learning = store.learning.erased()
                HapticFeedback.mediumImpact()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Intelligent oubliera ce qu'il a appris de vos choix. Vos réponses sont conservées.")
        }
    }
}
