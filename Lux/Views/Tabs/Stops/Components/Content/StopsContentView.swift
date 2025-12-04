//
//  StopsContentView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import LuxCom

struct StopsContentView: View {
    @ObservedObject var progress = Progress.shared
    @State private var isShowingTip: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
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
        .overlay {
            if progress.numOfTimesStopViewWasOpened == 1 {
                HintIndicatorView(icon: "chevron.compact.down",
                                  message: String(localized: "Glissez vers le bas pour retourner sur l'écran d'accueil"),
                                  delay: 2,
                                  duration: 10,
                                  onDismiss: {isShowingTip = false})
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.75)) {
                            isShowingTip = true
                        }
                    }
                }
                .background(
                    // totally not from customtabbar :)
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(
                                Color(.secondarySystemBackground)
                            )
                            .shadow(
                                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15),
                                radius: 7.5,
                                x: 0,
                                y: 5
                            )
                        Capsule(style: .continuous)
                            .fill(
                                colorScheme == .dark
                                ? Color(.secondarySystemBackground).opacity(0.7)
                                : Color.white
                            )
                            .stroke(
                                colorScheme == .dark
                                ? Color.primary.opacity(0.1)
                                : Color.gray.opacity(0.1),
                                lineWidth: 0.75
                            )
                    }
                        .opacity(isShowingTip ? 1.0 : 0.0)
                        .frame(width: 350, height: 65)
                )
                .padding(.top, 375)
            }
        }
    }
}

struct SectionTitleView: View {
    let isSearchMode: Bool
//    @State private var showMap: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: isSearchMode ? "magnifyingglass" : "location.fill")
                .accessibilityHidden(true)
            Text(isSearchMode ? "Résultats de recherche" : "À proximité")
                .font(.headline)
                .fontWeight(.bold)
                .accessibilityLabel(isSearchMode ? "Liste des résultats de recherche" : "Liste des arrêts à proximité")
            Spacer()
//            Button() {
//                showMap = true
//                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
//            } label: {
//                Image(systemName: "map.fill")
//            }
//            .foregroundColor(.accentColor)
//            .font(.system(size: 12))
//            .frame(maxHeight: 7.5)
//            .padding(.vertical, 8)
//            .padding(.horizontal, 20)
//            .background(
//                Capsule(style: .continuous)
//                    .stroke(Color.primary.opacity(0.1))
//                    .fill(Color(.secondarySystemFill).opacity(0.5))
//            )
        }
        .padding(.top, 17)
        .padding(.horizontal, 25)
//        .navigationDestination(isPresented: $showMap) {
//            EmptyView()
//        }
        .id("sectionTitle-\(isSearchMode ? "search" : "nearby")")
    }
}
