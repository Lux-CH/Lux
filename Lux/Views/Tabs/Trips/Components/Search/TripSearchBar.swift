//
//  TripSearchBar.swift
//  Lux
//
//  Created by Constantin Clerc on 30.04.2025.
//
///  Basically just `AnimatedSearchBar` with a few edits

import SwiftUI

struct TripSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool
    @Namespace private var animation
    
    var placeholderText: String
    var selectedLocation: SelectedLocation?
    var onSearch: () -> Void
    var onClear: () -> Void
    var onRemoveTag: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 10) {
            if let location = selectedLocation {
                LocationTagView(location: location) {
                    onRemoveTag?()
                }
                .matchedGeometryEffect(id: "location_\(location.id)", in: animation)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            } else {
                TextField(placeholderText, text: $searchText)
                    .focused($isFocused)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.vertical, 6)
                    .submitLabel(.search)
                    .onChange(of: searchText) {
                        if searchText.isEmpty {
                            onClear()
                        }
                    }
                    .onSubmit {
                        if !searchText.isEmpty {
                            onSearch()
                            HapticFeedback.lightImpact()
                        }
                    }
                    .transition(.opacity)
            }
            
            Spacer(minLength: 4)
            
            if selectedLocation == nil {
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        onClear()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                            .contentShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.trailing, 35)
                    .animation(.spring(response: 0.4), value: searchText)
                }
            }
        }
        .frame(height: 40)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}
