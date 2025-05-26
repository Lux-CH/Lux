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
    var createdAt: Date
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
            
            var fullName: String {
                switch self {
                case .monday: return "Lundi"
                case .tuesday: return "Mardi"
                case .wednesday: return "Mercredi"
                case .thursday: return "Jeudi"
                case .friday: return "Vendredi"
                case .saturday: return "Samedi"
                case .sunday: return "Dimanche"
                }
            }
        }
        
        struct TimeComponents: Codable, Equatable {
            var hour: Int
            var minute: Int
            
            var displayString: String {
                return String(format: "%02d:%02d", hour, minute)
            }
            
            func toDate() -> Date {
                let calendar = Calendar.current
                let components = DateComponents(hour: hour, minute: minute)
                return calendar.date(from: components) ?? Date()
            }
        }
    }
    
    init(id: UUID = UUID(), name: String, symbol: String, coordinates: Coordinates, timeSchedule: TimeSchedule? = nil) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.coordinates = coordinates
        self.createdAt = Date()
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
            }
        }
        
        if let userLoc = userLocation {
            let shortcutLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            let distance = userLoc.distance(from: shortcutLocation)
            
            let distancePenalty = calculateDistancePenalty(distance: distance)
            print(name)
            print(distance)
            print(distancePenalty)
            score -= distancePenalty
            print(score)
        }
        
        return score
    }

    private func calculateDistancePenalty(distance: Double) -> Double {
        if distance < 25 {
            return 50.0
        } else if distance < 50 {
            return 35.0 * exp(-distance / 25.0) + 15.0
        } else if distance < 100 {
            return 25.0 * exp(-distance / 35.0) + 10.0
        } else if distance < 200 {
            let normalizedDistance = (distance - 100) / 100
            return 8.0 * (1.0 - normalizedDistance)
        } else if distance < 500 {
            let normalizedDistance = (distance - 200) / 300
            return 3.0 * (1.0 - normalizedDistance)
        } else {
            return 0.0
        }
    }
}
