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
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = LocationSearchViewModel()
    @EnvironmentObject private var locationManager: LocationManager
    @Binding var searchQuery: String
    @Binding var selectedLocation: SearchResult?
    var onLocationSelected: (SearchResult) -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var appearAnimation = false
    
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation { appearAnimation = true }
                }
            }
            .onDisappear { appearAnimation = false }
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
            let showCurrentLocation = locationManager.authorizationStatus == .authorizedWhenInUse && !searchQuery.isEmpty

            VStack(spacing: 0) {
                if showCurrentLocation {
                    Button {
                        viewModel.useCurrentLocation(locationManager: locationManager) { result in
                            if let result = result {
                                onLocationSelected(result)
                            }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.14))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "location.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                            Text("Position actuelle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appearAnimation)

                    if !viewModel.searchResults.isEmpty {
                        Divider().padding(.leading, 68)
                    }
                }

                ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
                    Button {
                        selectedLocation = result
                        onLocationSelected(result)
                    } label: {
                        SearchResultRow(result: result)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 8)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.8)
                            .delay(Double(showCurrentLocation ? index + 1 : index) * 0.04),
                        value: appearAnimation
                    )

                    if index < viewModel.searchResults.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color(.tertiarySystemBackground)
                        : Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08),
                        radius: 12, x: 0, y: 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
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
