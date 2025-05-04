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
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.colorScheme) var colorScheme
    var onShortcutSelected: (SearchResult) -> Void
    var onCurrentPositionSelected: () -> Void
    
    var body: some View {
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
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                } else {
                    Text("Aucun raccourci disponible")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(height: 56)
        .background(.ultraThinMaterial)
        .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: -2)
    }
}
