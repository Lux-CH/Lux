//
//  ConnectionExtractor.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import Foundation
import SwiftUI

class ConnectionExtractor: ObservableObject {
    @ObservedObject var settings = Settings.shared
    private let url: URL
    
    private var mappedData: Data?
    
    init() throws {
        guard let url = Bundle.main.url(forResource: "connections", withExtension: "plist") else {
            throw BinaryPlistError.fileNotFound
        }
        self.url = url
        try mapFile()
    }
    
    private func mapFile() throws {
        mappedData = try Data(contentsOf: url, options: .mappedIfSafe)
    }
    
    func extractSpecificKey(_ key: String) async throws -> [String]? {
        guard let data = mappedData else {
            throw BinaryPlistError.dataNotLoaded
        }
        
        let stream = InputStream(data: data)
        stream.open()
        defer { stream.close() }
        
        guard let plist = try PropertyListSerialization.propertyList(with: stream, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
            throw BinaryPlistError.invalidPlistFormat
        }
        
        return plist[key] as? [String]
    }
    
    func releaseResources() {
        mappedData = nil
    }
    
    enum BinaryPlistError: Error {
        case fileNotFound
        case dataNotLoaded
        case invalidPlistFormat
    }
}
