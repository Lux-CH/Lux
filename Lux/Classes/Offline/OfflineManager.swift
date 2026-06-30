//
//  OfflineManager.swift
//  Lux
//
//  Created by Constantin Clerc on 13.06.2026.
//

import Foundation
import SwiftUI

@MainActor
final class OfflineManager: ObservableObject {
    static let shared = OfflineManager()

    enum State: Equatable {
        case absent
        case downloading(Double)
        case extracting
        case ready
        case failed(String)
    }

    @Published private(set) var state: State = .absent
    @Published private(set) var datasetReady = false
    @Published private(set) var lastImportDate: Date?
    @Published private(set) var bytesOnDisk: Int = 0

    private let settings = Settings.shared
    let network = NetworkMonitor()
    private(set) var store: OfflineGTFSStore?

    private let datasetURL = URL(string: "https://lux.cclerc.ch/offline.sqlite")!

    private init() {
        network.onChange = { [weak self] in self?.updateActivation() }
        loadExistingStoreIfEnabled()
    }

    private lazy var luxDir: URL = {
        var base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lux", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        var rv = URLResourceValues()
        rv.isExcludedFromBackup = true
        try? base.setResourceValues(rv)
        return base
    }()
    private lazy var dbURL: URL = luxDir.appendingPathComponent("offline.sqlite")

    private func loadExistingStoreIfEnabled() {
        guard settings.offlineModeEnabled,
              FileManager.default.fileExists(atPath: dbURL.path) else { return }
        do {
            let store = try OfflineGTFSStore(url: dbURL)
            self.store = store
            finishReady(store)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func enable() {
        settings.offlineModeEnabled = true
        if FileManager.default.fileExists(atPath: dbURL.path), store == nil {
            loadExistingStoreIfEnabled()
        }
        updateActivation()
    }

    func disable() {
        settings.offlineModeEnabled = false
        deleteDataset()
    }

    func setForceOffline(_ value: Bool) {
        settings.offlineForceOffline = value
        updateActivation()
    }

    var isWorking: Bool {
        switch state {
        case .downloading, .extracting: return true
        default: return false
        }
    }

    func startImport() {
        guard !isWorking else { return }
        state = .downloading(0)
        Task { await runPipeline() }
    }

    private func runPipeline() async {
        do {
            let downloader = GTFSDownloader()
            downloader.onProgress = { [weak self] p in
                Task { @MainActor in self?.state = .downloading(p) }
            }
            let tmpURL = luxDir.appendingPathComponent("offline.download.sqlite")
            let downloaded = try await downloader.download(from: datasetURL, to: tmpURL)

            await MainActor.run { self.state = .extracting }
            store = nil
            OfflineRouter.shared.register(nil)
            for url in [dbURL, dbURL.appendingPathExtension("wal"), dbURL.appendingPathExtension("shm")] {
                try? FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: downloaded, to: dbURL)

            let store = try OfflineGTFSStore(url: dbURL)
            guard store.stopCount() > 0 else {
                try? FileManager.default.removeItem(at: dbURL)
                throw NSError(domain: "Offline", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Le fichier téléchargé est invalide.")
                ])
            }
            self.store = store
            finishReady(store)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func deleteDataset() {
        OfflineRouter.shared.register(nil)
        store = nil
        for url in [dbURL, dbURL.appendingPathExtension("wal"), dbURL.appendingPathExtension("shm"),
                    luxDir.appendingPathComponent("offline.download.sqlite")] {
            try? FileManager.default.removeItem(at: url)
        }
        datasetReady = false
        lastImportDate = nil
        bytesOnDisk = 0
        settings.offlineLastImportDate = 0
        state = .absent
        updateActivation()
    }

    private func finishReady(_ store: OfflineGTFSStore) {
        OfflineRouter.shared.register(OfflineProvider(store: store))
        datasetReady = store.stopCount() > 0
        lastImportDate = store.importDate()
        if let date = lastImportDate { settings.offlineLastImportDate = date.timeIntervalSince1970 }
        bytesOnDisk = (try? FileManager.default.attributesOfItem(atPath: dbURL.path)[.size] as? Int) ?? 0
        state = datasetReady ? .ready : .absent
        updateActivation()
    }

    private var lastActive = false

    private func updateActivation() {
        let active = settings.offlineModeEnabled && datasetReady
            && (!network.isOnline || settings.offlineForceOffline)
        OfflineRouter.shared.setOfflineActive(active)
        if active != lastActive {
            lastActive = active
            NotificationCenter.default.post(name: NSNotification.Name("ReloadNearbyStops"), object: nil)
        }
        objectWillChange.send()
    }

    var isOfflineActive: Bool { OfflineRouter.shared.isOfflineActive }

    var isOnline: Bool { network.isOnline }
    var isOnWiFi: Bool { network.isOnWiFi }

    var needsInitialDownload: Bool {
        if case .absent = state { return settings.offlineModeEnabled }
        return false
    }

    var needsUpdate: Bool {
        guard settings.offlineModeEnabled, datasetReady, network.isOnline,
              let last = lastImportDate else { return false }
        return Date().timeIntervalSince(last) > 14 * 24 * 3600
    }
}

private final class GTFSDownloader: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((Double) -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?
    private var destination: URL?

    func download(from url: URL, to destination: URL) async throws -> URL {
        self.destination = destination
        try? FileManager.default.removeItem(at: destination)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let destination else { return }
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            continuation?.resume(throwing: NSError(domain: "Offline", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: String(localized: "Téléchargement impossible (\(http.statusCode)).")
            ]))
            continuation = nil
            return
        }
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            continuation?.resume(returning: destination)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { continuation?.resume(throwing: error); continuation = nil }
    }
}
