//
//  ShortcutStorage.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import Foundation
import Combine

protocol ShortcutStorageProtocol {
    func saveShortcuts(_ shortcuts: [UserShortcut]) throws
    func loadShortcuts() -> [UserShortcut]
    func addShortcut(_ shortcut: UserShortcut) throws
    func updateShortcut(_ shortcut: UserShortcut) throws
    func deleteShortcut(withId id: UUID) throws
    
    var shortcutsPublisher: AnyPublisher<[UserShortcut], Never> { get }
}

class ShortcutStorage: ShortcutStorageProtocol {
    private let fileManager = FileManager.default
    private let shortcutsSubject = CurrentValueSubject<[UserShortcut], Never>([])
    private var currentShortcuts: [UserShortcut] {
        get { shortcutsSubject.value }
        set { shortcutsSubject.send(newValue) }
    }
    
    var shortcutsPublisher: AnyPublisher<[UserShortcut], Never> {
        shortcutsSubject.eraseToAnyPublisher()
    }
    
    private var shortcutsURL: URL {
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let luxDirectory = appSupportDirectory.appendingPathComponent("Lux")
        
        try? fileManager.createDirectory(at: luxDirectory, withIntermediateDirectories: true)
        
        return luxDirectory.appendingPathComponent("shortcuts.data")
    }
    
    init() {
        shortcutsSubject.send(loadShortcutsFromDisk())
    }
    
    private func loadShortcutsFromDisk() -> [UserShortcut] {
        guard fileManager.fileExists(atPath: shortcutsURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: shortcutsURL)
            let decoder = PropertyListDecoder()
            return try decoder.decode([UserShortcut].self, from: data)
        } catch {
            print("Error loading shortcuts: \(error.localizedDescription)")
            return []
        }
    }
    
    private func persistToDisk(_ shortcuts: [UserShortcut]) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(shortcuts)
        try data.write(to: shortcutsURL, options: .atomic)
    }
    
    func saveShortcuts(_ shortcuts: [UserShortcut]) throws {
        currentShortcuts = shortcuts
        try persistToDisk(shortcuts)
    }
    
    func loadShortcuts() -> [UserShortcut] {
        return currentShortcuts
    }
    
    func addShortcut(_ shortcut: UserShortcut) throws {
        var updated = currentShortcuts
        updated.append(shortcut)
        try saveShortcuts(updated)
    }
    
    func updateShortcut(_ shortcut: UserShortcut) throws {
        var updated = currentShortcuts
        if let index = updated.firstIndex(where: { $0.id == shortcut.id }) {
            updated[index] = shortcut
            try saveShortcuts(updated)
        }
    }
    
    func deleteShortcut(withId id: UUID) throws {
        let updated = currentShortcuts.filter { $0.id != id }
        try saveShortcuts(updated)
    }
}
