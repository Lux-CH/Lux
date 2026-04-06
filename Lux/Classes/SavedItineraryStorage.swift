//
//  SavedItineraryStorage.swift
//  Lux
//
//  Created by Codex on 06.04.2026.
//

import Foundation
import LuxCom

struct SavedItineraryRecord: Identifiable {
    let id: String
    let fileURL: URL
    let itinerary: Itinerary
}

enum SavedItineraryStorageError: LocalizedError {
    case storageUnavailable
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            return "Impossible d'accéder au stockage local."
        case .saveFailed(let message):
            return "Impossible d'enregistrer l'itinéraire localement : \(message)"
        }
    }
}

final class SavedItineraryStorage {
    static let shared = SavedItineraryStorage()

    private let fileManager = FileManager.default
    private let itinerarySharer = ItinerarySharer()
    private let expirationBuffer: TimeInterval = 5 * 60
    private let lookAheadWindow: TimeInterval = 60 * 60
    private let fileExtension = "luxtrip"
    private let cacheLock = NSLock()
    private var cachedDirectoryFingerprint: Int?
    private var cachedRecordsCache: [SavedItineraryRecord] = []
    private let storageLock = NSRecursiveLock()

    private var storageDirectoryURL: URL? {
        guard let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = appSupportDirectory
            .appendingPathComponent("Lux", isDirectory: true)
            .appendingPathComponent("SavedItineraries", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            print("Failed to create saved itineraries directory: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func save(_ itinerary: Itinerary) -> Result<Void, SavedItineraryStorageError> {
        storageLock.lock()
        defer { storageLock.unlock() }
        
        guard let directory = storageDirectoryURL else {
            return .failure(.storageUnavailable)
        }

        cleanupExpiredItineraries(referenceDate: Date())
        removeDuplicateEntries(for: itinerary)

        do {
            let encoded = try itinerarySharer.encode(itinerary)
            let filename = "\(Int(itinerary.startTime.timeIntervalSince1970))-\(UUID().uuidString).\(fileExtension)"
            let fileURL = directory.appendingPathComponent(filename)

            try encoded.write(to: fileURL, options: .atomic)
            invalidateCache()
            NotificationCenter.default.post(name: .savedItinerariesDidChange, object: nil)
            return .success(())
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
    
    func isSaved(_ itinerary: Itinerary, referenceDate: Date = Date()) -> Bool {
        storageLock.lock()
        defer { storageLock.unlock() }
        
        let nonExpiredRecords = loadValidRecords(
            referenceDate: referenceDate,
            cleanupExpiredFiles: false,
            postNotificationOnCleanup: false
        )
        return nonExpiredRecords.contains { record in
            itinerariesMatch(record.itinerary, itinerary)
        }
    }
    
    func isSavedAsync(_ itinerary: Itinerary, referenceDate: Date = Date()) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let isSaved = self.isSaved(itinerary, referenceDate: referenceDate)
                continuation.resume(returning: isSaved)
            }
        }
    }

    func loadUpcomingItinerary(referenceDate: Date = Date()) -> SavedItineraryRecord? {
        storageLock.lock()
        defer { storageLock.unlock() }
        
        let records = loadValidRecords(
            referenceDate: referenceDate,
            cleanupExpiredFiles: true,
            postNotificationOnCleanup: true
        )
        
        let candidates = records.filter { record in
            isWithinDisplayWindow(itinerary: record.itinerary, at: referenceDate)
        }

        let upcoming = candidates
            .filter { $0.itinerary.startTime >= referenceDate }
            .sorted { $0.itinerary.startTime < $1.itinerary.startTime }
            .first

        if let upcoming {
            return upcoming
        }

        return candidates.sorted { $0.itinerary.endTime < $1.itinerary.endTime }.first
    }

    func loadItinerary(from fileURL: URL) -> Itinerary? {
        storageLock.lock()
        defer { storageLock.unlock() }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let itinerary = try itinerarySharer.decode(data)
            guard itinerarySharer.validateItinerary(itinerary) else {
                return nil
            }
            return itinerary
        } catch {
            return nil
        }
    }

    @discardableResult
    func cleanupExpiredItineraries(referenceDate: Date = Date()) -> Int {
        storageLock.lock()
        defer { storageLock.unlock() }
        
        let records = loadAllItineraries()
        let (_, removedCount) = removeExpiredRecords(records, referenceDate: referenceDate, postNotification: true)
        return removedCount
    }

    private func loadAllItineraries() -> [SavedItineraryRecord] {
        guard let directory = storageDirectoryURL else {
            return []
        }

        let fileURLs: [URL]
        do {
            fileURLs = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == fileExtension }
        } catch {
            print("Failed to read saved itineraries directory: \(error.localizedDescription)")
            return []
        }
        
        let fingerprint = calculateDirectoryFingerprint(for: fileURLs)
        if let cached = cachedRecordsIfAvailable(for: fingerprint) {
            return cached
        }

        var records: [SavedItineraryRecord] = []
        var removedInvalidFile = false

        for fileURL in fileURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                let itinerary = try itinerarySharer.decode(data)

