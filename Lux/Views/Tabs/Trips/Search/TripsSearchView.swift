//
//  TripsSearchView.swift
//  Lux
//
//  Created by Constantin Clerc on 29.04.2025.
//

import SwiftUI

struct TripsSearchView: View {
    @StateObject private var viewModel = TripsSearchViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @FocusState private var isFromFocused: Bool
    @FocusState private var isToFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .opacity(0.9)
                
                VStack(spacing: 0) {
                    // Header
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground).opacity(0.8))
                            .frame(height: 195)
                            .clipShape(
                                .rect(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 40,
                                    bottomTrailingRadius: 40,
                                    topTrailingRadius: 0,
                                    style: .continuous
                                )
                            )
                        
                        VStack(alignment: .center, spacing: 10) {
                            ZStack(alignment: .trailing) {
                                HStack(spacing: 16) {
                                    // From search bar
                                    AnimatedSearchBar(
                                        searchText: $viewModel.fromQuery,
                                        isFocused: $isFromFocused,
                                        placeholderText: "Depuis",
                                        selectedLocation: viewModel.selectedFrom,
                                        onSearch: {
                                            viewModel.performSearch(viewModel.fromQuery)
                                        },
                                        onClear: {
                                            viewModel.resetSearch()
                                        },
                                        onRemoveTag: {
                                            viewModel.removeFromLocation()
                                        },
                                        topPadding: 0
                                    )
                                    .onTapGesture {
                                        if viewModel.selectedFrom == nil {
                                            isFromFocused = true
                                            viewModel.setActiveSearchField(.from)
                                        }
                                    }
                                    .onChange(of: isFromFocused) {
                                        if isFromFocused {
                                            viewModel.setActiveSearchField(.from)
                                        }
                                    }
                                    
                                    // Swap button
                                    Button(action: {
                                        withAnimation(.spring(duration: 0.4)) {
                                            viewModel.swapLocations()
                                        }
                                    }) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                            .background(Color.accentColor)
                                            .clipShape(Circle())
                                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
                                    }
                                    .disabled(viewModel.selectedFrom == nil && viewModel.selectedTo == nil)
                                }
                            }
                            
                            // To search bar
                            AnimatedSearchBar(
                                searchText: $viewModel.toQuery,
                                isFocused: $isToFocused,
                                placeholderText: "À",
                                selectedLocation: viewModel.selectedTo,
                                onSearch: {
                                    viewModel.performSearch(viewModel.toQuery)
                                },
                                onClear: {
                                    viewModel.resetSearch()
                                },
                                onRemoveTag: {
                                    viewModel.removeToLocation()
                                },
                                topPadding: 0
                            )
                            .onTapGesture {
                                if viewModel.selectedTo == nil {
                                    isToFocused = true
                                    viewModel.setActiveSearchField(.to)
                                }
                            }
                            .onChange(of: isToFocused) {
                                if isToFocused {
                                    viewModel.setActiveSearchField(.to)
                                }
                            }
                            
                            if viewModel.selectedFrom != nil && viewModel.selectedTo != nil {
                                NavigationLink(destination: EmptyView()) {
                                    Text("Rechercher")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(width: 160, height: 48)
                                        .background(Color.accentColor)
                                        .cornerRadius(24)
                                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                                }
                                .padding(.top, 10)
                            }
                        }
                        .padding(.top, 50)
                        .padding(.horizontal, 20)
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // Content
                    ZStack {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground).opacity(0.8))
                            .frame(maxHeight: .infinity)
                            .clipShape(
                                .rect(
                                    topLeadingRadius: 38,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 38,
                                    style: .continuous
                                )
                            )
                        
                        VStack(spacing: 0) {
                            // Show Current Position option when search is empty
                            if (viewModel.activeSearchField != .none && viewModel.fromQuery.isEmpty && viewModel.toQuery.isEmpty) && viewModel.isCurrentPositionAvailable() {
                                VStack(alignment: .leading) {
                                    Text("Localisation")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                        .padding(.top, 16)
                                        .padding(.bottom, 8)
                                    
                                    Button(action: {
                                        withAnimation {
                                            viewModel.selectCurrentPosition()
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "location.fill")
                                                .foregroundColor(.blue)
                                            Text("Position Actuelle")
                                                .fontWeight(.medium)
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(.systemBackground))
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                    }
                                    
                                    Divider()
                                        .padding(.vertical, 8)
                                        .padding(.horizontal)
                                }
                            }
                            
                            if viewModel.showMinCharactersMessage {
                                Text("Entrez au moins 3 caractères pour rechercher")
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            } else if viewModel.isLoading {
                                ProgressView()
                                    .padding()
                                Spacer()
                            } else if !viewModel.searchResults.isEmpty {
                                List {
                                    Section(header: Text("Résultats")) {
                                        ForEach(viewModel.searchResults, id: \.id) { result in
                                            Button(action: {
                                                withAnimation {
                                                    viewModel.selectLocation(result)
                                                }
                                            }) {
                                                SearchResultRow(result: result)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .listStyle(PlainListStyle())
                                .scrollContentBackground(.hidden)
                            } else {
                                Spacer()
                            }
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .onAppear {
            viewModel.setupLocationManager(locationManager)
        }
    }
}

struct LocationTagView: View {
    let location: SelectedLocation
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            if case .currentPosition = location {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
            }
            
            Text(location.displayName)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemFill))
        )
        .animation(.spring(response: 0.3), value: location)
    }
}

#Preview {
    TripsSearchView()
}
