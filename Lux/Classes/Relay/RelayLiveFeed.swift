//
//  RelayLiveFeed.swift
//  Lux
//
//  Created by Constantin Clerc on 18.07.2026.
//

import Foundation

@MainActor
final class RelayLiveFeed<Value: Sendable> {
    private var streamTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?
    private var receivedStreamValue = false

    func start(
        fallbackOnly: Bool = false,
        fallbackInterval: Duration,
        stream: @escaping @Sendable () async -> AsyncStream<Value>?,
        fallbackFetch: @escaping @Sendable () async -> Value?,
        onUpdate: @escaping @MainActor (Value) -> Void
    ) {
        stop()
        receivedStreamValue = false

        if !fallbackOnly {
            streamTask = Task { [weak self] in
                guard let stream = await stream() else { return }
                for await value in stream {
                    if Task.isCancelled || self == nil { return }
                    self?.receivedStreamValue = true
                    onUpdate(value)
                }
            }
        }

        fallbackTask = Task { [weak self] in
            var firstIteration = true
            while !Task.isCancelled && self != nil {
                if !firstIteration || fallbackOnly {
                    let socketConnected = await RelayClient.shared.isConnected
                    if fallbackOnly || !socketConnected || self?.receivedStreamValue == false {
                        if let value = await fallbackFetch(), !Task.isCancelled {
                            onUpdate(value)
                        }
                    }
                }
                firstIteration = false
                let connected = fallbackOnly ? false : await RelayClient.shared.isConnected
                try? await Task.sleep(for: connected ? max(fallbackInterval, .seconds(15)) : fallbackInterval)
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        fallbackTask?.cancel()
        streamTask = nil
        fallbackTask = nil
    }

    deinit {
        streamTask?.cancel()
        fallbackTask?.cancel()
    }
}
