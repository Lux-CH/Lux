//
//  RelayClient.swift
//  Lux
//
//  Created by Constantin Clerc on 18.07.2026.
//

import Foundation
import UIKit
import LuxCom

/// Shared WebSocket client for the lux-relay server. The relay polls the
/// upstream APIs (MOTIS / disruptions) server-side and only pushes
/// a message when the payload actually changed, replacing the app's HTTP
/// polling loops. Subscriptions are exposed as AsyncStreams; the relay replays
/// the last known payload on subscribe.
actor RelayClient {
    static let shared = RelayClient()

    private static let url = URL(string: "wss://lux.cclerc.ch/ws")!

    private struct SubscriptionKey: Hashable {
        let channel: String // "dep" | "trip" | "dis"
        let src: String
        let id: String
        let extra: String
    }

    private struct Subscriber {
        let deliver: (Data) -> Void
        let subscribeMessage: String
    }

    private var task: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var pingLoop: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var suspendedForBackground = false
    private var subscribers: [SubscriptionKey: [UUID: Subscriber]] = [:]

    /// True when the socket is connected; RelayLiveFeed uses this to decide
    /// whether the HTTP fallback needs to run.
    private(set) var isConnected = false

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        Task { await self.observeLifecycle() }
    }

    // MARK: - Public subscription API

    func departures(
        stopId: String,
        n: Int,
        radius: Int?
    ) -> AsyncStream<StopTimes> {
        let key = SubscriptionKey(
            channel: "dep",
            src: "motis",
            id: stopId,
            extra: "\(n)|\(radius ?? 0)"
        )
        var payload: [String: Any] = [
            "action": "sub_dep",
            "src": "motis",
            "stopId": stopId,
            "n": n,
        ]
        if let radius { payload["radius"] = radius }
        return stream(key: key, subscribePayload: payload, as: StopTimes.self)
    }

    func trip(tripId: String) -> AsyncStream<Itinerary> {
        let key = SubscriptionKey(channel: "trip", src: "motis", id: tripId, extra: "")
        let payload: [String: Any] = [
            "action": "sub_trip",
            "src": "motis",
            "tripId": tripId,
        ]
        return stream(key: key, subscribePayload: payload, as: Itinerary.self)
    }

    func disruptions() -> AsyncStream<[Disruption]> {
        let key = SubscriptionKey(channel: "dis", src: "shared", id: "global", extra: "")
        return stream(key: key, subscribePayload: ["action": "sub_dis"], as: [Disruption].self)
    }

    // MARK: - Subscription plumbing

    private func stream<T: Decodable & Sendable>(
        key: SubscriptionKey,
        subscribePayload: [String: Any],
        as type: T.Type
    ) -> AsyncStream<T> {
        let subscribeMessage = Self.encode(subscribePayload)
        let subscriberId = UUID()

        return AsyncStream { continuation in
            let subscriber = Subscriber(
                deliver: { data in
                    if let value = try? Self.decoder.decode(T.self, from: data) {
                        continuation.yield(value)
                    } else {
                        print("relay: failed to decode \(key.channel) payload")
                    }
                },
                subscribeMessage: subscribeMessage
            )

            continuation.onTermination = { _ in
                Task { await self.removeSubscriber(subscriberId, for: key) }
            }

            Task { await self.addSubscriber(subscriber, id: subscriberId, for: key) }
        }
    }

    private func addSubscriber(_ subscriber: Subscriber, id: UUID, for key: SubscriptionKey) {
        let isNewKey = subscribers[key] == nil
        subscribers[key, default: [:]][id] = subscriber

        connectIfNeeded()
        // The relay dedups subs per key server-side; re-sending for an existing
        // key just triggers a snapshot replay for everyone, which is fine.
        if isConnected || isNewKey {
            send(subscriber.subscribeMessage)
        }
    }

    private func removeSubscriber(_ id: UUID, for key: SubscriptionKey) {
        guard var keySubscribers = subscribers[key] else { return }
        keySubscribers.removeValue(forKey: id)

        if keySubscribers.isEmpty {
            subscribers.removeValue(forKey: key)
            let action: [String: Any]
            switch key.channel {
            case "dep":
                action = ["action": "unsub_dep", "src": key.src, "stopId": key.id]
            case "trip":
                action = ["action": "unsub_trip", "src": key.src, "tripId": key.id]
            default:
                action = ["action": "unsub_dis"]
            }
            send(Self.encode(action))
            if subscribers.isEmpty {
                disconnect()
            }
        } else {
            subscribers[key] = keySubscribers
        }
    }

    // MARK: - Connection management

    private func connectIfNeeded() {
        guard task == nil, !suspendedForBackground else { return }

        let webSocketTask = URLSession.shared.webSocketTask(with: Self.url)
        task = webSocketTask
        webSocketTask.resume()

        receiveLoop = Task { await self.runReceiveLoop(on: webSocketTask) }
        pingLoop = Task { await self.runPingLoop(on: webSocketTask) }
    }

    private func disconnect() {
        receiveLoop?.cancel()
        pingLoop?.cancel()
        receiveLoop = nil
        pingLoop = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
    }

    private func runReceiveLoop(on webSocketTask: URLSessionWebSocketTask) async {
        do {
            while !Task.isCancelled {
                let message = try await webSocketTask.receive()
                if !isConnected {
                    // First frame confirms the connection is live.
                    markConnected()
                }
                handle(message)
            }
        } catch {
            guard task === webSocketTask else { return }
            handleDisconnect()
        }
    }

    private func runPingLoop(on webSocketTask: URLSessionWebSocketTask) async {
        // The first successful pong is what flips isConnected when the relay
        // has nothing to push right away. After that, pings are only a liveness
        // check: the server heartbeats every 30s (keeping NAT mappings alive),
        // so a slow cadence here halves radio wakeups without losing detection.
        while !Task.isCancelled, task === webSocketTask {
            let connected: Bool = await withCheckedContinuation { continuation in
                webSocketTask.sendPing { error in
                    continuation.resume(returning: error == nil)
                }
            }
            guard task === webSocketTask else { return }
            if connected {
                markConnected()
            }
            try? await Task.sleep(for: .seconds(isConnected ? 45 : 5))
        }
    }

    private func markConnected() {
        guard !isConnected else { return }
        isConnected = true
        reconnectAttempt = 0
        resubscribeAll()
    }

    private func handleDisconnect() {
        disconnect()
        guard !subscribers.isEmpty, !suspendedForBackground else { return }

        reconnectAttempt += 1
        let delay = min(30.0, pow(2.0, Double(reconnectAttempt))) * .random(in: 0.8...1.2)
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await self.reconnectIfNeeded()
        }
    }

    private func reconnectIfNeeded() {
        guard task == nil, !subscribers.isEmpty, !suspendedForBackground else { return }
        connectIfNeeded()
    }

    private func resubscribeAll() {
        for keySubscribers in subscribers.values {
            if let message = keySubscribers.values.first?.subscribeMessage {
                send(message)
            }
        }
    }

    private func send(_ message: String) {
        task?.send(.string(message)) { _ in }
    }

    // MARK: - Incoming messages

    private struct Envelope: Decodable {
        let ch: String
        let src: String?
        let stopId: String?
        let tripId: String?
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let raw): data = raw
        @unknown default: return
        }

        guard
            let envelope = try? Self.decoder.decode(Envelope.self, from: data),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let payload = object["data"],
            let payloadData = try? JSONSerialization.data(withJSONObject: payload)
        else { return }

        let key = SubscriptionKey(
            channel: envelope.ch,
            src: envelope.src ?? "shared",
            id: envelope.stopId ?? envelope.tripId ?? "global",
            extra: ""
        )

        for (candidate, keySubscribers) in subscribers {
            // dep keys carry n/radius in `extra`, which the server doesn't echo
            // back; match on channel/src/id only.
            guard candidate.channel == key.channel,
                  candidate.src == key.src,
                  candidate.id == key.id else { continue }
            for subscriber in keySubscribers.values {
                subscriber.deliver(payloadData)
            }
        }
    }

    // MARK: - App lifecycle

    private func observeLifecycle() async {
        let center = NotificationCenter.default
        Task {
            for await _ in center.notifications(named: UIApplication.didEnterBackgroundNotification) {
                await self.enterBackground()
            }
        }
        Task {
            for await _ in center.notifications(named: UIApplication.willEnterForegroundNotification) {
                await self.enterForeground()
            }
        }
    }

    private func enterBackground() {
        suspendedForBackground = true
        disconnect()
    }

    private func enterForeground() {
        suspendedForBackground = false
        reconnectAttempt = 0
        if !subscribers.isEmpty {
            connectIfNeeded()
        }
    }

    private static func encode(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
