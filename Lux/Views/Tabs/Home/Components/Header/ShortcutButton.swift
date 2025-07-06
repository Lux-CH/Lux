//
//  ShortcutButton.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI

struct ShortcutButton: View {
    @ObservedObject var settings = Settings.shared
    var symbol: String
    var name: String?
    var isPlaceholder: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: symbol)
                        .foregroundColor(isPlaceholder ? Color.accentColor.opacity(0.5) : Color.accentColor)
                        .font(.system(size: 20))
                    if let shortcutName = name, !isPlaceholder, settings.showShortcutLabel {
                        Text(shortcutName)
                            .font(.system(size: 15))
                    }
                }
            }
            .frame(width: 134, height: 52.5)
            .background(
                RoundedRectangle(cornerRadius: 35)
                    .stroke(
                        isPlaceholder ? Color.secondary.opacity(0.3) : Color.primary.opacity(0.1),
                        style: StrokeStyle(lineWidth: isPlaceholder ? 2 : 0.5, dash: isPlaceholder ? [6] : [])
                    )
                    .background(
                        Color(.secondarySystemFill)
                            .opacity(isPlaceholder ? 0.3 : 0.5)
                            .cornerRadius(35)
                    )
            )
        }
    }
}
//
//#Preview {
//    HomeHeaderView()
//}
