//
//  ConnectionExtractor.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import Foundation

struct StopConnection: Hashable, Sendable {
    let line: String
    let agency: String?
}

actor ConnectionExtractor {
    private let url: URL
    private var table: [String: [StopConnection]]?

    init() throws {
        guard let url = Bundle.main.url(forResource: "connections", withExtension: "plist") else {
            throw BinaryPlistError.fileNotFound
        }
        self.url = url
    }

    func extractSpecificKey(_ key: String) throws -> [StopConnection]? {
        if table == nil {
            table = try loadTable()
        }
        return table?[key]
    }

    private func loadTable() throws -> [String: [StopConnection]] {
        try autoreleasepool {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [Any]] else {
                throw BinaryPlistError.invalidPlistFormat
            }
            var result = [String: [StopConnection]](minimumCapacity: plist.count)
            for (key, entries) in plist {
                result[key] = entries.compactMap { entry in
                    if let pair = entry as? [String], let line = pair.first {
                        return StopConnection(line: line, agency: pair.count > 1 && !pair[1].isEmpty ? pair[1] : nil)
                    }
                    if let line = entry as? String {
                        return StopConnection(line: line, agency: nil)
                    }
                    return nil
                }
            }
            return result
        }
    }

    enum BinaryPlistError: Error {
        case fileNotFound
        case invalidPlistFormat
    }
}
