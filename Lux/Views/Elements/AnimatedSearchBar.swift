//
//  AnimatedSearchBar.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI

struct AnimatedSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool
    var placeholderText: String
    var selectedLocation: SelectedLocation?
    var onSearch: () -> Void
    var onClear: () -> Void
    var onRemoveTag: (() -> Void)?
    var topPadding: CGFloat
    
    var body: some View {
        HStack {
            if let location = selectedLocation {
                LocationTagView(location: location) {
                    onRemoveTag?()
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                TextField(placeholderText, text: $searchText)
                    .focused($isFocused)
                    .font(.system(size: 16, weight: .medium))
                    .onChange(of: searchText) {
                        if searchText.isEmpty {
                            onClear()
                        } else {
                            onSearch()
                        }
                    }
            }
            
            Spacer()
            
            if selectedLocation == nil {
                if !searchText.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(Color.accentColor)
                }
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(height: 60)
        .background(Color(.secondarySystemFill).opacity(0.5))
        .cornerRadius(25)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: searchText)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedLocation)
    }
}
