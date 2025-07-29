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
