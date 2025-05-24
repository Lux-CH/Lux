//
//  ModernComponents.swift
//  Lux
//
//  Created by Constantin Clerc on 25.05.2025.
//

import SwiftUI

struct ModernCard<Content: View>: View {
    enum Style {
        case normal
        case accent
        case subtle
    }
    
    let style: Style
    @ViewBuilder let content: Content
    
    init(style: Style = .normal, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
            }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .normal:
            return Color(.secondarySystemGroupedBackground)
        case .accent:
            return Color.accentColor.opacity(0.05)
        case .subtle:
            return Color(.tertiarySystemGroupedBackground)
        }
    }
    
    private var strokeColor: Color {
        switch style {
        case .normal:
            return Color(.separator).opacity(0.3)
        case .accent:
            return Color.accentColor.opacity(0.2)
        case .subtle:
            return Color(.separator).opacity(0.2)
        }
    }
    
    private var strokeWidth: CGFloat {
        switch style {
        case .normal:
            return 0.5
        case .accent:
            return 1
        case .subtle:
            return 0.5
        }
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                    }
            }
            .font(.body)
    }
}

struct ModernToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(configuration.isOn ? Color.accentColor : Color(.systemGray4))
                .frame(width: 50, height: 30)
                .overlay {
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
