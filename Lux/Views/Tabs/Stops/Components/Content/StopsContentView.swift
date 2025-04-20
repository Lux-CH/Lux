//
//  StopsContentView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import LuxCom

struct StopsContentView: View {
    let isSearchMode: Bool
    let isLoading: Bool
    let searchResults: [SearchResult]
    let showMinCharactersMessage: Bool
    let locationManager: LocationManager
    
    var body: some View {
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
            
            VStack(alignment: .leading) {
                // Title section with icon
                SectionTitleView(isSearchMode: isSearchMode)
                
                Divider()
                
                // Status messages
                StopsStatusMessageView(
                    showMinCharactersMessage: showMinCharactersMessage,
                    isLoading: isLoading,
                    isEmpty: searchResults.isEmpty,
                    isSearchMode: isSearchMode
                )
                
                // Results list
                if !searchResults.isEmpty {
                    StopsList(stops: searchResults, locationManager: locationManager)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct SectionTitleView: View {
    let isSearchMode: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isSearchMode ? "magnifyingglass" : "location.fill")
            Text(isSearchMode ? "Résultats de recherche" : "À proximité")
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding(.top, 17)
        .padding(.horizontal)
    }
}
