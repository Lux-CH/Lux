//
//  RelayClient.swift
//  Lux
//
//  Created by Constantin Clerc on 18.07.2026.
//

import Foundation
import UIKit
import LuxCom

actor RelayClient {
    static let shared = RelayClient()

    private static let url = URL(string: "wss://lux.cclerc.ch/ws")!

    private struct SubscriptionKey: Hashable {
        let channel: String
        let src: String
        let id: String
        let extra: String
    }

    private struct Subscriber {
        let deliver: (Data) -> Void
        let subscribeMessage: String
        let unsubscribeMessage: String
    }

    private var task: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var pingLoop: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var suspendedForBackground = false
    private var subscribers: [SubscriptionKey: [UUID: Subscriber]] = [:]
    private var idleDisconnectTask: Task<Void, Never>?

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
        var unsubscribePayload: [String: Any] = [
            "action": "unsub_dep",
            "src": "motis",
            "stopId": stopId,
            "n": n,
        ]
        if let radius {
            payload["radius"] = radius
            unsubscribePayload["radius"] = radius
        }
        return stream(
            key: key,
            subscribePayload: payload,
            unsubscribePayload: unsubscribePayload,
            as: StopTimes.self
        )
    }

    func trip(tripId: String) -> AsyncStream<Itinerary> {
        let key = SubscriptionKey(channel: "trip", src: "motis", id: tripId, extra: "")
        let payload: [String: Any] = [
            "action": "sub_trip",
            "src": "motis",
            "tripId": tripId,
        ]
        return stream(
            key: key,
            subscribePayload: payload,
            unsubscribePayload: ["action": "unsub_trip", "src": "motis", "tripId": tripId],
            as: Itinerary.self
        )
    }

    func disruptions() -> AsyncStream<[Disruption]> {
        let key = SubscriptionKey(channel: "dis", src: "shared", id: "global", extra: "")
        return stream(
            key: key,
            subscribePayload: ["action": "sub_dis"],
            unsubscribePayload: ["action": "unsub_dis"],
            as: [Disruption].self
        )
    }

    // MARK: - Subscription plumbing

    private func stream<T: Decodable & Sendable>(
        key: SubscriptionKey,
        subscribePayload: [String: Any],
        unsubscribePayload: [String: Any],
        as type: T.Type
    ) -> AsyncStream<T> {
        let subscribeMessage = Self.encode(subscribePayload)
        let unsubscribeMessage = Self.encode(unsubscribePayload)
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
                subscribeMessage: subscribeMessage,
                unsubscribeMessage: unsubscribeMessage
            )

            continuation.onTermination = { _ in
                Task { await self.removeSubscriber(subscriberId, for: key) }
            }

            Task { self.addSubscriber(subscriber, id: subscriberId, for: key) }
        }
    }

    private func addSubscriber(_ subscriber: Subscriber, id: UUID, for key: SubscriptionKey) {
        let isNewKey = subscribers[key] == nil
        subscribers[key, default: [:]][id] = subscriber

        idleDisconnectTask?.cancel()
        idleDisconnectTask = nil
        connectIfNeeded()
        if isConnected || isNewKey {
            send(subscriber.subscribeMessage)
        }
    }

    private func removeSubscriber(_ id: UUID, for key: SubscriptionKey) {
        guard var keySubscribers = subscribers[key] else { return }
        guard let subscriber = keySubscribers.removeValue(forKey: id) else { return }

        if keySubscribers.isEmpty {
            subscribers.removeValue(forKey: key)
            send(subscriber.unsubscribeMessage)
            scheduleIdleDisconnect()
        } else {
            subscribers[key] = keySubscribers
        }
    }

    private func scheduleIdleDisconnect() {
        idleDisconnectTask?.cancel()
        idleDisconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            await self.disconnectIfIdle()
        }
    }

    private func disconnectIfIdle() {
        idleDisconnectTask = nil
        if subscribers.isEmpty {
            disconnect()
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
            self.reconnectIfNeeded()
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
        let n: Int?
        let radius: Int?
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

        let channel = envelope.ch
        let src = envelope.src ?? "shared"
        let id = envelope.stopId ?? envelope.tripId ?? "global"
        let extra = envelope.n.map { "\($0)|\(envelope.radius ?? 0)" }

        for (candidate, keySubscribers) in subscribers {
            guard candidate.channel == channel,
                  candidate.src == src,
                  candidate.id == id else { continue }
            if let extra, candidate.extra != extra { continue }
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
                self.enterBackground()
            }
        }
        Task {
            for await _ in center.notifications(named: UIApplication.willEnterForegroundNotification) {
                self.enterForeground()
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
