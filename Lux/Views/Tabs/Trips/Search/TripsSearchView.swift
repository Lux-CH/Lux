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
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                    ? [Color(.systemBackground), Color(.systemBackground).opacity(0.8)]
                    : [Color(.secondarySystemBackground), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(
                                colorScheme == .dark
                                ? Color(.secondarySystemBackground).opacity(0.7)
                                : Color.white
                            )
                            .clipShape(
                                .rect(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 40,
                                    bottomTrailingRadius: 40,
                                    topTrailingRadius: 0,
                                    style: .continuous
                                )
                            )
                            .frame(height: 205)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        
                        VStack(alignment: .center, spacing: 16) {
                            HStack(spacing: 12) {
                                VStack(spacing: 22) {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 12, height: 12)
                                    
                                    ForEach(0..<3) { _ in
                                        Circle()
                                            .fill(Color.gray.opacity(0.5))
                                            .frame(width: 4, height: 4)
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.accentColor.opacity(0.8))
                                        .frame(width: 12, height: 12)
                                }
                                .padding(.vertical, 4)
                                
                                VStack(spacing: 16) {
                                    // from
                                    TripSearchBar(
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
                                            withAnimation(.spring(response: 0.4)) {
                                                viewModel.removeFromLocation()
                                            }
                                        },
                                        topPadding: 0,
                                        iconName: "location.circle.fill"
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
                                    
                                    // to
                                    TripSearchBar(
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
                                            withAnimation(.spring(response: 0.4)) {
                                                viewModel.removeToLocation()
                                            }
                                        },
                                        topPadding: 0,
                                        iconName: "mappin.circle.fill"
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
                                }
                                
                                Button(action: {
                                    withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                                        viewModel.swapLocations()
                                    }
                                }) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 38, height: 38)
                                        .background(
                                            viewModel.selectedFrom == nil && viewModel.selectedTo == nil
                                            ? Color.accentColor.opacity(0.3)
                                            : Color.accentColor
                                        )
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                        .symbolEffect(.bounce, value: viewModel.selectedFrom != nil || viewModel.selectedTo != nil)
                                }
                                .disabled(viewModel.selectedFrom == nil && viewModel.selectedTo == nil)
                                .offset(y: 15)
                            }
                            
                            if viewModel.selectedFrom != nil && viewModel.selectedTo != nil {
                                NavigationLink(destination: EmptyView()) {
                                    HStack(spacing: 8) {
                                        Text("Rechercher")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 160, height: 48)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(24)
                                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .transition(.scale.combined(with: .opacity))
                                .matchedGeometryEffect(id: "searchButton", in: animation)
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
                            .fill(
                                colorScheme == .dark
                                ? Color(.secondarySystemBackground).opacity(0.7)
                                : Color.white
                            )
                            .clipShape(
                                .rect(
                                    topLeadingRadius: 38,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 38,
                                    style: .continuous
                                )
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -4)
                        
                        VStack(spacing: 0) {
                            // Show Current Position option when search is empty
                            if (viewModel.activeSearchField != .none && viewModel.fromQuery.isEmpty && viewModel.toQuery.isEmpty) && viewModel.isCurrentPositionAvailable() {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Localisation")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                        .padding(.top, 22)
                                        .padding(.bottom, 12)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4)) {
                                            viewModel.selectCurrentPosition()
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.accentColor)
                                                .frame(width: 24, height: 24)
                                                .background(Color.accentColor.opacity(0.1))
                                                .clipShape(Circle())
                                            
                                            Text("Position Actuelle")
                                                .fontWeight(.medium)
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(.systemBackground))
                                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                        )
                                        .padding(.horizontal)
                                    }
                                    
                                    Divider()
                                        .padding(.vertical, 16)
                                        .padding(.horizontal)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            if viewModel.showMinCharactersMessage {
                                VStack(spacing: 16) {
                                    Image(systemName: "character.cursor.ibeam")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .padding(.top, 40)
                                    
                                    Text("Entrez au moins 3 caractères pour rechercher")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity)
                                .transition(.opacity)
                                
                                Spacer()
                            } else if !viewModel.searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Résultats")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                        .padding(.top, 22)
                                        .padding(.bottom, 8)
                                    
                                    ScrollView {
                                        LazyVStack(spacing: 12) {
                                            ForEach(viewModel.searchResults, id: \.id) { result in
                                                Button(action: {
                                                    withAnimation(.spring(response: 0.4)) {
                                                        viewModel.selectLocation(result)
                                                    }
                                                }) {
                                                    SearchResultRow(result: result)
                                                        .padding(.horizontal, 16)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 16)
                                                                .fill(Color(.systemBackground))
                                                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                                        )
                                                        .contentShape(Rectangle())
                                                }
                                                .buttonStyle(ScaleButtonStyle())
                                                .padding(.horizontal)
                                            }
                                        }
                                        .padding(.bottom, 16)
                                    }
                                }
                            } else if viewModel.activeSearchField != .none {
                                VStack(spacing: 20) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .padding(.top, 40)
                                    
                                    Text("Recherchez un lieu ou une adresse")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .transition(.opacity)
                                
                                Spacer()
                            } else {
                                Spacer()
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: viewModel.showMinCharactersMessage)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.searchResults.isEmpty)
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

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    TripsSearchView()
}
