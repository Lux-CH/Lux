//
//  LineColorContrast.swift
//  Lux
//
//  Created by Constantin Clerc on 28.09.2026.
//

import SwiftUI
import UIKit

func readableLineColor(_ color: Color, onTint tint: Double = 0) -> Color {
    LineColorContrast.dynamic(color, tint: tint)
}

func legacyLineColor(_ color: Color) -> Color {
    isDarkColor(color) ? lightenColor(color) : color
}

enum LineColorContrast {
    static let darkTarget = 3.5

    private typealias RGB = (r: Double, g: Double, b: Double)

    private struct DynamicKey: Hashable {
        let color: Color
        let tint: Double
    }

    private struct ResolvedKey: Hashable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        let isDark: Bool
        let tint: Double
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var dynamicColors: [DynamicKey: Color] = [:]
    nonisolated(unsafe) private static var resolvedColors: [ResolvedKey: UIColor] = [:]

    static func dynamic(_ color: Color, tint: Double) -> Color {
        let key = DynamicKey(color: color, tint: tint)
        lock.lock()
        defer { lock.unlock() }
        if let cached = dynamicColors[key] { return cached }
        let base = UIColor(color)
        let result = Color(UIColor { traits in
            resolved(base.resolvedColor(with: traits), isDark: traits.userInterfaceStyle == .dark, tint: tint)
        })
        if dynamicColors.count > 512 { dynamicColors.removeAll() }
        dynamicColors[key] = result
        return result
    }

    private static func resolved(_ color: UIColor, isDark: Bool, tint: Double) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return color }
        let key = ResolvedKey(red: red, green: green, blue: blue, alpha: alpha, isDark: isDark, tint: tint)
        lock.lock()
        let cached = resolvedColors[key]
        lock.unlock()
        if let cached { return cached }
        let result = readable(color, isDark: isDark, tint: tint)
        lock.lock()
        if resolvedColors.count > 1024 { resolvedColors.removeAll() }
        resolvedColors[key] = result
        lock.unlock()
        return result
    }

    private static let darkSurface: RGB = (0.282, 0.282, 0.290)
    private static let lightSurface: RGB = (1, 1, 1)

    private static func legacy(_ color: UIColor) -> UIColor {
        isDarkColor(Color(color)) ? UIColor(lightenColor(Color(color))) : color
    }

    static func readable(_ color: UIColor, isDark: Bool, tint: Double) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return color }
        let original: RGB = (clamp(red), clamp(green), clamp(blue))
        let surface = isDark ? darkSurface : lightSurface
        let background: RGB = (
            surface.r + (original.r - surface.r) * tint,
            surface.g + (original.g - surface.g) * tint,
            surface.b + (original.b - surface.b) * tint
        )

        guard isDark else { return legacy(color) }
        let (hue, saturation, lightness) = hsl(original)
        func candidate(_ step: Int) -> RGB {
            step == 0 ? original : rgb(hue: hue, saturation: saturation, lightness: min(1, lightness + Double(step) / 100))
        }
        func passes(_ step: Int) -> Bool {
            lightness + Double(step) / 100 >= 1 || contrast(candidate(step), background) >= darkTarget
        }
        var low = 0, high = 100
        while low < high {
            let middle = (low + high) / 2
            if passes(middle) { high = middle } else { low = middle + 1 }
        }
        let result = candidate(low)
        return UIColor(red: result.r, green: result.g, blue: result.b, alpha: alpha)
    }

    private static func clamp(_ value: CGFloat) -> Double {
        min(1, max(0, Double(value)))
    }

    private static func luminance(_ color: RGB) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }

    private static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func hsl(_ color: RGB) -> (Double, Double, Double) {
        let high = max(color.r, color.g, color.b)
        let low = min(color.r, color.g, color.b)
        let lightness = (high + low) / 2
        guard high != low else { return (0, 0, lightness) }
        let delta = high - low
        let saturation = lightness > 0.5 ? delta / (2 - high - low) : delta / (high + low)
        let hue: Double
        switch high {
        case color.r: hue = (color.g - color.b) / delta + (color.g < color.b ? 6 : 0)
        case color.g: hue = (color.b - color.r) / delta + 2
        default: hue = (color.r - color.g) / delta + 4
        }
        return (hue / 6, saturation, lightness)
    }

    private static func rgb(hue: Double, saturation: Double, lightness: Double) -> RGB {
        guard saturation > 0 else { return (lightness, lightness, lightness) }
        let q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
        let p = 2 * lightness - q
        func channel(_ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }
        return (channel(hue + 1 / 3), channel(hue), channel(hue - 1 / 3))
    }
}
