//
//  LocationTagView.swift
//  Lux
//
//  Created by Constantin Clerc on 30.04.2025.
//

import SwiftUI

struct LocationTagView: View {
    let location: SelectedLocation
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            if case .currentPosition = location {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 18)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.5)
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
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 75, style: .continuous)
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.75)
        )
        .animation(.spring(response: 0.3), value: location)
    }
}
