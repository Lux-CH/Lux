//
//  StatsView.swift
//  Lux
//
//  Created by Constantin Clerc on 19.08.2025.
//
// MARK: this should only be used for debug purposes and should not be in prod (release)

import SwiftUI

struct StatsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var progress = Progress.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                headerCard
                SettingsCard {
                    Section {
                        stat(varName: "appLaunchCount", value: settings.appLaunchCount)
                        Divider()
                        stat(varName: "isFirstLaunch", value: settings.firstLaunch)
                        Divider()
                        stat(varName: "tripShareExpiryHours", value: settings.luxTripShareExpiryTimeH)
                        Divider()
                        if settings.customScheme {
                            stat(varName: "customAccent", value: settings.customSchemeSelection)
                            Divider()
                        }
                        stat(varName: "mkDirections", value: settings.fetchWalkingDirectionsUsingMKDirections)
                    } header: {
                        SectionHeader(
                            icon: "gearshape.2",
                            iconColor: .purple,
                            title: "settingsDomain",
                            subtitle: "Les paramètres ci-dessous sont issues du domaine \"settings\"."
                        )
                    }
                }
                SettingsCard {
                    Section {
                        stat(varName: "stopViewOpened", value: progress.numOfTimesStopViewWasOpened)
                        Divider()
                        stat(varName: "tripViewOpened", value: progress.numOfTimesTripViewWasOpened)
                    } header: {
                        SectionHeader(
                            icon: "trophy",
                            iconColor: .purple,
                            title: "progressDomain",
                            subtitle: "Les paramètres ci-dessous sont issues du domaine \"progress\"."
                        )
                    }
                }
                SettingsCard {
                    Section {
                        stat(varName: "stopViewOpened", value: progress.shownTripViewSuggestion)
                    } header: {
                        SectionHeader(
                            icon: "lightbulb",
                            iconColor: .purple,
                            title: "tipsDomain",
                            subtitle: "Les paramètres ci-dessous sont issues du domaine \"tips\"."
                        )
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    
    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text(verbatim: "Statistiques")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(verbatim: "Consultez les statistiques de votre usage de l'app (dev only)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private func stat(varName: String, value: Any) -> some View {
        HStack {
            Text(varName)
            Spacer()
            Text("\(value)")
                .fontDesign(.monospaced)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 15)
    }
}

#Preview {
    StatsView()
}
