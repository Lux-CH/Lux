//
//  ShortcutButton.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI

struct ShortcutButton: View {
    var symbol: String
    var coords: (Double, Double)?
    var name: String?
    var isPlaceholder: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .foregroundColor(isPlaceholder ? Color.accentColor.opacity(0.5) : Color.accentColor)
                    .font(.system(size: 20))
            }
            .frame(width: 134, height: 52.5)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isPlaceholder ? Color.secondary.opacity(0.3) : Color.clear,
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
                    .background(
                        Color(.secondarySystemFill)
                            .opacity(isPlaceholder ? 0.3 : 0.5)
                            .cornerRadius(20)
                    )
            )
        }
        // Removed the disabled modifier so placeholders are clickable
    }
}
//
//#Preview {
//    HomeHeaderView()
//}
