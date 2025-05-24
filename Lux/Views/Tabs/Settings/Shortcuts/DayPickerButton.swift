//
//  DayPickerButton.swift
//  Lux
//
//  Created by Constantin Clerc on 25.05.2025.
//

import SwiftUI

struct DayPickerButton: View {
    let day: UserShortcut.TimeSchedule.Weekday
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Day circle
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.quaternarySystemFill))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(
                                    isSelected ? Color.clear : Color(.separator).opacity(0.3),
                                    lineWidth: 0.5
                                )
                        }
                    
                    Text(day.shortDisplayName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                    radius: isSelected ? 1 : 0,
                    x: 0,
                    y: 0.5
                )
                Text(day.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .accent : .secondary)
                    .opacity(isSelected ? 1.0 : 0.8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}
