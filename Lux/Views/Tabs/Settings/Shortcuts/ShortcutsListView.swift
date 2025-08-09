//
//  ShortcutsListView.swift
//  Lux
//
//  Created by Constantin Clerc on 30.07.2025.
//

import SwiftUI

struct ShortcutsListView: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    @EnvironmentObject private var shortcutManager: ShortcutManager
    @ObservedObject var settings = Settings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddShortcutSheet = false
    @State private var editingShortcut: UserShortcut? = nil
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                headerCard
                
                VStack(spacing: 8) {
                    shortcutsCard
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $editingShortcut) { shortcut in
            ShortcutEditorView(shortcutToEdit: shortcut)
        }
        .sheet(isPresented: $showAddShortcutSheet) {
            ShortcutEditorView(shortcutToEdit: nil)
        }
    }
    
    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 40))
                .foregroundColor(accentColorManager.selectedAccentColor)
            
            Text("Raccourcis")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Accès rapide à vos destinations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
    
    private var shortcutsCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(
                    icon: "list.star",
                    iconColor: .blue,
                    title: "Raccourcis",
                    subtitle: shortcutManager.shortcuts.isEmpty ?
                    String(localized: "Aucun raccourci configuré") :
                        String(localized: "\(shortcutManager.visibleShortcuts.count)/\(shortcutManager.shortcuts.count) affichés")
                )
                
                List {
                    ForEach(shortcutManager.shortcuts) { shortcut in
                        VStack(spacing: 0) {
                            Button {
                                editingShortcut = shortcut
                            } label: {
                                shortcutRow(for: shortcut)
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .padding(.leading, 25)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
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
                        .padding(.vertical, 10)
                        .padding(.leading, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: shortcutManager.shortcuts.isEmpty ? 50 : CGFloat(shortcutManager.shortcuts.count) * 70 + 95)
                
                if !shortcutManager.shortcuts.isEmpty {
                    Text(settings.useTimeBasedRelevance ?
                         "Les raccourcis seront triés par pertinence temporelle. Les plus proches en termes d'horaire et de jour seront affichés en premier, sauf si vous êtes très proche de la destination." :
                         "Les deux premiers raccourcis seront affichés sur l'écran d'accueil.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }
            }
        }
    }
    
    private func shortcutRow(for shortcut: UserShortcut) -> some View {
        HStack {
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
                                .foregroundStyle(Color.accentColor)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
