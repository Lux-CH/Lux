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
    case glassTintedIn(AnyShape, Color)
    case glassButtonIn(AnyShape)
    case glassButtonTintedIn(AnyShape, Color)
}

private struct LiquidGlassLightModeButtonTintOptOutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var liquidGlassLightModeButtonTintOptOut: Bool {
        get { self[LiquidGlassLightModeButtonTintOptOutKey.self] }
        set { self[LiquidGlassLightModeButtonTintOptOutKey.self] = newValue }
    }
}

private struct iOS26EffectModifier: ViewModifier {
    let effect: iOS26Effect
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.liquidGlassLightModeButtonTintOptOut) private var lightModeButtonTintOptOut

    private var shouldUseLightModeButtonTint: Bool {
        colorScheme == .light && !lightModeButtonTintOptOut
    }

    private var defaultLightModeButtonTint: Color {
        Color(.secondarySystemFill)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            applyiOS26Effect(to: content)
        } else {
            content
        }
    }

    @available(iOS 26, *)
    @ViewBuilder
    private func applyiOS26Effect(to content: Content) -> some View {
        switch effect {
        case .glass:
            content.glassEffect()
        case .glassButton:
            if shouldUseLightModeButtonTint {
                content.glassEffect(.regular.tint(defaultLightModeButtonTint).interactive(true))
            } else {
                content.glassEffect(.regular.interactive(true))
            }
        case .glassButtonClear:
            if shouldUseLightModeButtonTint {
                content.glassEffect(.regular.tint(defaultLightModeButtonTint).interactive(true))
            } else {
                if #available(iOS 27, *) {
                    content.glassEffect(.regular.tint(Color(.tertiarySystemBackground)).interactive(true))
                }
                else {
                    content.glassEffect(.clear.interactive(true))
                }
            }
        case .glassButtonTinted(let tint):
            content.glassEffect(.regular.tint(tint).interactive(true))
        case .glassButtonClearTinted(let tint):
            if shouldUseLightModeButtonTint {
                content.glassEffect(.regular.tint(tint).interactive(true))
            } else {
                content.glassEffect(.clear.tint(tint).interactive(true))
            }
        case .glassIn(let shape):
            content.glassEffect(in: shape)
        case .glassTintedIn(let shape, let color):
            content.glassEffect(.regular.tint(color), in: shape)
        case .glassButtonIn(let shape):
            if #available(iOS 27, *), !shouldUseLightModeButtonTint {
                content.glassEffect(.clear.tint(Color(.tertiarySystemBackground)).interactive(true), in: shape)
            }
            else {
                content.glassEffect(.clear.interactive(true), in: shape)
            }
        case .glassButtonTintedIn(let shape, let tint):
            content.glassEffect(.regular.tint(tint).interactive(true), in: shape)
        }
    }
}

extension View {
    @ViewBuilder
    func adaptable<Fallback: View>(
        ios26 effect: iOS26Effect,
        @ViewBuilder fallback: (Self) -> Fallback
    ) -> some View {
        if #available(iOS 26, *) {
            self.modifier(iOS26EffectModifier(effect: effect))
        } else {
            fallback(self)
        }
    }
 
    @ViewBuilder
    func ifAvailable(ios26 effect: iOS26Effect) -> some View {
        if #available(iOS 26, *) {
            self.modifier(iOS26EffectModifier(effect: effect))
        } else {
            self
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

    func liquidGlassLightModeButtonTintOptOut(_ enabled: Bool = true) -> some View {
        environment(\.liquidGlassLightModeButtonTintOptOut, enabled)
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
