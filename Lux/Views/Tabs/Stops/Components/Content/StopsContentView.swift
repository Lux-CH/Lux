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
        VStack(alignment: .leading) {            
            StopsStatusMessageView(
                showMinCharactersMessage: showMinCharactersMessage,
                isLoading: isLoading,
                isEmpty: searchResults.isEmpty,
                isSearchMode: isSearchMode
            )
            
            if !searchResults.isEmpty {
                StopsList(stops: searchResults, locationManager: locationManager, isSearching: isSearchMode)
            }
        }
    }
}

struct SectionTitleView: View {
    let isSearchMode: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isSearchMode ? "magnifyingglass" : "location.fill")
            Text(isSearchMode ? "Résultats de recherche" : "À proximité")
                .font(.headline)
                .fontWeight(.heavy)
        }
        .padding(.top, 17)
        .padding(.horizontal, 25)
        .id("sectionTitle-\(isSearchMode ? "search" : "nearby")")
    }
}
