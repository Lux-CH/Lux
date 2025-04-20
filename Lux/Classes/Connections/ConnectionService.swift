//
//  ConnectionService.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

// FIXME: Risk of memory leak, pls flush cache
import Foundation
import Combine

class ConnectionService: ObservableObject {
    static let shared = ConnectionService()
    
    @Published private(set) var loadedConnections = [String: [String]]()
    
    private var extractor: ConnectionExtractor?
    private var loadingTasks = [String: AnyCancellable]()
    
    private init() {
        do {
            self.extractor = try ConnectionExtractor()
        } catch {
            print("Failed to initialize ConnectionExtractor: \(error)")
        }
    }
    
    func getConnections(for stopId: String, completion: @escaping ([String]) -> Void) {
        let cleanStopId = stopId.replacingOccurrences(of: "ch_Parent", with: "ch_")
        
        // Check if we already have the connections loaded
        if let connections = loadedConnections[cleanStopId] {
            completion(connections)
            return
        }
        
        // Cancel existing task for this stop if any
        loadingTasks[cleanStopId]?.cancel()
        
        // Create a new loading task
        loadingTasks[cleanStopId] = Future<[String], Never> { promise in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self, let extractor = self.extractor else {
                    promise(.success([]))
                    return
                }
                
                do {
                    if let connections = try extractor.extractSpecificKey(cleanStopId) {
                        promise(.success(connections))
                    } else {
                        promise(.success([]))
                    }
                } catch {
                    print("Error loading connections for \(cleanStopId): \(error)")
                    promise(.success([]))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] connections in
            guard let self = self else { return }
            
            self.loadedConnections[cleanStopId] = connections
            completion(connections)
            self.loadingTasks.removeValue(forKey: cleanStopId)
        }
    }
    
    func clearCache() {
        loadedConnections.removeAll()
    }
}
