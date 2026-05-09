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
            print(error)
        }
    }
    
    func getConnections(for stopId: String, completion: @escaping ([String]) -> Void) {
        let cleanStopId = stopId.replacingOccurrences(of: "ch_Parent", with: "ch_")
        
        if let connections = loadedConnections[cleanStopId] {
            let sortedConnections = LineScoreManager.shared.getSortedRouteNames(connections)
            completion(sortedConnections)
            return
        }
        
        loadingTasks[cleanStopId]?.cancel()

        loadingTasks[cleanStopId] = Future<[String], Never> { [weak self] promise in
            guard let self = self, let extractor = self.extractor else {
                promise(.success([]))
                return
            }

            Task(priority: .userInitiated) {
                do {
                    let connections = try await extractor.extractSpecificKey(cleanStopId) ?? []
                    promise(.success(connections))
                } catch {
                    print("\(cleanStopId) \(error)")
                    promise(.success([]))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] connections in
            guard let self = self else { return }
            
            if self.loadedConnections.count > 100 {
                if let keyToRemove = self.loadedConnections.keys.first {
                    self.loadedConnections.removeValue(forKey: keyToRemove)
                }
            }
            self.loadedConnections[cleanStopId] = connections
            
            let sortedConnections = LineScoreManager.shared.getSortedRouteNames(connections)
            completion(sortedConnections)
            self.loadingTasks.removeValue(forKey: cleanStopId)
        }
    }
    
    func clearCache() {
        loadedConnections.removeAll()
    }
}
