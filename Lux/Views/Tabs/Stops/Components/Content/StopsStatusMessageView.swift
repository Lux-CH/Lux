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
                        Image(systemName: "character.cursor.ibeam")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.top, 40)
                        
                        Text("Entrez au moins 3 caractères pour rechercher")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .scrollDisabled(true)
                .padding(.top, 15)
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
                .padding(.top, 15)
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
                .padding(.top, 15)
            }
        }
    }
}
