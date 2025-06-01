//
//  ShortcutManager.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import Foundation
import Combine
import SwiftUI
import CoreLocation

class ShortcutManager: ObservableObject {
    @ObservedObject var settings = Settings.shared
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
    
    func updateVisibleShortcuts(userLocation: CLLocation? = nil) {
        if settings.useTimeBasedRelevance {
            let sortedByRelevance = shortcuts.enumerated().sorted { element1, element2 in
                let score1 = element1.element.relevanceScore(userLocation: userLocation, originalIndex: element1.offset)
                let score2 = element2.element.relevanceScore(userLocation: userLocation, originalIndex: element2.offset)
                return score1 > score2
            }.map { $0.element }
            
            visibleShortcuts = Array(sortedByRelevance.prefix(maxVisibleShortcuts))
        } else {
            visibleShortcuts = Array(shortcuts.prefix(maxVisibleShortcuts))
        }
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
        guard fromIndex >= 0 && fromIndex < shortcuts.count,
              toIndex >= 0 && toIndex <= shortcuts.count,
              fromIndex != toIndex else {
            return
        }
        
        var updatedShortcuts = shortcuts
        let shortcut = updatedShortcuts.remove(at: fromIndex)
        
        let adjustedToIndex = toIndex > fromIndex ? toIndex - 1 : toIndex
        updatedShortcuts.insert(shortcut, at: adjustedToIndex)
        
        do {
            try storage.saveShortcuts(updatedShortcuts)
        } catch {
            print("err reordering shortcuts \(error.localizedDescription)")
        }
    }
}
