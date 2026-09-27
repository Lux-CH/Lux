//
//  DirectionPreferenceStore.swift
//  Lux
//
//  Created by Constantin Clerc on 25.09.2026.
//

import Foundation

final class DirectionPreferenceStore {
    static let shared = DirectionPreferenceStore()

    enum TimeBucket: String, Codable {
        case weekdayMorning
        case weekdayEvening
        case weekend

        init(date: Date, calendar: Calendar = .current) {
            if calendar.isDateInWeekend(date) {
                self = .weekend
            } else {
                let hour = calendar.component(.hour, from: date)
                self = (4..<12).contains(hour) ? .weekdayMorning : .weekdayEvening
            }
        }
    }

    private struct Entry: Codable {
        var score: Double
        var updatedAt: Date
    }

    private static let halfLife: TimeInterval = 30 * 24 * 3600
    private static let pruneThreshold = 0.05

    private let queue = DispatchQueue(label: "ch.cclerc.lux.directionPreferences")
    private var entries: [String: Entry] = [:]

    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let luxDirectory = appSupport.appendingPathComponent("Lux")
        try? FileManager.default.createDirectory(at: luxDirectory, withIntermediateDirectories: true)
        return luxDirectory.appendingPathComponent("directionPreferences.data")
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? PropertyListDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        }
    }

    func record(stopId: String, route: String, headsignKey: String, at date: Date, points: Double) {
        let key = Self.key(stopId: stopId, route: route, headsignKey: headsignKey, bucket: TimeBucket(date: date))
        queue.sync {
            let current = entries[key].map { Self.decayed($0, at: date) } ?? 0
            entries[key] = Entry(score: current + points, updatedAt: date)
        }
        persist()
    }

    func score(stopId: String, route: String, headsignKey: String, at date: Date) -> Double {
        let key = Self.key(stopId: stopId, route: route, headsignKey: headsignKey, bucket: TimeBucket(date: date))
        return queue.sync {
            entries[key].map { Self.decayed($0, at: date) } ?? 0
        }
    }

    private func persist() {
        queue.async { [self] in
            let now = Date()
            entries = entries.filter { Self.decayed($0.value, at: now) >= Self.pruneThreshold }
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            guard let data = try? encoder.encode(entries) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private static func decayed(_ entry: Entry, at date: Date) -> Double {
        let elapsed = max(0, date.timeIntervalSince(entry.updatedAt))
        return entry.score * pow(0.5, elapsed / halfLife)
    }

    private static func key(stopId: String, route: String, headsignKey: String, bucket: TimeBucket) -> String {
        "\(stopId)|\(route.uppercased())|\(headsignKey)|\(bucket.rawValue)"
    }
}
