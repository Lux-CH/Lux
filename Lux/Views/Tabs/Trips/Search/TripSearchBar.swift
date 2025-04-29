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
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation
    
    var placeholderText: String
    var selectedLocation: SelectedLocation?
    var onSearch: () -> Void
    var onClear: () -> Void
    var onRemoveTag: (() -> Void)?
    var topPadding: CGFloat
    var iconName: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: selectedLocation != nil ?
                  (selectedLocation == .currentPosition ? "location.fill" : iconName) :
                  iconName)
                .font(.system(size: 16))
                .foregroundColor(selectedLocation != nil ? .accentColor : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(selectedLocation != nil ?
                              Color.accentColor.opacity(0.1) :
                              Color(.systemFill).opacity(0.5))
                )
            
            if let location = selectedLocation {
                LocationTagView(location: location) {
                    onRemoveTag?()
                }
                .matchedGeometryEffect(id: "location_\(location.id)", in: animation)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            } else {
                TextField(placeholderText, text: $searchText)
                    .focused($isFocused)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.vertical, 2)
                    .submitLabel(.search)
                    .onChange(of: searchText) {
                        if searchText.isEmpty {
                            onClear()
                        } else {
                            onSearch()
                        }
                    }
                    .onSubmit {
                        if !searchText.isEmpty {
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
                            .font(.system(size: 18))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                        )
                }
                .padding(.leading, 4)
                .disabled(searchText.count < 3)
                .opacity(searchText.count < 3 ? 0.5 : 1)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ?
                      Color(.systemFill).opacity(0.2) :
                      Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isFocused ? Color.accentColor.opacity(0.4) : Color.clear,
                    lineWidth: 2
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        )
        .animation(.spring(response: 0.3), value: searchText)
        .animation(.spring(response: 0.3), value: selectedLocation)
    }
}
