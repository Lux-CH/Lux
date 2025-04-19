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
                Color(.black)
                    .ignoresSafeArea()
                    .opacity(0.9)
                
                VStack(spacing: 0) {
                    StopsSearchHeaderView(
                        searchQuery: $viewModel.searchQuery,
                        onSearch: viewModel.performSearch,
                        onClear: { viewModel.resetSearch() }
                    )
                    
                    StopsContentView(
                        isSearchMode: viewModel.isSearchMode,
                        isLoading: viewModel.isLoading,
                        searchResults: viewModel.searchResults,
                        showMinCharactersMessage: viewModel.showMinCharactersMessage,
                        locationManager: locationManager
                    )
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
