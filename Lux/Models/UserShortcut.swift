//
//  UserShortcut.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import Foundation
import LuxCom
import CoreLocation

struct UserShortcut: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var symbol: String
    var coordinates: Coordinates
    var timeSchedule: TimeSchedule?
    
    struct Coordinates: Codable, Equatable {
        var latitude: Double
        var longitude: Double
        var locationName: String
    }
    
    struct TimeSchedule: Codable, Equatable {
        var daysOfWeek: Set<Weekday>
        var time: TimeComponents
        
        enum Weekday: Int, CaseIterable, Codable {
            case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday
            
            var displayName: String {
                switch self {
                case .monday: return "Lun"
                case .tuesday: return "Mar"
                case .wednesday: return "Mer"
                case .thursday: return "Jeu"
                case .friday: return "Ven"
                case .saturday: return "Sam"
                case .sunday: return "Dim"
                }
            }
            
            var shortDisplayName: String {
                switch self {
                case .monday: return "L"
                case .tuesday: return "Ma"
                case .wednesday: return "Me"
                case .thursday: return "J"
                case .friday: return "V"
                case .saturday: return "S"
                case .sunday: return "D"
                }
            }
        }
        
        struct TimeComponents: Codable, Equatable {
            var hour: Int
            var minute: Int
            
            var displayString: String {
                return String(format: "%02d:%02d", hour, minute)
            }
        }
    }
    
    init(id: UUID = UUID(), name: String, symbol: String, coordinates: Coordinates, timeSchedule: TimeSchedule? = nil) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.coordinates = coordinates
        self.timeSchedule = timeSchedule
    }
    
    func toSearchResult() -> SearchResult {
        return SearchResult(
            type: .place,
            tokens: [[0, name.count]],
            name: name,
            id: id.uuidString,
            lat: coordinates.latitude,
            lon: coordinates.longitude,
            areas: [],
            score: 1.0
        )
    }
    
    func relevanceScore(currentDate: Date = Date(), userLocation: CLLocation? = nil, originalIndex: Int? = nil) -> Double {
        var score: Double = 0
        
        score += 1.0
        
        if let index = originalIndex {
            let orderBonus = max(0, 2.0 - (Double(index) * 0.5))
            score += orderBonus
        }
        
        if let schedule = timeSchedule {
            let calendar = Calendar.current
            let currentWeekday = calendar.component(.weekday, from: currentDate)
            let currentHour = calendar.component(.hour, from: currentDate)
            let currentMinute = calendar.component(.minute, from: currentDate)
            
            // convert to our weekday enum
            let mappedWeekday = currentWeekday == 1 ? 7 : currentWeekday - 1
            
            if let weekday = TimeSchedule.Weekday(rawValue: mappedWeekday),
               schedule.daysOfWeek.contains(weekday) {
                score += 10.0
                
                let currentTimeInMinutes = currentHour * 60 + currentMinute
                let scheduledTimeInMinutes = schedule.time.hour * 60 + schedule.time.minute
                let timeDifference = abs(currentTimeInMinutes - scheduledTimeInMinutes)
                
                if timeDifference <= 240 {
                    let proximityScore = max(0, 5.0 - (Double(timeDifference) / 48.0))
                    score += proximityScore
                }
            } else {
                let timeDifference = abs(currentHour * 60 + currentMinute - schedule.time.hour * 60 + schedule.time.minute)
                if timeDifference <= 240 {
                    let timeOnlyScore = max(0, 3.0 - (Double(timeDifference) / 80.0))
                    score += timeOnlyScore
                }
            }
        }
        
        if let userLoc = userLocation {
            let shortcutLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            let distance = userLoc.distance(from: shortcutLocation)
            
            let distancePenalty = calculateDistancePenalty(distance: distance)
            score -= distancePenalty
        }
        
        return score
    }

    private func calculateDistancePenalty(distance: Double) -> Double {
        let distanceKm = distance / 1000.0
        
        if distanceKm < 0.025 {
            return 100.0
        } else if distanceKm < 0.1 {
            return 80.0 + (20.0 * (0.1 - distanceKm) / 0.075)
        } else if distanceKm < 0.5 {
            return 60.0 * exp(-distanceKm * 3.0) + 20.0
        } else if distanceKm < 1.0 {
            let normalizedDistance = (distanceKm - 0.5) / 0.5
            return 40.0 * (1.0 - pow(normalizedDistance, 0.7)) + 15.0
        } else if distanceKm < 2.0 {
            let normalizedDistance = (distanceKm - 1.0) / 1.0
            return 25.0 * (1.0 - pow(normalizedDistance, 0.6)) + 8.0
        } else {
            return max(0.5, 5.0 * exp(-distanceKm / 20.0))
        }
    }
}
