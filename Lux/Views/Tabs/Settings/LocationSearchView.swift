//
//  LocationSearchView.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import SwiftUI
import LuxCom

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LocationSearchViewModel()
    @EnvironmentObject private var locationManager: LocationManager
    @Binding var searchQuery: String
    @Binding var selectedLocation: SearchResult?
    var onLocationSelected: (SearchResult) -> Void
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        Color(.systemGroupedBackground)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        if viewModel.showMinCharactersMessage {
                            minCharactersMessage
                                .frame(width: geometry.size.width)
                                .transition(.opacity)
                        } else if viewModel.searchResults.isEmpty && !searchQuery.isEmpty {
                            noResultsMessage
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
            .navigationTitle("Rechercher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isSearchFocused = true
                if let location = locationManager.location {
                    viewModel.userLocation = (location.coordinate.latitude, location.coordinate.longitude)
                }
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
            
            TextField("Adresse, lieu, arrêt...", text: $searchQuery)
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
                if locationManager.authorizationStatus == .authorizedWhenInUse && !searchQuery.isEmpty {
                    Button {
                        viewModel.useCurrentLocation(locationManager: locationManager) { result in
                            if let result = result {
                                onLocationSelected(result)
                            }
                        }
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 38, height: 38)
                                
                                Image(systemName: "location.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentColor)
                            }
                            
                            Text("Position actuelle")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                    }
                    
                    Divider()
                        .padding(.leading)
                }
                
                ForEach(viewModel.searchResults) { result in
                    Button {
                        selectedLocation = result
                        onLocationSelected(result)
                    } label: {
                        SearchResultRow(result: result)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                    }
                    
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }
    
    private var minCharactersMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.cursor.ibeam")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            
            Text("Saisissez au moins 3 caractères pour rechercher")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var noResultsMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            
            Text("Aucun résultat trouvé pour \(searchQuery)")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
