//
//  LineScoreManager.swift
//  Lux
//
//  Created by Constantin Clerc on 25.05.2025.
//

import Foundation
import Combine
import SwiftUI

class LineScoreManager: ObservableObject {
    static let shared = LineScoreManager()
    
    @Published var lineScores: [LineScore] = []
    
    private let storage: LineScoreStorageProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private init(storage: LineScoreStorageProtocol = LineScoreStorage()) {
        self.storage = storage
        
        storage.lineScoresPublisher
            .sink { [weak self] scores in
                self?.lineScores = scores
            }
            .store(in: &cancellables)
        
        self.lineScores = storage.loadLineScores()
    }
    
    func addScore(to routeShortName: String, points: Double = 0.1) {
        if let existingIndex = lineScores.firstIndex(where: { $0.routeShortName == routeShortName }) {
            var updatedScore = lineScores[existingIndex]
            updatedScore.addScore(points)
            do {
                try storage.updateLineScore(updatedScore)
            } catch {
                print("error updating line score: \(error.localizedDescription)")
            }
        } else {
            let newScore = LineScore(routeShortName: routeShortName, initialScore: points)
            do {
                try storage.addLineScore(newScore)
            } catch {
                print("error adding line score: \(error.localizedDescription)")
            }
        }
    }
    
    func getScore(for routeShortName: String) -> Double {
        return lineScores.first { $0.routeShortName == routeShortName }?.totalScore ?? 0.0
    }
    
    func getSortedRouteNames(_ routeNames: [String]) -> [String] {
        return routeNames.sorted { routeA, routeB in
            let scoreA = getScore(for: routeA)
            let scoreB = getScore(for: routeB)
            
            if scoreA != scoreB {
                return scoreA > scoreB
            }
            
            return routeA < routeB
        }
    }
    
    func resetScore(for routeShortName: String) {
        if let existingIndex = lineScores.firstIndex(where: { $0.routeShortName == routeShortName }) {
            var updatedScore = lineScores[existingIndex]
            updatedScore.resetScore()
            do {
                try storage.updateLineScore(updatedScore)
            } catch {
                print("Error resetting line score: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteScore(for routeShortName: String) {
        do {
            try storage.deleteLineScore(for: routeShortName)
        } catch {
            print("Error deleting line score: \(error.localizedDescription)")
        }
    }
}
