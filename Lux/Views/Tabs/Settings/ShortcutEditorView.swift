//
//  ShortcutEditorView.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import SwiftUI
import SymbolPicker
import LuxCom

struct ShortcutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ShortcutEditorViewModel()
    @EnvironmentObject private var shortcutManager: ShortcutManager
    @EnvironmentObject private var locationManager: LocationManager
    
    var shortcutToEdit: UserShortcut?
    
    @State private var name: String = ""
    @State private var selectedSymbol: String = "house"
    @State private var searchQuery: String = ""
    @State private var selectedLocation: SearchResult?
    @State private var showSymbolPicker = false
    @State private var isSearchActive = false
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        nameSection
                        
                        symbolSection
                        
                        locationSection
                        Spacer()
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(isEditing ? "Modifier le raccourci" : "Nouveau raccourci")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Enregistrer" : "Ajouter") {
                        saveShortcut()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedLocation == nil)
                }
            }
            .onAppear {
                setupForEditing()
            }
            .sheet(isPresented: $showSymbolPicker) {
                SymbolPicker(symbol: $selectedSymbol)
                    .navigationTitle("Choisir un symbole")
            }
            .sheet(isPresented: $isSearchActive) {
                LocationSearchView(
                    searchQuery: $searchQuery,
                    selectedLocation: $selectedLocation,
                    onLocationSelected: { location in
                        selectedLocation = location
                        isSearchActive = false
                    }
                )
            }
        }
    }
    
    private func setupForEditing() {
        if let shortcut = shortcutToEdit {
            isEditing = true
            name = shortcut.name
            selectedSymbol = shortcut.symbol
            
            viewModel.convertToSearchResult(shortcut: shortcut) { result in
                if let result = result {
                    selectedLocation = result
                }
            }
        }
    }
    
    private func saveShortcut() {
        guard let location = selectedLocation,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let coordinates = UserShortcut.Coordinates(
            latitude: location.lat,
            longitude: location.lon,
            locationName: location.name
        )
        
        if isEditing, let shortcutId = shortcutToEdit?.id {
            let updatedShortcut = UserShortcut(
                id: shortcutId,
                name: name,
                symbol: selectedSymbol,
                coordinates: coordinates
            )
            shortcutManager.updateShortcut(updatedShortcut)
        } else {
            let newShortcut = UserShortcut(
                name: name,
                symbol: selectedSymbol,
                coordinates: coordinates
            )
            shortcutManager.addShortcut(newShortcut)
        }
        
        dismiss()
    }
    
    // MARK: - UI Components
    private var headerSection: some View {
        VStack(spacing: 16) {
            if !isEditing {
                Text("Créez un raccourci pour accéder rapidement à vos destinations préférées")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
        }
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nom du raccourci")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            TextField("Ex: Maison, Travail, École...", text: $name)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }
    
    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icône")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Button {
                showSymbolPicker = true
            } label: {
                HStack {
                    Image(systemName: selectedSymbol)
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 40)
                    
                    Text(selectedSymbol)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Destination")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Button {
                isSearchActive = true
            } label: {
                HStack {
                    if let location = selectedLocation {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                        
                        Text(location.name)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Rechercher une destination")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            if selectedLocation == nil {
                Button {
                    viewModel.useCurrentLocation(locationManager: locationManager) { result in
                        if let result = result {
                            selectedLocation = result
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.accentColor)
                            .font(.headline)
                        
                        Text("Utiliser ma position actuelle")
                            .foregroundColor(.accentColor)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
}
