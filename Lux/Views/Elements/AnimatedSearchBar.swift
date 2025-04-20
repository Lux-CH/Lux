//
//  AnimatedSearchBar.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI

struct AnimatedSearchBar: View {
    @Binding var searchText: String
    var placeholderText: String
    var onSearch: () -> Void
    var onClear: () -> Void
    var topPadding: CGFloat
    
    var body: some View {
        HStack {
            TextField(placeholderText, text: $searchText)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .font(.system(size: 16, weight: .medium))
                .overlay(
                    HStack {
                        Spacer()
                        if !searchText.isEmpty {
                            Button(action: onClear) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            }
                            .padding(.trailing, 8)
                        }
                    }
                )
                .onChange(of: searchText) {
                    if searchText.isEmpty {
                        onClear()
                    }
                    else {
                        onSearch()
                    }
                }
            
            Spacer()
            
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundColor(Color.accentColor)
            }
            .padding(.trailing, 18)
        }
        .frame(width: 350, height: 60)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(25)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: placeholderText)
    }
}
