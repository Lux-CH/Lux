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
    private var subscriberCount: Int = 0
    
    private init() {}
    
    func startBlinking() {
        subscriberCount += 1
        if subscriberCount == 1 {
            resumeTimer()
        }
    }
    
    func stopBlinking() {
        subscriberCount = max(0, subscriberCount - 1)
        if subscriberCount == 0 {
            pauseTimer()
        }
    }
    
    private func resumeTimer() {
        cancellable?.cancel()
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.isVisible.toggle()
            }
    }
    
    private func pauseTimer() {
        cancellable?.cancel()
        cancellable = nil
        isVisible = true
    }
    
    deinit {
        cancellable?.cancel()
    }
}
