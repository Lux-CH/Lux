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
    var isTextFieldDisabled: Bool
    
    var body: some View {
        HStack {
            TextField(placeholderText, text: $searchText)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .font(.system(size: 16, weight: .medium))
                .disabled(isTextFieldDisabled)
                .accessibilityHidden(isTextFieldDisabled)
                .overlay(
                    HStack {
                        Spacer()
                        if !searchText.isEmpty {
                            Button(action: onClear) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                                    .font(.system(size: 16))
                            }
                            .padding(.trailing, 8)
                            .accessibilityHidden(isTextFieldDisabled)
                        }
                    }
                )
                .onChange(of: searchText) {
                    if searchText.isEmpty {
                        onClear()
                    } else {
                        onSearch()
                    }
                }
                .onSubmit {
                    onSearch()
                }
            
            Spacer()
            
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
            .allowsHitTesting(!isTextFieldDisabled)
            .accessibilityHidden(isTextFieldDisabled)
            .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .contentShape(Capsule(style: .continuous))
        .adaptable(ios26: .glassButtonClear, fallback: {
            $0.background(
                Capsule(style: .continuous)
                    .fill(Color(.secondarySystemFill).opacity(0.5))
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        })
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: placeholderText)
        .accessibilityElement(children: isTextFieldDisabled ? .ignore : .contain)
    }
}
