//
//  WidgetStopSelectorView.swift
//  Lux
//
//  Created by Constantin Clerc on 29.06.2025.
//

import SwiftUI
import LuxCom

struct WidgetStopSelectorView: View {
    @StateObject private var viewModel = WidgetStopSearchViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchQuery = ""
    @State private var selectedStopId: String?
    
    @FocusState private var isSearchFocused: Bool
    
    private var uniqueSearchResults: [SearchResult] {
        var seen = Set<String>()
        return viewModel.searchResults.filter { result in
            if seen.contains(result.id) {
                return false
            } else {
                seen.insert(result.id)
                return true
            }
        }
    }
    
    private var isLocationAuthorized: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        Color(.systemGroupedBackground)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        if viewModel.showMinCharactersMessage && searchQuery.isEmpty {
                            contentWithCurrentLocation
                                .frame(width: geometry.size.width)
                                .transition(.opacity)
                        } else if viewModel.searchResults.isEmpty && !searchQuery.isEmpty {
                            noResultsWithCurrentLocation
                                .frame(width: geometry.size.width)
                                .transition(.opacity)
                        } else {
                            searchResultsList
                                .frame(width: geometry.size.width)
                                .transition(.opacity)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
                .animation(.easeInOut(duration: 0.2), value: viewModel.showMinCharactersMessage)
                .animation(.easeInOut(duration: 0.2), value: viewModel.searchResults.isEmpty)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Sélectionner un arrêt")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isSearchFocused = true
                loadCurrentSelection()
                viewModel.performSearch(searchQuery)
            }
            .onChange(of: searchQuery) {
                viewModel.performSearch(searchQuery)
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Rechercher un arrêt...", text: $searchQuery)
                .disableAutocorrection(true)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    viewModel.performSearch(searchQuery)
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    viewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .zIndex(1)
    }
    
    private var searchResultsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                currentLocationOption
                
                Divider()
                    .padding(.leading)
                
                ForEach(uniqueSearchResults) { result in
                    Button {
                        saveSelection(result)
                    } label: {
                        WidgetStopRow(
                            result: result,
                            isSelected: selectedStopId == result.id
                        )
                        .padding()
                        .background(Color(.secondarySystemBackground))
                    }
                    
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }
    
    private var contentWithCurrentLocation: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    currentLocationOption
                    
                    Divider()
                        .padding(.leading)
                }
            }
            
            VStack(spacing: 16) {
                if let currentStopId = selectedStopId {
                    if currentStopId == "current" {
                        Image(systemName: "location.fill.viewfinder")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Position actuelle sélectionnée")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Le widget affichera l'arrêt le plus proche de votre position actuelle.\nCommencez à taper pour choisir un arrêt fixe.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Image(systemName: "signpost.right")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Arrêt sélectionné")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Commencez à taper pour rechercher un autre arrêt.\n3 caractères minimum sont requis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Aucun arrêt sélectionné")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Choisissez votre position actuelle ou commencez à taper pour rechercher un arrêt.\n3 caractères minimum sont requis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var noResultsWithCurrentLocation: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    currentLocationOption
                    
                    Divider()
                        .padding(.leading)
                }
            }
            
            VStack(spacing: 12) {
                Image(systemName: "questionmark")
                    .font(.system(size: 30))
                    .foregroundColor(.secondary)
                
                Text("Aucun résultat trouvé.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var currentLocationOption: some View {
        Button {
            if isLocationAuthorized {
                saveCurrentLocationSelection()
            } else {
                locationManager.requestLoc()
            }
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                        .symbolRenderingMode(.hierarchical)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Position actuelle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if !isLocationAuthorized {
                        Text("Autorisation requise")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    } else {
                        Text("Fréquemment mis à jour sur l'arrêt le plus proche")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: selectedStopId == "current" ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selectedStopId == "current" ? .accentColor : .secondary.opacity(0.7))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
    }
    
    private var minCharactersMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "signpost.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            if let currentStopId = selectedStopId {
                if currentStopId == "current" {
                    Text("Position actuelle sélectionnée")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Le widget affichera l'arrêt le plus proche de votre position actuelle.\nCommencez à taper pour choisir un arrêt fixe.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Arrêt sélectionné")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Commencez à taper pour rechercher un autre arrêt.\n3 caractères minimum sont requis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                Text("Aucun arrêt sélectionné")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Choisissez votre position actuelle ou commencez à taper pour rechercher un arrêt.\n3 caractères minimum sont requis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var noResultsMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            
            Text("Aucun résultat trouvé.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private func saveSelection(_ result: SearchResult) {
        selectedStopId = result.id
        guard let stopId = selectedStopId else { return }
        WidgetManager.shared.setSelectedStopId(stopId)
        WidgetManager.shared.requestWidgetRefresh()
    }
    
    private func saveCurrentLocationSelection() {
        selectedStopId = "current"
        WidgetManager.shared.setSelectedStopId("current")
        WidgetManager.shared.requestWidgetRefresh()
    }
    
    private func loadCurrentSelection() {
        selectedStopId = WidgetManager.shared.getSelectedStopId()
    }
}

struct WidgetStopRow: View {
    let result: SearchResult
    let isSelected: Bool
    
    private func relevantArea() -> String? {
        if let matchedArea = result.areas.first(where: { $0.matched }) {
            return matchedArea.name
        } else if let defaultArea = result.areas.first(where: { $0.default == true }) {
            return defaultArea.name
        } else if !result.areas.isEmpty {
            return result.areas.sorted(by: { $0.adminLevel < $1.adminLevel }).first?.name
        }
        
        return nil
    }
    
    var body: some View {
        HStack(spacing: 18) {
//            ZStack {
//                Circle()
//                    .fill(Color.accentColor.opacity(0.15))
//                    .frame(width: 44, height: 44)
//                
//                Image(systemName: "signpost.right.fill")
//                    .font(.system(size: 18))
//                    .foregroundColor(.accentColor)
//                    .symbolRenderingMode(.hierarchical)
//            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                if let area = relevantArea() {
                    Text(area)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.7))
        }
        .contentShape(Rectangle())
    }
}

class WidgetStopSearchViewModel: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var showMinCharactersMessage = true
    
    private let minimumCharacters = 3
    
    func performSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            showMinCharactersMessage = true
            return
        }
        
        guard trimmedQuery.count >= minimumCharacters else {
            searchResults = []
            showMinCharactersMessage = true
            return
        }
        
        showMinCharactersMessage = false
        
        Task {
            await searchStops(query: trimmedQuery)
        }
    }
    
    @MainActor
    private func searchStops(query: String) async {
        isLoading = true
        
        do {
            let results = try await geocode(
                text: query,
                type: .stop
            )
            
            searchResults = results
            isLoading = false
        } catch {
            searchResults = []
            isLoading = false
            print("Erreur de recherche: \(error)")
        }
    }
}

#Preview {
    WidgetStopSelectorView()
}
