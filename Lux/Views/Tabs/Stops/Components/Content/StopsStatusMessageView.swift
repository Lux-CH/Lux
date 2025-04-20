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
        VStack(alignment: .leading) {
            if showMinCharactersMessage {
                ScrollView {
                    VStack {
                        Text("Veuillez saisir au moins 3 caractères pour rechercher")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollDisabled(true)
            }
            else if isLoading && isEmpty {
                ScrollView {
                    VStack {
                        ProgressView(isSearchMode ? "Recherche en cours..." : "Chargement des arrêts à proximité...")
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollDisabled(true)
            }
            else if isEmpty && !showMinCharactersMessage {
                ScrollView {
                    VStack {
                        Text(isSearchMode ? "Aucun résultat trouvé." : "Aucun arrêt à proximité trouvé.")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollDisabled(true)
            }
        }
    }
}
