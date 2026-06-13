//
//  SearchResultVisualStyleStore.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum SearchResultVisualColor: String, Codable, Sendable {
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

struct SearchResultVisualStyle: Codable, Equatable, Sendable {
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

private struct PersistedStyleEntry: Codable, Sendable {
    let style: SearchResultVisualStyle
    let updatedAt: Date
}

@MainActor
final class SearchResultVisualStyleStore: ObservableObject {
    static let shared = SearchResultVisualStyleStore()

    @Published private var entries: [String: PersistedStyleEntry] = [:]

    private let maxStoredStyles = 750
    private let maxStyleAge: TimeInterval = 60 * 60 * 24 * 45

    private let legacyStorageKey = "search_result_visual_styles"

    private let persister = StylePersister(url: SearchResultVisualStyleStore.fileURL)
    private var persistTask: Task<Void, Never>?
    private var needsPersist = false
    private let persistDebounce: Duration = .seconds(2)

    private init() {
        loadPersistedStyles()
        observeAppLifecycle()
    }

    func style(for resultID: String) -> SearchResultVisualStyle? {
        entries[resultID]?.style
    }

    func setStyles(_ styles: [String: SearchResultVisualStyle]) {
        guard !styles.isEmpty else { return }

        var updated = entries
        var hasChanges = false
        let now = Date()

        for (resultID, style) in styles {
            if updated[resultID]?.style != style {
                updated[resultID] = PersistedStyleEntry(style: style, updatedAt: now)
                hasChanges = true
            }
        }

        let didPrune = prune(&updated, referenceDate: now)
        guard hasChanges || didPrune else { return }

        entries = updated
        schedulePersist()
    }

    private static let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SearchResultVisualStyles.json", isDirectory: false)
    }()

    private func loadPersistedStyles() {
        let now = Date()

        if let data = try? Data(contentsOf: SearchResultVisualStyleStore.fileURL),
           let decoded = try? JSONDecoder().decode([String: PersistedStyleEntry].self, from: data) {
            var loaded = decoded
            let didPrune = prune(&loaded, referenceDate: now)
            entries = loaded
            if didPrune { schedulePersist() }
            return
        }

        guard let legacyData = UserDefaults.standard.data(forKey: legacyStorageKey) else {
            return
        }

        var migrated: [String: PersistedStyleEntry] = [:]
        if let decoded = try? JSONDecoder().decode([String: PersistedStyleEntry].self, from: legacyData) {
            migrated = decoded
        } else if let legacy = try? JSONDecoder().decode([String: SearchResultVisualStyle].self, from: legacyData) {
            migrated = legacy.mapValues { PersistedStyleEntry(style: $0, updatedAt: now) }
        }

        UserDefaults.standard.removeObject(forKey: legacyStorageKey)

        guard !migrated.isEmpty else { return }
        _ = prune(&migrated, referenceDate: now)
        entries = migrated
        schedulePersist()
    }

    private func schedulePersist() {
        needsPersist = true
        persistTask?.cancel()
        persistTask = Task { [weak self, debounce = persistDebounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self?.persistNow()
        }
    }

    private func persistNow() async {
        guard needsPersist else { return }
        needsPersist = false
        persistTask = nil
        await persister.write(entries: entries)
    }

    private func flushPendingWrites() {
        guard needsPersist else { return }
        needsPersist = false
        persistTask?.cancel()
        persistTask = nil
        let snapshot = entries
        Task { await persister.write(entries: snapshot) }
    }

    private func observeAppLifecycle() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flushPendingWrites()
            }
        }
        #endif
    }

    private func prune(_ entries: inout [String: PersistedStyleEntry], referenceDate: Date) -> Bool {
        var didPrune = false
        let expirationDate = referenceDate.addingTimeInterval(-maxStyleAge)

        let countBeforeExpiry = entries.count
        entries = entries.filter { $0.value.updatedAt >= expirationDate }
        if entries.count != countBeforeExpiry {
            didPrune = true
        }

        if entries.count > maxStoredStyles {
            let keysToKeep = Set(
                entries
                    .sorted { $0.value.updatedAt > $1.value.updatedAt }
                    .prefix(maxStoredStyles)
                    .map(\.key)
            )
            entries = entries.filter { keysToKeep.contains($0.key) }
            didPrune = true
        }

        return didPrune
    }
}

private actor StylePersister {
    private let url: URL
    private var didExcludeFromBackup = false

    init(url: URL) {
        self.url = url
    }

    func write(entries: [String: PersistedStyleEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }

        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        guard (try? data.write(to: url, options: .atomic)) != nil else { return }

        if !didExcludeFromBackup {
            didExcludeFromBackup = true
            var mutableURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? mutableURL.setResourceValues(values)
        }
    }
}
