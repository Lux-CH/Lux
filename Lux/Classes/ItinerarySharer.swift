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
    func getPathFromItinerary(_ itinerary: Itinerary) -> URL? {
        do {
            return try saveDataToTemp(data: encode(itinerary))
        }
        catch {
            print("error \(error)")
        }
        return nil
    }
    
    private func encode(_ itinerary: Itinerary) throws -> Data {
        return try MessagePackEncoder().encode(itinerary)
    }
    func decode(_ data: Data) throws -> Itinerary {
        return try MessagePackDecoder().decode(Itinerary.self, from: data)
    }
    func cleanUp() {
        do {
            let tempDirectory = FileManager.default.temporaryDirectory
            let directory = tempDirectory.appendingPathComponent("sharedItineraries/")
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        }
        catch {
            print(error)
        }
    }
    private func saveDataToTemp(data: Data) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let directory = tempDirectory.appendingPathComponent("sharedItineraries/\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("Itineraire.luxtrip")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        try data.write(to: fileURL)
        return fileURL
    }
    
    func downloadItinerary(_ identifier: String) async -> Itinerary? {
        guard let url = URL(string: "https://0x0.st/\(identifier).luxtrip") else {
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    return nil
                }
            }
            
            guard data.count <= 51200 else {
                return nil
            }
            
            let itinerary = try decode(data)
            guard validateItinerary(itinerary) else {
                return nil
            }
            
            return itinerary
            
        } catch {
            return nil
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
