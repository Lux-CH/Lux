//
//  SearchResultVisualStyleStore.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2026.
//

import SwiftUI

struct SearchResultVisualStyle {
    let symbolName: String
    let color: Color
}

@MainActor
final class SearchResultVisualStyleStore: ObservableObject {
    static let shared = SearchResultVisualStyleStore()
    
    @Published private var stylesByResultID: [String: SearchResultVisualStyle] = [:]
    
    private init() {}
    
    func style(for resultID: String) -> SearchResultVisualStyle? {
        stylesByResultID[resultID]
    }
    
    func setStyles(_ styles: [String: SearchResultVisualStyle]) {
        for (resultID, style) in styles {
            stylesByResultID[resultID] = style
        }
    }
}
