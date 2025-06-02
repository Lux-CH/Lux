//
//  TicketsView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//

import SwiftUI

struct TicketsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    SettingsCard {
                        Section {
                            NavigationLink(destination: LuxPassView()) {
                                SettingsRow(
                                    icon: "person.text.rectangle",
                                    title: "LuxPass",
                                    subtitle: "Gérez vos tickets et ajoutez votre SwissPass à Lux.",
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    SettingsCard {
                        Section {
                            SettingsRow(icon: "xmark", title: "Aucun ticket disponible", subtitle: "Veuillez réessayer plus tard", showChevron: false)
                        } header: {
                            SectionHeader(
                                icon: "creditcard",
                                iconColor: .orange,
                                title: "Tickets TPG",
                                subtitle: "Achetez des tickets auprès des TPGs par SMS"
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tickets")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
