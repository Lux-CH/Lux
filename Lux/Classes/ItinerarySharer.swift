//
//  ItinerarySharer.swift
//  Lux
//
//  Created by Constantin Clerc on 01.06.2025.
//

import MessagePacker
import LuxCom
import SwiftUI
import Foundation

class ItinerarySharer {
    private func encode(_ itinerary: Itinerary) throws -> Data {
        return try MessagePackEncoder().encode(itinerary)
    }
    func decode(_ data: Data) throws -> Itinerary {
        return try MessagePackDecoder().decode(Itinerary.self, from: data)
    }
    
    func downloadItinerary(_ identifier: String) async -> Result<Itinerary, URLHandlerError> {
        guard let url = URL(string: "https://0x0.st/\(identifier).luxtrip") else {
            return .failure(.invalidURL)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    return .failure(.expiredLink)
                }
                guard httpResponse.statusCode == 200 else {
                    return .failure(.networkError)
                }
            }
            
            guard data.count <= 51200 else {
                return .failure(.fileTooLarge)
            }
            
            let itinerary = try decode(data)
            guard validateItinerary(itinerary) else {
                return .failure(.invalidFile)
            }
            
            return .success(itinerary)
            
        } catch {
            return .failure(.networkError)
        }
    }
    
    
    func uploadItinerary(_ itinerary: Itinerary) async -> Result<String, URLHandlerError> {
        do {
            let data = try encode(itinerary)
            
            let expiresInHours = await MainActor.run {
                Settings.shared.luxTripShareExpiryTimeH
            }
            
            let boundary = UUID().uuidString
            var body = Data()
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"Itineraire.luxtrip\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"expires\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(expiresInHours)".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            guard let url = URL(string: "https://0x0.st") else {
                return .failure(.invalidURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    return .failure(.networkError)
                }
            }
            
            guard let responseString = String(data: responseData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return .failure(.networkError)
            }
            
            guard responseString.hasPrefix("https://0x0.st/") && responseString.hasSuffix(".luxtrip") else {
                return .failure(.networkError)
            }
            
            if let url = URL(string: responseString),
               let lastPathComponent = url.lastPathComponent.split(separator: ".").first {
                return .success(String(lastPathComponent))
            } else {
                return .failure(.networkError)
            }
        } catch {
            return .failure(.networkError)
        }
    }

    
    func validateItinerary(_ itinerary: Itinerary) -> Bool {
        let now = Date()
        let oneYearFromNow = now.addingTimeInterval(365 * 24 * 60 * 60)
        let oneYearAgo = now.addingTimeInterval(-365 * 24 * 60 * 60)
        
        guard itinerary.startTime >= oneYearAgo && itinerary.startTime <= oneYearFromNow else {
            return false
        }
        
        guard itinerary.endTime >= oneYearAgo && itinerary.endTime <= oneYearFromNow else {
            return false
        }
        
        guard itinerary.startTime <= itinerary.endTime else {
            return false
        }
        
        guard itinerary.duration > 0 && itinerary.duration <= 86400 else { // 24hr
            return false
        }
        
        guard itinerary.legs.count > 0 && itinerary.legs.count <= 20 else {
            return false
        }
        
        for leg in itinerary.legs {
            guard validateLeg(leg) else {
                return false
            }
        }
        
        return true
    }
    
    private func validateLeg(_ leg: Leg) -> Bool {
        guard validatePlace(leg.from) && validatePlace(leg.to) else {
            return false
        }
        
        guard leg.duration >= 0 && leg.duration <= 86400 else {
            return false
        }
        
        if let stops = leg.intermediateStops, stops.count > 100 {
            return false
        }
        
        if let headsign = leg.headsign, headsign.count > 200 {
            return false
        }
        
        if let routeShortName = leg.routeShortName, routeShortName.count > 50 {
            return false
        }
        
        return true
    }

    private func validatePlace(_ place: Place) -> Bool {
        guard place.lat >= -90 && place.lat <= 90 else {
            return false
        }
        
        guard place.lon >= -180 && place.lon <= 180 else {
            return false
        }
        
        guard place.name.count <= 300 else {
            return false
        }
        
        return true
    }
}
