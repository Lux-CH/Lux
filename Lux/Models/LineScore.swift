//
//  LineScore.swift
//  Lux
//
//  Created by Constantin Clerc on 25.05.2025.
//

import Foundation

struct LineScore: Codable, Identifiable {
    var id = UUID()
    let routeShortName: String
    private(set) var totalScore: Double
    private(set) var usageCount: Int
    
    init(routeShortName: String, initialScore: Double = 1.0) {
        self.routeShortName = routeShortName
        self.totalScore = initialScore
        self.usageCount = 1
    }
    
    mutating func addScore(_ points: Double = 0.1) {
        totalScore += points
        usageCount += 1
    }
}
