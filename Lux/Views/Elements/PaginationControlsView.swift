//
//  PaginationControlsView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.05.2025.
//

import SwiftUI

struct PaginationControlsView: View {
    @Binding var isLoadingEarlier: Bool
    @Binding var isLoadingLater: Bool
    @Binding var isChangingContent: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var isLoading: Bool
    @Binding var animateIn: Bool
    var loadEarlier: () -> Void
    var loadLater: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: loadEarlier) {
                HStack(spacing: 6) {
                    if isLoadingEarlier {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.backward")
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text("Plus tôt")
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isLoadingEarlier || isLoadingLater || isLoading || isChangingContent)
            
            Spacer()
            
            Button(action: loadLater) {
                HStack(spacing: 6) {
                    Text("Plus tard")
                        .font(.system(size: 16, weight: .medium))
                    if isLoadingLater {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.forward")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isLoadingEarlier || isLoadingLater || isLoading || isChangingContent)
        }
        .foregroundColor(.accentColor)
        .background(
            Capsule()
                .fill(
                    colorScheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color.white
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    radius: 7.5,
                    x: 0,
                    y: 5
                )
                .overlay(
                    Capsule()
                        .stroke(
                            colorScheme == .dark
                            ? Color.primary.opacity(0.1)
                            : Color.gray.opacity(0.1),
                            lineWidth: 0.75
                        )
                )
                .scaleEffect(isChangingContent ? 0.98 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isChangingContent)
        )
        .frame(height: 54)
        .padding(.horizontal, 24)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? -16 : 40)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateIn)
    }
}
