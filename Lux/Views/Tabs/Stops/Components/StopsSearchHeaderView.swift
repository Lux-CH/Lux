//
//  StopsSearchHeaderView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI

// MARK: - Search Header View
struct StopsSearchHeaderView: View {
    @Binding var searchQuery: String
    var onSearch: () -> Void
    var onClear: () -> Void
    
    var body: some View {
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
            
            HStack {
                TextField("Rechercher un arrêt...", text: $searchQuery)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                    .font(.system(size: 16, weight: .medium))
                    .overlay(
                        HStack {
                            Spacer()
                            if !searchQuery.isEmpty {
                                Button(action: onClear) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                }
                                .padding(.trailing, 8)
                            }
                        }
                    )
                    .onChange(of: searchQuery) {
                        onSearch()
                    }
                
                Spacer()
                
                Button(action: {
                    onSearch()
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(Color.accentColor)
                }
                .padding(.trailing, 18)
            }
            .frame(width: 350, height: 60)
            .background(Color(.secondarySystemFill).opacity(0.5))
            .cornerRadius(25)
            .padding(.top, 55)
        }
        .ignoresSafeArea(edges: .top)
    }
}
