//
//  SearchResultVisualStyleStore.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2026.
//

import SwiftUI

enum SearchResultVisualColor: String, Codable {
    case accent
    case red
    case orange
    case yellow
    case blue
    case teal
    case indigo
    case mint
    case cyan
    case brown
    case purple
    case green
    case pink
    case gray
    
    var color: Color {
        switch self {
        case .accent: return .accentColor
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .blue: return .blue
        case .teal: return .teal
        case .indigo: return .indigo
        case .mint: return .mint
        case .cyan: return .cyan
        case .brown: return .brown
        case .purple: return .purple
        case .green: return .green
        case .pink: return .pink
        case .gray: return .gray
        }
    }
}

struct SearchResultVisualStyle: Codable, Equatable {
    let symbolName: String
    let colorKey: SearchResultVisualColor
    
    var color: Color {
        colorKey.color
    }
    
    init(symbolName: String, color: SearchResultVisualColor) {
        self.symbolName = symbolName
        self.colorKey = color
    }
}

@MainActor
final class SearchResultVisualStyleStore: ObservableObject {
    static let shared = SearchResultVisualStyleStore()
    
    @Published private var stylesByResultID: [String: SearchResultVisualStyle] = [:]
    private let storageKey = "search_result_visual_styles"
    
    private init() {
        loadPersistedStyles()
    }
    
    func style(for resultID: String) -> SearchResultVisualStyle? {
        stylesByResultID[resultID]
    }
    
    func setStyles(_ styles: [String: SearchResultVisualStyle]) {
        var hasChanges = false
        
        for (resultID, style) in styles {
            if stylesByResultID[resultID] != style {
                stylesByResultID[resultID] = style
                hasChanges = true
            }
        }
        
        if hasChanges {
            persistStyles()
        }
    }
    
    private func persistStyles() {
        do {
            let encoded = try JSONEncoder().encode(stylesByResultID)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("failed to persist search result visual styles: \(error.localizedDescription)")
        }
    }
    
    private func loadPersistedStyles() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        do {
            stylesByResultID = try JSONDecoder().decode([String: SearchResultVisualStyle].self, from: data)
        } catch {
            print("failed to decode persisted search result visual styles: \(error.localizedDescription)")
        }
    }
}
