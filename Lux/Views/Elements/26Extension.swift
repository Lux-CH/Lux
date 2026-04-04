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
    case glassIn(AnyShape)
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
            self.glassEffect(.clear.interactive(true))
        case .glassIn(let shape):
            self.glassEffect(in: shape)
        }
    }
}


struct GlassEffectGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                content()
            }
        } else {
            content()
        }
    }
}
