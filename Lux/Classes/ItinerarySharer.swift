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
}
