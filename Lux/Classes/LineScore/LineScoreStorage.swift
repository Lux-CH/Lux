//
//  LineScoreStorage.swift
//  Lux
//
//  Created by Constantin Clerc on 25.05.2025.
//

import Foundation
import Combine

protocol LineScoreStorageProtocol {
    func loadLineScores() -> [LineScore]
    func addLineScore(_ score: LineScore) throws
    func updateLineScore(_ score: LineScore) throws
    func deleteLineScore(for routeShortName: String) throws
    
    var lineScoresPublisher: AnyPublisher<[LineScore], Never> { get }
}

class LineScoreStorage: LineScoreStorageProtocol {
    private let fileManager = FileManager.default
    private let lineScoresSubject = CurrentValueSubject<[LineScore], Never>([])
    private var currentLineScores: [LineScore] {
        get { lineScoresSubject.value }
        set { lineScoresSubject.send(newValue) }
    }
    
    var lineScoresPublisher: AnyPublisher<[LineScore], Never> {
        lineScoresSubject.eraseToAnyPublisher()
    }
    
    private var lineScoresURL: URL {
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let luxDirectory = appSupportDirectory.appendingPathComponent("Lux")
        
        try? fileManager.createDirectory(at: luxDirectory, withIntermediateDirectories: true)
        
        return luxDirectory.appendingPathComponent("lineScores.data")
    }
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.ch.cclerc.lux.shareddata")
    }
    
    init() {
        lineScoresSubject.send(loadLineScoresFromDisk())
    }
    
    private func loadLineScoresFromDisk() -> [LineScore] {
        guard fileManager.fileExists(atPath: lineScoresURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: lineScoresURL)
            let decoder = PropertyListDecoder()
            return try decoder.decode([LineScore].self, from: data)
        } catch {
            print("Error loading line scores: \(error.localizedDescription)")
            return []
        }
    }
    
    private func persistToDisk(_ scores: [LineScore]) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(scores)
        try data.write(to: lineScoresURL, options: .atomic)
        
        syncToSharedDefaults(scores)
    }
    
    private func syncToSharedDefaults(_ scores: [LineScore]) {
        guard let sharedDefaults = sharedDefaults else {
            print("warning!! : cld not access shared stuff for widget sync")
            return
        }
        
        do {
            let encoder = PropertyListEncoder()
            let data = try encoder.encode(scores)
            sharedDefaults.set(data, forKey: "lineScores")
            sharedDefaults.synchronize()
        } catch {
            print("error \(error.localizedDescription)")
        }
    }
    
    func saveLineScores(_ scores: [LineScore]) throws {
        currentLineScores = scores
        try persistToDisk(scores)
    }
    
    func loadLineScores() -> [LineScore] {
        return currentLineScores
    }
    
    func addLineScore(_ score: LineScore) throws {
        var updated = currentLineScores
        updated.append(score)
        try saveLineScores(updated)
    }
    
    func updateLineScore(_ score: LineScore) throws {
        var updated = currentLineScores
        if let index = updated.firstIndex(where: { $0.routeShortName == score.routeShortName }) {
            updated[index] = score
            try saveLineScores(updated)
        }
    }
    
    func deleteLineScore(for routeShortName: String) throws {
        let updated = currentLineScores.filter { $0.routeShortName != routeShortName }
        try saveLineScores(updated)
    }
}
