//
//  StopsView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

// MARK: - StopsView
struct StopsView: View {
    @StateObject private var viewModel = StopsViewModel()
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .opacity(0.9)
                
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground).opacity(0.8))
                            .frame(height: 135)
                            .clipShape(
                                .rect(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 40,
                                    bottomTrailingRadius: 40,
                                    topTrailingRadius: 0,
                                    style: .continuous
                                )
                            )
                        StopsSearchHeaderView(
                            searchQuery: $viewModel.searchQuery,
                            onSearch: viewModel.performSearch,
                            onClear: { viewModel.resetSearch() }
                        )
                    }
                    .ignoresSafeArea(edges: .top)
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
                        StopsContentView(
                            isSearchMode: viewModel.isSearchMode,
                            isLoading: viewModel.isLoading,
                            searchResults: viewModel.searchResults,
                            showMinCharactersMessage: viewModel.showMinCharactersMessage,
                            locationManager: locationManager
                        )
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .onAppear {
            viewModel.setupLocationManager(locationManager)
            if viewModel.searchResults.isEmpty && !viewModel.isSearchMode {
                viewModel.loadNearbyStops(showLoading: true)
            }
        }
        .onChange(of: locationManager.location) {
            if !viewModel.isSearchMode {
                viewModel.checkLocationAndRefresh()
            }
        }
        .onReceive(viewModel.refreshTimer) { _ in
            if !viewModel.isSearchMode {
                viewModel.refreshNearbyStopsInBackground()
            }
        }
        .onDisappear {
            viewModel.cancelBackgroundTasks()
        }
    }
}
