//
//  CacheCleaner.swift
//  Lux
//
//  Created by Constantin Clerc on 03.08.2025.
//

import Foundation

struct CacheCleaner {
    static func performCleanup() async {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return
        }
        
        cleanDirectory(at: URL(fileURLWithPath: NSTemporaryDirectory()))
        cleanDirectory(at: documentsPath.appendingPathComponent("Inbox"))
        cleanDirectory(at: libraryPath.appendingPathComponent("Logs"))
        print("cleanup done !")
    }
    
    static func cleanDirectory(at url: URL) {
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: url.path) else {
            print("\(url.path)")
            return
        }
        
        do {
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            for item in contents {
                try fm.removeItem(at: item)
            }
        } catch {
            print(error)
        }
    }
}
