//
//  BlinkManager.swift
//  Lux
//
//  Created by Constantin Clerc on 24.05.2025.
//


import SwiftUI
import Combine

@MainActor
class BlinkManager: ObservableObject {
    static let shared = BlinkManager()
    
    @Published var isVisible: Bool = true
    private var cancellable: AnyCancellable?
    
    private init() {
        startBlinking()
    }
    
    private func startBlinking() {
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.isVisible.toggle()
            }
    }
    
    deinit {
        cancellable?.cancel()
    }
}
