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
    private struct PersistedStyleEntry: Codable {
        let style: SearchResultVisualStyle
        let updatedAt: Date
    }
    
    static let shared = SearchResultVisualStyleStore()
    
    @Published private var stylesByResultID: [String: SearchResultVisualStyle] = [:]
    private let storageKey = "search_result_visual_styles"
    private let maxStoredStyles = 750
    private let maxStyleAge: TimeInterval = 60 * 60 * 24 * 45
    
    private var persistedEntries: [String: PersistedStyleEntry] = [:]
    
    private init() {
        loadPersistedStyles()
    }
    
    func style(for resultID: String) -> SearchResultVisualStyle? {
        stylesByResultID[resultID]
    }
    
    func setStyles(_ styles: [String: SearchResultVisualStyle]) {
        guard !styles.isEmpty else { return }
        
        var hasChanges = false
        let now = Date()
        
        for (resultID, style) in styles {
            if persistedEntries[resultID]?.style != style {
                persistedEntries[resultID] = PersistedStyleEntry(style: style, updatedAt: now)
                hasChanges = true
            }
        }
        
        let didPrune = pruneEntries(referenceDate: now)
        if hasChanges || didPrune {
            refreshPublishedStyles()
            persistStyles()
        }
    }
    
    private func persistStyles() {
        do {
            let encoded = try JSONEncoder().encode(persistedEntries)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("failed to persist search result visual styles: \(error.localizedDescription)")
        }
    }
    
    private func loadPersistedStyles() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        if let decodedEntries = try? JSONDecoder().decode([String: PersistedStyleEntry].self, from: data) {
            persistedEntries = decodedEntries
        } else if let legacyStyles = try? JSONDecoder().decode([String: SearchResultVisualStyle].self, from: data) {
            let now = Date()
            persistedEntries = legacyStyles.mapValues { style in
                PersistedStyleEntry(style: style, updatedAt: now)
            }
        } else {
            print("failed to decode persisted search result visual styles")
            return
        }
        
        if pruneEntries(referenceDate: Date()) {
            persistStyles()
        }
        
        refreshPublishedStyles()
    }
    
    private func pruneEntries(referenceDate: Date) -> Bool {
        var didPrune = false
        let expirationDate = referenceDate.addingTimeInterval(-maxStyleAge)
        
        let countBeforeExpiryPrune = persistedEntries.count
        persistedEntries = persistedEntries.filter { _, entry in
            entry.updatedAt >= expirationDate
        }
        if persistedEntries.count != countBeforeExpiryPrune {
            didPrune = true
        }
        
        if persistedEntries.count > maxStoredStyles {
            let keysToKeep = Set(
                persistedEntries
                    .sorted { $0.value.updatedAt > $1.value.updatedAt }
                    .prefix(maxStoredStyles)
                    .map(\.key)
            )
            persistedEntries = persistedEntries.filter { key, _ in
                keysToKeep.contains(key)
            }
            didPrune = true
        }
        
        return didPrune
    }
    
    private func refreshPublishedStyles() {
        stylesByResultID = persistedEntries.mapValues(\.style)
    }
}
