//
//  LocationTagView.swift
//  Lux
//
//  Created by Constantin Clerc on 30.04.2025.
//

import SwiftUI
import LuxCom

struct LocationTagView: View {
    @EnvironmentObject var shortcutManager: ShortcutManager
    @ObservedObject private var visualStyleStore = SearchResultVisualStyleStore.shared
    let location: SelectedLocation
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            if let iconStyle = iconStyle {
                Image(systemName: iconStyle.symbolName)
                    .font(.system(size: 10))
                    .foregroundColor(iconStyle.color)
                    .frame(width: 28, height: 18)
                    .background(iconStyle.color.opacity(0.12))
                    .clipShape(Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(iconStyle.color.opacity(0.35), lineWidth: 0.5)
                    )
            }
            
            Text(location.displayName)
                .lineLimit(1)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 15))
                    .padding(4)
                    .contentShape(Circle())
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .frame(maxHeight: 15)
        .padding(.vertical, 8)
        .padding(.horizontal, 15)
        .background(
            RoundedRectangle(cornerRadius: 75, style: .continuous)
                .fill(Color(.secondarySystemFill).opacity(0.4))
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.75)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .animation(.spring(response: 0.3), value: location)
    }
    
    private var iconStyle: (symbolName: String, color: Color)? {
        if case .currentPosition = location {
            return ("location.fill", .accentColor)
        }
        
        guard case .searchResult(let result) = location else {
            return nil
        }
        
        if let shortcutSymbol = shortcutSymbol(for: result) {
            return (shortcutSymbol, .accentColor)
        }
        
        if result.type != .stop, let style = visualStyleStore.style(for: result.id) {
            return (style.symbolName, style.color)
        }
        
        return defaultIcon(for: result.type, id: result.id)
    }
    
    private func defaultIcon(for type: LocationType, id: String = "") -> (symbolName: String, color: Color) {
        switch type {
        case .adress:
            return ("mappin", .red)
        case .place:
            if id == "citaStop" {
                return ("signpost.right.fill", .accentColor)
            }
            return ("building.fill", .blue)
        case .stop:
            return ("signpost.right.fill", .accentColor)
        }
    }
    
    private func shortcutSymbol(for result: SearchResult) -> String? {
        if let matchByStop = shortcutManager.shortcuts.first(where: { $0.stopId == result.id }) {
            return matchByStop.symbol
        }
        
        if let matchByName = shortcutManager.shortcuts.first(where: {
            $0.name.localizedCaseInsensitiveCompare(result.name) == .orderedSame
        }) {
            return matchByName.symbol
        }
        
        return nil
    }
}
