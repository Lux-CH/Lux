//
//  ShortcutManager.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import Foundation
import Combine
import SwiftUI

class ShortcutManager: ObservableObject {
    @Published var shortcuts: [UserShortcut] = []
    @Published var visibleShortcuts: [UserShortcut] = []
    
    private let storage: ShortcutStorageProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let maxVisibleShortcuts = 2
    
    init(storage: ShortcutStorageProtocol = ShortcutStorage()) {
        self.storage = storage
        
        storage.shortcutsPublisher
            .sink { [weak self] shortcuts in
                self?.shortcuts = shortcuts
                self?.updateVisibleShortcuts()
            }
            .store(in: &cancellables)
        
        self.shortcuts = storage.loadShortcuts()
        updateVisibleShortcuts()
    }
    
    private func updateVisibleShortcuts() {
        visibleShortcuts = Array(shortcuts.prefix(maxVisibleShortcuts))
    }
    
    func addShortcut(_ shortcut: UserShortcut) {
        do {
            try storage.addShortcut(shortcut)
        } catch {
            print("error adding shortcut !! \(error.localizedDescription)")
        }
    }
    
    func updateShortcut(_ shortcut: UserShortcut) {
        do {
            try storage.updateShortcut(shortcut)
        } catch {
            print("error updating shortcut ! \(error.localizedDescription)")
        }
    }
    
    func deleteShortcut(withId id: UUID) {
        do {
            try storage.deleteShortcut(withId: id)
        } catch {
            print("err deleting shortcut \(error.localizedDescription)")
        }
    }
    
    func moveShortcut(fromIndex: Int, toIndex: Int) {
        var updatedShortcuts = shortcuts
        let shortcut = updatedShortcuts.remove(at: fromIndex)
        updatedShortcuts.insert(shortcut, at: toIndex)
        
        do {
            try storage.saveShortcuts(updatedShortcuts)
        } catch {
            print("err reordering shortcuts \(error.localizedDescription)")
        }
    }
}