                guard itinerarySharer.validateItinerary(itinerary) else {
                    try fileManager.removeItem(at: fileURL)
                    removedInvalidFile = true
                    continue
                }

                records.append(
                    SavedItineraryRecord(
                        id: fileURL.lastPathComponent,
                        fileURL: fileURL,
                        itinerary: itinerary
                    )
                )
            } catch {
                do {
                    try fileManager.removeItem(at: fileURL)
                    removedInvalidFile = true
                } catch {
                    print("Failed to remove invalid itinerary file: \(error.localizedDescription)")
                }
            }
        }
        
        let validFingerprint = calculateDirectoryFingerprint(for: records.map(\.fileURL))
        updateCache(records: records, fingerprint: validFingerprint)
        
        if removedInvalidFile {
            NotificationCenter.default.post(name: .savedItinerariesDidChange, object: nil)
        }

        return records
    }

    private func isWithinDisplayWindow(itinerary: Itinerary, at date: Date) -> Bool {
        let showFrom = itinerary.startTime.addingTimeInterval(-lookAheadWindow)
        let showUntil = itinerary.endTime.addingTimeInterval(expirationBuffer)
        return date >= showFrom && date <= showUntil
    }

    private func removeDuplicateEntries(for itinerary: Itinerary) {
        let duplicates = loadAllItineraries().filter {
            itinerariesMatch($0.itinerary, itinerary)
        }
        
        guard !duplicates.isEmpty else {
            return
        }

        var removedAny = false

        for duplicate in duplicates {
            do {
                try fileManager.removeItem(at: duplicate.fileURL)
                removedAny = true
            } catch {
                print("Failed to remove duplicate itinerary file: \(error.localizedDescription)")
            }
        }
        
        if removedAny {
            invalidateCache()
        }
    }
    
    private func itinerariesMatch(_ lhs: Itinerary, _ rhs: Itinerary) -> Bool {
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.legs.first?.from.name == rhs.legs.first?.from.name &&
        lhs.legs.last?.to.name == rhs.legs.last?.to.name
    }
    
    private func loadValidRecords(
        referenceDate: Date,
        cleanupExpiredFiles: Bool,
        postNotificationOnCleanup: Bool
    ) -> [SavedItineraryRecord] {
        let records = loadAllItineraries()
        
        if cleanupExpiredFiles {
            let (remainingRecords, _) = removeExpiredRecords(
                records,
                referenceDate: referenceDate,
                postNotification: postNotificationOnCleanup
            )
            return remainingRecords
        }
        
        return records.filter { !itineraryIsExpired($0.itinerary, at: referenceDate) }
    }
    
    private func removeExpiredRecords(
        _ records: [SavedItineraryRecord],
        referenceDate: Date,
        postNotification: Bool
    ) -> (remainingRecords: [SavedItineraryRecord], removedCount: Int) {
        let expiredRecords = records.filter { itineraryIsExpired($0.itinerary, at: referenceDate) }
        
        guard !expiredRecords.isEmpty else {
            return (records, 0)
        }
        
        var removed = 0
        let expiredIDs = Set(expiredRecords.map(\.id))
        
        for record in expiredRecords {
            do {
                try fileManager.removeItem(at: record.fileURL)
                removed += 1
            } catch {
                print("Failed to remove expired itinerary file: \(error.localizedDescription)")
            }
        }
        
        let remainingRecords = records.filter { !expiredIDs.contains($0.id) }
        let remainingFingerprint = calculateDirectoryFingerprint(for: remainingRecords.map(\.fileURL))
        updateCache(records: remainingRecords, fingerprint: remainingFingerprint)
        
        if removed > 0 && postNotification {
            NotificationCenter.default.post(name: .savedItinerariesDidChange, object: nil)
        }
        
        return (remainingRecords, removed)
    }
    
    private func itineraryIsExpired(_ itinerary: Itinerary, at date: Date) -> Bool {
        date > itinerary.endTime.addingTimeInterval(expirationBuffer)
    }
    
    private func calculateDirectoryFingerprint(for fileURLs: [URL]) -> Int {
        var hasher = Hasher()
        
        for fileURL in fileURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            hasher.combine(fileURL.lastPathComponent)
            
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) {
                hasher.combine(values.fileSize ?? 0)
                hasher.combine(values.contentModificationDate?.timeIntervalSince1970 ?? 0)
            } else {
                hasher.combine(0)
                hasher.combine(0.0)
            }
        }
        
        return hasher.finalize()
    }
    
    private func cachedRecordsIfAvailable(for fingerprint: Int) -> [SavedItineraryRecord]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard cachedDirectoryFingerprint == fingerprint else {
            return nil
        }
        
        return cachedRecordsCache
    }
    
    private func updateCache(records: [SavedItineraryRecord], fingerprint: Int) {
        cacheLock.lock()
        cachedRecordsCache = records
        cachedDirectoryFingerprint = fingerprint
        cacheLock.unlock()
    }
    
    private func invalidateCache() {
        cacheLock.lock()
        cachedRecordsCache = []
        cachedDirectoryFingerprint = nil
        cacheLock.unlock()
    }
}

extension Notification.Name {
    static let savedItinerariesDidChange = Notification.Name("SavedItinerariesDidChange")
}
