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
            ZStack {
                Circle()
                    .fill(selectedLocation != nil ?
                          Color.accentColor.opacity(0.15) :
                          Color(.systemFill).opacity(0.4))
                    .frame(width: 36, height: 36)
                    .animation(.spring(response: 0.3), value: selectedLocation)
                
                Image(systemName: selectedLocation != nil ?
                      (selectedLocation == .currentPosition ? "location.fill" : iconName) :
                      iconName)
                    .font(.system(size: 16, weight: selectedLocation != nil ? .medium : .regular))
                    .foregroundColor(selectedLocation != nil ? .accentColor : .secondary)
                    .symbolEffect(.bounce, options: .speed(1.5), value: selectedLocation)
            }
            
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
                            HapticFeedback.lightImpact()
                        }
                    }
                    .transition(.opacity)
            }
            
            Spacer()
            
            if selectedLocation == nil {
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        onClear()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 18))
                            .contentShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.4), value: searchText)
                }
                
                Button(action: {
                    onSearch()
                    HapticFeedback.lightImpact()
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                .padding(.leading, 4)
                .disabled(searchText.count < 3)
                .opacity(searchText.count < 3 ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.2), value: searchText.count < 3)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 35)
                .fill(Color(.secondarySystemFill).opacity(0.5))
                .shadow(
                    color: Color.black.opacity(isFocused ? 0.08 : 0.05),
                    radius: isFocused ? 6 : 4,
                    x: 0,
                    y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 35)
                .stroke(
                    isFocused ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.1),
                    lineWidth: isFocused ? 2 : 0.5
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        )
        .scaleEffect(isFocused ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .animation(.spring(response: 0.4), value: searchText)
    }
}
