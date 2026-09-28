//
//  LineColorContrast.swift
//  Lux
//
//  Created by Constantin Clerc on 28.09.2026.
//

import SwiftUI
import UIKit

func readableLineColor(_ color: Color, onTint tint: Double = 0) -> Color {
    let base = UIColor(color)
    return Color(UIColor { traits in
        LineColorContrast.readable(
            base.resolvedColor(with: traits),
            isDark: traits.userInterfaceStyle == .dark,
            tint: tint
        )
    })
}

enum LineColorContrast {
    static let darkTarget = 3.5

    private typealias RGB = (r: Double, g: Double, b: Double)

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
        var (hue, saturation, lightness) = hsl(original)
        var candidate = original
        for _ in 0..<100 {
            if contrast(candidate, background) >= darkTarget || lightness >= 1 { break }
            lightness = min(1, lightness + 0.01)
            candidate = rgb(hue: hue, saturation: saturation, lightness: lightness)
        }
        return UIColor(red: candidate.r, green: candidate.g, blue: candidate.b, alpha: alpha)
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
