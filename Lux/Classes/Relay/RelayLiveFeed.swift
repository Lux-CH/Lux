//
//  RelayLiveFeed.swift
//  Lux
//
//  Created by Constantin Clerc on 18.07.2026.
//

import Foundation

/// Bridges a RelayClient AsyncStream with the legacy HTTP polling path.
/// While the WebSocket is connected, updates come exclusively from the stream;
/// whenever it is down (or `fallbackOnly` is set, e.g. offline mode or a
/// custom departure time), the legacy fetch runs on its old polling interval
/// so the app keeps working without the relay.
@MainActor
final class RelayLiveFeed<Value: Sendable> {
    private var streamTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?

    func start(
        fallbackOnly: Bool = false,
        fallbackInterval: Duration,
        stream: @escaping @Sendable () async -> AsyncStream<Value>?,
        fallbackFetch: @escaping @Sendable () async -> Value?,
        onUpdate: @escaping @MainActor (Value) -> Void
    ) {
        stop()

        if !fallbackOnly {
            streamTask = Task { [weak self] in
                guard let stream = await stream() else { return }
                for await value in stream {
                    if Task.isCancelled || self == nil { return }
                    onUpdate(value)
                }
            }
        }

        fallbackTask = Task { [weak self] in
            var firstIteration = true
            while !Task.isCancelled && self != nil {
                if !firstIteration || fallbackOnly {
                    // Skip the immediate fetch on the relay path: the relay
                    // replays its snapshot right after subscribing.
                    let socketConnected = await RelayClient.shared.isConnected
                    if fallbackOnly || !socketConnected {
                        if let value = await fallbackFetch(), !Task.isCancelled {
                            onUpdate(value)
                        }
                    }
                }
                firstIteration = false
                // While the socket is healthy this loop is only a watchdog, so
                // idle at a slower cadence than the legacy polling interval.
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
