//
//  SettingsView.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var shortcutManager: ShortcutManager
    @ObservedObject var settings = Settings.shared
    
    @State private var showAddShortcutSheet = false
    @State private var editingShortcut: UserShortcut? = nil
    @State private var isReordering = false
    
    var body: some View {
        NavigationStack {
            List {
                shortcutsSection
                customisationSection
                experimentalSection
                infoSection
            }
            .environment(\.defaultMinListRowHeight, 60)
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
    
    private var shortcutsSection: some View {
        Section {
            ForEach(shortcutManager.shortcuts) { shortcut in
                shortcutRow(for: shortcut)
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
                        .foregroundColor(.accentColor)
                    Text("Ajouter un raccourci")
                        .foregroundColor(.accentColor)
                }
            }
            Toggle("Afficher les titres", isOn: $settings.showShortcutLabel)
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
                Text("Les deux premiers raccourcis seront affichés sur l'écran d'accueil.")
            }
        }
    }
    
    private func shortcutRow(for shortcut: UserShortcut) -> some View {
        HStack {
            Button {
                editingShortcut = shortcut
            } label: {
                Image(systemName: shortcut.symbol)
                    .foregroundColor(.accentColor)
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
                }
                
                Spacer()
                
                Image(systemName: "pencil")
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
    
    private var infoSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("À propos")
        }
    }
    private var customisationSection: some View {
        Section {
            Toggle("Afficher les images", isOn: $settings.showModern)
        } header: {
            Text("Personnalisation")
        }
    }
    private var experimentalSection: some View {
        Section {
            Toggle("Aperçu des trajets amélioré", isOn: $settings.getPolylineWithOSRM)
        } header: {
            Text("Experimental")
        } footer: {
            Text("""
Cette fonctionnalité permet de calculer les aperçus des trajets de bus (polylignes) à l'aide d'OSRM. Si le calcul est correct, cela permet d'améliorer la précision des estimations d’arrivée des bus.

L'activation des fonctionnalités ci-dessus n'est pas recommendée.
""")
        }
    }
}
