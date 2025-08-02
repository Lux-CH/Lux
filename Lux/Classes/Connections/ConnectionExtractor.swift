//
//  ConnectionExtractor.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import Foundation

class ConnectionExtractor: ObservableObject {
    private let url: URL
    
    private var mappedData: Data?
    
    init(fromBundle filename: String = "connections") throws {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "plist") else {
            throw BinaryPlistError.fileNotFound(filename: "\(filename).plist")
        }
        self.url = url
        try mapFile()
    }
    
    private func mapFile() throws {
        mappedData = try Data(contentsOf: url, options: .mappedIfSafe)
    }
    

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
    
    func releaseResources() {
        mappedData = nil
    }
    
    enum BinaryPlistError: Error {
        case fileNotFound(filename: String)
        case dataNotLoaded
        case invalidPlistFormat
    }
}
