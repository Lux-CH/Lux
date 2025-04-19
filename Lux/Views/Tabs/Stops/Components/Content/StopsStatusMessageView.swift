//
//  StopsStatusMessageView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI

struct StopsStatusMessageView: View {
    let showMinCharactersMessage: Bool
    let isLoading: Bool
    let isEmpty: Bool
    let isSearchMode: Bool
    
    var body: some View {
        VStack {
            if showMinCharactersMessage {
                ScrollView {
                    Text("Veuillez saisir au moins 3 caractères pour rechercher")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .scrollDisabled(true)
            }
            else if isLoading && isEmpty {
                ScrollView {
                    ProgressView(isSearchMode ? "Recherche en cours..." : "Chargement des arrêts à proximité...")
                        .padding(.horizontal)
                }
                .scrollDisabled(true)
            }
            else if isEmpty && !showMinCharactersMessage {
                ScrollView {
                    Text(isSearchMode ? "Aucun résultat trouvé." : "Aucun arrêt à proximité trouvé.")
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                .scrollDisabled(true)
            }
        }
    }
}
