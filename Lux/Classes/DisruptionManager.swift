//
//  DisruptionManager.swift
//  Lux
//
//  Created by Constantin Clerc on 27.05.2025.
//

import Foundation
import LuxCom

final class DisruptionManager: ObservableObject {
    @Published var disruptions: [Disruption] = []
    private var refreshTimer: Timer?
    
    init() {
        Task {
            await fetchDisruptions()
        }
        startAutoRefresh()
    }
    
    deinit {
        stopAutoRefresh()
    }
    
    func fetchDisruptions() async {
        do {
            let fetchedDisruptions = try await getDisruptions()
            
            await MainActor.run {
                self.disruptions = fetchedDisruptions
            }
        } catch {
            print(error)
        }
    }
    
    func disruptions(for line: String) -> [Disruption] {
        disruptions.filter { $0.line == line }
    }
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.fetchDisruptions()
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
