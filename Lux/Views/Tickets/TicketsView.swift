//
//  TicketsView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//

import SwiftUI
import LuxCom
import MessageUI

struct TicketsView: View {
    @State private var ticketsInfo = TicketsInfo()
    @State private var selectedUserType: UserType = .adulte
    
    @ObservedObject private var luxPassManager = LuxPassManager.shared
    @ObservedObject var settings = Settings.shared
    
    private var filteredTickets: [TicketCategory: [TicketInfo]] {
        let grouped = Dictionary(grouping: ticketsInfo.tickets) { $0.category }
        return grouped.mapValues { tickets in
            tickets.sorted { $0.duration < $1.duration }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    SettingsCard {
                        NavigationLink(destination: LuxPassView(showSwisspassOnHome: $settings.swisspassOnHome, isFromHome: false)) {
                            LuxPassRow()
                        }
                        .buttonStyle(.plain)
                        
                        if luxPassManager.hasSwissPass {
                            Divider()
                                .padding(.horizontal, 20)
                            SettingsToggle(icon: "house", title: String(localized: "Afficher LuxPass sur l'écran d'accueil"), subtitle: String(localized: "Ajouter un accès rapide à votre SwissPass en remplacant un raccourcis"), isOn: $settings.swisspassOnHome)
                        }
                    }
                    
                    UserTypeSelector(selectedUserType: $selectedUserType)
                    
                    ForEach(TicketCategory.allCases, id: \.self) { category in
                        if let tickets = filteredTickets[category], !tickets.isEmpty {
                            TicketCategorySection(
                                category: category,
                                tickets: tickets,
                                selectedUserType: selectedUserType
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tickets")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct UserTypeSelector: View {
    @Binding var selectedUserType: UserType
    
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type de tarif")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Sélectionnez votre catégorie tarifaire")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Picker("Type d'utilisateur", selection: $selectedUserType) {
                    ForEach(UserType.allCases, id: \.self) { userType in
                        Text(userType.rawValue)
                            .tag(userType)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                
                Text("Note : Les tickets ci-dessous seront achetés via un SMS envoyé au service officiel des TPG suite à votre confirmation. Des frais SMS standard peuvent s'appliquer.\nLes tickets ne sont pas gérés par Lux et leurs tarifs peuvent évoluer à tout moment sans préavis.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
            }
        }
    }
}

struct TicketCategorySection: View {
    let category: TicketCategory
    let tickets: [TicketInfo]
    let selectedUserType: UserType
    
    private var categoryIcon: String {
        switch category {
        case .toutGeneve:
            return "building.2.fill"
        case .toutGeneveDayPass:
            return "calendar.badge.clock"
        case .lemanPassMultizone:
            return "map.fill"
        case .complementaryTickets:
            return "plus.circle.fill"
        case .frenchZoneTickets:
            return "flag.fill"
        }
    }
    
    private var categoryColor: Color {
        switch category {
        case .toutGeneve:
            return .green
        case .toutGeneveDayPass:
            return .orange
        case .lemanPassMultizone:
            return .blue
        case .complementaryTickets:
            return .purple
        case .frenchZoneTickets:
            return .red
        }
    }
    
    private var filteredTickets: [TicketInfo] {
        tickets.filter { $0.userType == selectedUserType }
    }
    
    var body: some View {
        if !filteredTickets.isEmpty {
            SettingsCard {
                VStack(spacing: 0) {
                    CategoryHeader(
                        icon: categoryIcon,
                        color: categoryColor,
                        title: category.rawValue
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredTickets.enumerated()), id: \.element.smsCode) { index, ticket in
                            TicketRow(ticket: ticket)
                            
                            if index < filteredTickets.count - 1 {
                                Divider()
                                    .padding(.leading, 68)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CategoryHeader: View {
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding(10)
    }
}

struct TicketRow: View {
    let ticket: TicketInfo
    @ObservedObject private var luxPassManager = LuxPassManager.shared
    
    @State private var showingMessageComposer = false
    @State private var uncompatibleAlert: Bool = false
    
    private var durationText: String {
        let totalSeconds = ticket.duration.components.seconds
        let totalMinutes = totalSeconds / 60
        let minutes = (totalSeconds % 3600) / 60
        
        if totalMinutes >= 100 {
            if minutes == 0 {
                return "\(totalSeconds / 3600)h"
            }
            return "\(totalSeconds / 3600)h\(minutes)"
        }
        else {
            return "\(totalMinutes)'"
        }
    }
    
    var body: some View {
        Button(action: {
            if MFMessageComposeViewController.canSendText() {
                showingMessageComposer = true
            } else {
                uncompatibleAlert = true
            }
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .center) {
                    Text(durationText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        let isCHF = Locale.current.currency == "CHF"
                        Text(isCHF ? "CHF \(ticket.priceCHF, specifier: "%.2f")" : "\(ticket.priceEUR, specifier: "%.2f") €")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Text(isCHF ? "/ \(ticket.priceEUR, specifier: "%.2f") €" : "/ CHF \(ticket.priceCHF, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposerView(
                recipients: ["788"],
                messageBody: ticket.smsCode,
                onResult: { result in
                    if result == .sent {
                        luxPassManager.addTicket(ticketName: ticket.title, duration: TimeInterval(ticket.duration.components.seconds))
                    }
                }
            )
            .ignoresSafeArea()
        }
        .alert("Impossible d'envoyer le SMS", isPresented: $uncompatibleAlert) {
                    Button("OK") { }
        } message: {
            Text("Votre appareil n'est pas en mesure d'envoyer des SMS.")
        }
    }
}

struct LuxPassRow: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.red, Color(red: 0.8, green: 0.1, blue: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "person.text.rectangle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("LuxPass")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Gérez vos tickets et ajoutez votre SwissPass à Lux.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
    }
}

#Preview {
    TicketsView()
}
