//
//  ConnectionExtractor.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import Foundation

class ConnectionExtractor {
    private let url: URL
    
    private var mappedData: Data?
    
    init(fromBundle filename: String = "connections") throws {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "plist") else {
            throw BinaryPlistError.fileNotFound(filename: "\(filename).plist")
        }
        self.url = url
        try mapFile()
    }
    
    init(url: URL) throws {
        self.url = url
        try mapFile()
    }
    
    // mem-maps the file for efficient acccess
    private func mapFile() throws {
        mappedData = try Data(contentsOf: url, options: .mappedIfSafe)
    }
    
    /// Extracts a specific key from the plist
    /// - Parameter key: The exact key to extract
    /// - Returns: The value associated with the key if found
    func extractSpecificKey(_ key: String) throws -> [String]? {
        guard let data = mappedData else {
            throw BinaryPlistError.dataNotLoaded
        }
        
        let stream = InputStream(data: data)
        stream.open()
        defer { stream.close() }
        
        guard let plist = try PropertyListSerialization.propertyList(with: stream,
                                                                     options: .mutableContainersAndLeaves,
                                                                     format: nil) as? [String: Any] else {
            throw BinaryPlistError.invalidPlistFormat
        }
        
        return plist[key] as? [String]
    }
    
    // release mem ressources
    func releaseResources() {
        mappedData = nil
    }
    
    enum BinaryPlistError: Error {
        case fileNotFound(filename: String)
        case dataNotLoaded
        case invalidPlistFormat
        case keyNotFound(key: String)
    }
}
