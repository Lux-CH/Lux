//
//  ShortcutsKeyboardToolbar.swift
//  Lux
//
//  Created by Constantin Clerc on 05.05.2025.
//

import SwiftUI
import LuxCom

struct ShortcutsKeyboardToolbar: View {
    @EnvironmentObject var shortcutManager: ShortcutManager
    @Environment(\.colorScheme) var colorScheme
    var onShortcutSelected: (SearchResult) -> Void
    var onCurrentPositionSelected: () -> Void
    
    var body: some View {
        if #available(iOS 26.0, *) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button(action: {
                        HapticFeedback.lightImpact()
                        onCurrentPositionSelected()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentColor)
                                .frame(width: 18, height: 18)
                                .scaledToFit()
                            
                            Text("Position actuelle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(height: 16)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .ifAvailable(ios26: .glassButtonTinted(Color.accentColor.opacity(0.15)))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 24)
                    
                    if !shortcutManager.shortcuts.isEmpty {
                        ForEach(shortcutManager.shortcuts) { shortcut in
                            Button(action: {
                                let searchResult = shortcut.toSearchResult()
                                HapticFeedback.lightImpact()
                                onShortcutSelected(searchResult)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: shortcut.symbol)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.accentColor)
                                        .frame(width: 18, height: 18)
                                        .scaledToFit()
                                    
                                    Text(shortcut.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .frame(height: 16)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .ifAvailable(ios26: .glassButtonTinted(colorScheme == .dark ? Color(.systemFill).opacity(0.8) : Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(height: 56)
            .clipShape(Capsule())
            .glassEffect(.regular)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button(action: {
                        HapticFeedback.lightImpact()
                        onCurrentPositionSelected()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentColor)
                                .frame(width: 18, height: 18)
                                .scaledToFit()
                            
                            Text("Position actuelle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(height: 16)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.15))
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 24)
                    
                    if !shortcutManager.shortcuts.isEmpty {
                        ForEach(shortcutManager.shortcuts) { shortcut in
                            Button(action: {
                                let searchResult = shortcut.toSearchResult()
                                HapticFeedback.lightImpact()
                                onShortcutSelected(searchResult)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: shortcut.symbol)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.accentColor)
                                        .frame(width: 18, height: 18)
                                        .scaledToFit()
                                    
                                    Text(shortcut.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .frame(height: 16)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(colorScheme == .dark ?
                                              Color(.systemFill).opacity(0.8) :
                                                Color(.secondarySystemBackground))
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                    
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(height: 56)
            .background(colorScheme == .dark ? Color(red: 0.184, green: 0.184, blue: 0.188) : Color(red: 0.812, green: 0.827, blue: 0.851))
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 0.5)
                    .offset(y: -28)
            )
        }
    }
}
