//
//  NetworkMonitor.swift
//  Lux
//
//  Created by Constantin Clerc on 13.06.2026.
//

import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var isExpensive: Bool = false

    var isOnWiFi: Bool { isOnline && !isExpensive }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ch.cclerc.lux.networkmonitor")
    var onChange: (() -> Void)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let expensive = path.isExpensive
            Task { @MainActor in
                guard let self else { return }
                self.isExpensive = expensive
                guard self.isOnline != online else { return }
                self.isOnline = online
                self.onChange?()
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
