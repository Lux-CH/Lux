//
//  HapticFeedback.swift
//  Lux
//
//  Created by Constantin Clerc on 26.07.2025.
//

import SwiftUI

struct HapticFeedback {
    @MainActor private static var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]

    @MainActor private static func generator(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let generator = impactGenerators[style] { return generator }
        let generator = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style] = generator
        return generator
    }

    @MainActor static func prepareImpact(_ styles: UIImpactFeedbackGenerator.FeedbackStyle...) {
        styles.forEach { generator($0).prepare() }
    }

    @MainActor static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = generator(style)
        generator.impactOccurred()
        generator.prepare()
    }

    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
