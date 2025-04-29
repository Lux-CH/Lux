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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 6) {
            if case .currentPosition = location {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.accentColor)
                    .clipShape(Circle())
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
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? 
                      Color(.systemFill).opacity(0.4) : 
                      Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
        .animation(.spring(response: 0.3), value: location)
    }
}
