//
//  26Extension.swift
//  Lux
//
//  Created by Constantin Clerc on 26.03.2026.
//

import SwiftUI
 
enum iOS26Effect {
    case glass
    case glassButton
    case glassButtonClear
    case glassButtonTinted(Color)
    case glassButtonClearTinted(Color)
    case glassIn(AnyShape)
    case glassButtonIn(AnyShape)
}

extension View {
    @ViewBuilder
    func adaptable<Fallback: View>(
        ios26 effect: iOS26Effect,
        @ViewBuilder fallback: (Self) -> Fallback
    ) -> some View {
        if #available(iOS 26, *) {
            self.applyiOS26Effect(effect)
        } else {
            fallback(self)
        }
    }
 
    @ViewBuilder
    func ifAvailable(ios26 effect: iOS26Effect) -> some View {
        if #available(iOS 26, *) {
            self.applyiOS26Effect(effect)
        } else {
            self
        }
    }
 
    @available(iOS 26, *)
    @ViewBuilder
    private func applyiOS26Effect(_ effect: iOS26Effect) -> some View {
        switch effect {
        case .glass:
            self.glassEffect()
        case .glassButton:
            self.glassEffect(.regular.interactive(true))
        case .glassButtonClear:
            self.glassEffect(.clear.interactive(true))
        case .glassButtonTinted(let tint):
            self.glassEffect(.regular.tint(tint).interactive(true))
        case .glassButtonClearTinted(let tint):
            self.glassEffect(.clear.tint(tint).interactive(true))
        case .glassIn(let shape):
            self.glassEffect(in: shape)
        case .glassButtonIn(let shape):
            self.glassEffect(.clear.interactive(true), in: shape)
        }
    }

    @ViewBuilder
    func glassButtonStyleIfAvailable(prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            self
        }
    }
}


struct GlassEffectGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    
    init(spacing: CGFloat = 18, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}
