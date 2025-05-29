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
        
        if let connections = loadedConnections[cleanStopId] {
            let sortedConnections = LineScoreManager.shared.getSortedRouteNames(connections)
            completion(sortedConnections)
            return
        }
        
        loadingTasks[cleanStopId]?.cancel()
        
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
                    print("error loading connections for \(cleanStopId): \(error)")
                    promise(.success([]))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] connections in
            guard let self = self else { return }
            
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
