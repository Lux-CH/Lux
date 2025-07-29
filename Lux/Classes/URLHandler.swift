//
//  URLHandler.swift
//  Lux
//
//  Created by Constantin Clerc on 29.07.2025.
//

import Foundation
import SwiftUI
import LuxCom

enum URLHandlerResult {
    case itinerary(Itinerary)
    case stopDetail(stopId: String, name: String)
    case confirmationRequired(URL)
    case error(URLHandlerError)
}

enum URLHandlerError: Error, LocalizedError {
    case invalidURL
    case fileTooLarge
    case invalidFile
    case networkError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .fileTooLarge:
            return "Fichier trop volumineux"
        case .invalidFile:
            return "Fichier invalide"
        case .networkError:
            return "Erreur réseau"
        case .decodingError:
            return "Erreur de décodage"
        }
    }
}

struct URLHandler {
    private static let maxFileSize: Int64 = 51200
    
    static func process(_ url: URL) async -> URLHandlerResult {
        if url.pathExtension == "luxtrip" || (url.scheme == "lux" && url.host == "itinerary") {
            return .confirmationRequired(url)
        }
        
        if let stopDetail = parseStopDetailURL(url) {
            return .stopDetail(stopId: stopDetail.stopId, name: stopDetail.name)
        }
        
        return .error(.invalidURL)
    }
    
    static func handleConfirmedItinerary(_ url: URL) async -> URLHandlerResult {
        if url.scheme == "lux" && url.host == "itinerary" {
            return await handleRemoteItinerary(url)
        } else {
            return await handleLocalItinerary(url)
        }
    }
    
    private static func parseStopDetailURL(_ url: URL) -> (stopId: String, name: String)? {
        guard let urlStr = url.absoluteString.components(separatedBy: "://").last,
              urlStr.contains("//") else {
            return nil
        }
        
        let components = urlStr.components(separatedBy: "//")
        guard components.count == 2,
              let decodedName = components[1].removingPercentEncoding else {
            return nil
        }
        
        return (stopId: components[0], name: decodedName)
    }
    
    private static func handleRemoteItinerary(_ url: URL) async -> URLHandlerResult {
        guard let query = url.query, !query.isEmpty else {
            return .error(.invalidURL)
        }
        
        let itinerarySharer = ItinerarySharer()
        
        if let downloadedItinerary = await itinerarySharer.downloadItinerary(String(query)) {
            return .itinerary(downloadedItinerary)
        } else {
            return .error(.networkError)
        }
    }
    
    private static func handleLocalItinerary(_ url: URL) async -> URLHandlerResult {
        let hasSSRAccess = url.startAccessingSecurityScopedResource()
        
        defer {
            if hasSSRAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = fileAttributes[.size] as? Int64,
               size > maxFileSize {
                return .error(.fileTooLarge)
            }
            
            let data = try Data(contentsOf: url)
            let itinerarySharer = ItinerarySharer()
            let decodedItinerary = try itinerarySharer.decode(data)
            
            guard itinerarySharer.validateItinerary(decodedItinerary) else {
                return .error(.invalidFile)
            }
            
            return .itinerary(decodedItinerary)
            
        } catch {
            return .error(.decodingError)
        }
    }
}
