//
//  OnboardLiveShare.swift
//  Lux
//
//  Created by Constantin Clerc on 14.10.2026.
//

import SwiftUI
import CoreLocation
import CryptoKit
import LuxCom

struct LiveShareState: Decodable, Sendable, Equatable {
    let status: String
    let arrived: Bool?
    let itin: String?
    let phase: String?
    let leg: Int?
    let next: Int?
    let lat: Double?
    let lon: Double?
    let acc: Double?
    let ts: Double?
    let eta: Double?
    let delay: Int?
    let dest: String?
    let times: [[Double]?]?
    let viewers: Int?
    let endedAt: Double?

    var isLive: Bool { status == "live" }
    var hasArrived: Bool { status == "ended" && arrived == true }
    var fixDate: Date? { ts.map { Date(timeIntervalSince1970: $0 / 1000) } }
    var etaDate: Date? { eta.map { Date(timeIntervalSince1970: $0 / 1000) } }
    var endedDate: Date? { endedAt.map { Date(timeIntervalSince1970: $0 / 1000) } }

    var onboardPhase: OnboardPhase? {
        switch phase {
        case "walking": .walking
        case "waiting": .waiting
        case "riding": .riding
        case "arrived": .arrived
        default: nil
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        guard isLive, let lat, let lon, let fixDate, Date().timeIntervalSince(fixDate) < 600 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func isStale(at date: Date = Date()) -> Bool {
        guard let fixDate else { return false }
        return date.timeIntervalSince(fixDate) > 120
    }

    func legTimes(_ index: Int) -> (start: Date, end: Date)? {
        guard let times, times.indices.contains(index), let pair = times[index], pair.count == 2 else { return nil }
        return (Date(timeIntervalSince1970: pair[0] / 1000), Date(timeIntervalSince1970: pair[1] / 1000))
    }
}

struct LiveShareLink: Equatable {
    let shareId: String
    let itineraryId: String
}

struct LiveShareUpdate: Encodable, Sendable {
    let action = "live_pub"
    let token: String
    let itin: String
    let phase: String
    let leg: Int
    let next: Int
    let lat: Double?
    let lon: Double?
    let acc: Double?
    let ts: Int?
    let eta: Int
    let delay: Int?
    let dest: String
    let times: [[Int]]
}

@MainActor
@Observable
final class OnboardLiveShare {
    enum Status: Equatable {
        case idle
        case starting
        case active
        case ended
    }

    private(set) var status: Status = .idle
    private(set) var url: URL?
    private(set) var viewers = 0

    @ObservationIgnored private var token = ""
    @ObservationIgnored private var shareId = ""
    @ObservationIgnored private var itineraryId: String?
    @ObservationIgnored private var plannedArrival: Date?
    @ObservationIgnored private var uploadedLegsKey = ""
    @ObservationIgnored private var nextUploadAt: Date = .distantPast
    @ObservationIgnored private var uploadTask: Task<Void, Never>?
    @ObservationIgnored private var viewersTask: Task<Void, Never>?
    @ObservationIgnored private var isConfirmed = false
    @ObservationIgnored private var lastCheckAt: Date = .distantPast
    @ObservationIgnored private var lastSentAt: Date = .distantPast
    @ObservationIgnored private var lastPublishedKey = ""
    @ObservationIgnored private var lastSignature = ""

    static let itineraryLifetimeHours = 12

    var isSharing: Bool { status == .starting || status == .active }

    func start(for session: OnboardSession) async -> URL? {
        if status == .active { return url }
        guard status != .starting else { return nil }
        status = .starting
        token = Self.makeToken()
        shareId = Self.shareId(for: token)
        isConfirmed = false
        viewers = 0
        let itinerary = session.sharedItinerary
        let result = await ItinerarySharer().uploadItinerary(itinerary, expiresInHours: Self.itineraryLifetimeHours)
        guard status == .starting else { return nil }
        guard case .success(let identifier) = result, Self.isValidItineraryId(identifier) else {
            status = .idle
            return nil
        }
        itineraryId = identifier
        plannedArrival = itinerary.endTime
        uploadedLegsKey = Self.legsKey(itinerary.legs)
        let link = URL(string: "https://lux.cclerc.ch/share.html#\(identifier)~\(shareId)")
        url = link
        status = .active
        observeViewers()
        update(from: session, force: true)
        return link
    }

    func update(from session: OnboardSession, force: Bool = false) {
        guard status == .active, let itineraryId else { return }
        let now = Date()
        let key = "\(session.phase)|\(session.legIndex)|\(session.nextStopIndex)"
        let interval: TimeInterval = !isConfirmed ? 2 : (viewers > 0 ? 3 : 15)
        let sinceSent = now.timeIntervalSince(lastSentAt)
        guard force || now.timeIntervalSince(lastCheckAt) >= interval || (key != lastPublishedKey && sinceSent >= 1.2) else { return }
        lastCheckAt = now
        guard Self.legsKey(session.legs) == uploadedLegsKey else {
            reupload(session)
            return
        }

        let location = session.userLocation.flatMap { location in
            now.timeIntervalSince(location.timestamp) < 120 && location.horizontalAccuracy >= 0 ? location : nil
        }
        let eta = Int(session.arrivalDate.timeIntervalSince1970 * 1000)
        let signature = "\(key)|\(location?.timestamp.timeIntervalSince1970 ?? 0)|\(eta)"
        guard force || !isConfirmed || signature != lastSignature || sinceSent >= 60 else { return }
        lastSentAt = now
        lastPublishedKey = key
        lastSignature = signature

        let delay = plannedArrival.map { Int(session.arrivalDate.timeIntervalSince($0)) }
        let update = LiveShareUpdate(
            token: token,
            itin: itineraryId,
            phase: Self.phaseName(session.phase),
            leg: session.legIndex,
            next: session.nextStopIndex,
            lat: location?.coordinate.latitude,
            lon: location?.coordinate.longitude,
            acc: location?.horizontalAccuracy,
            ts: location.map { Int($0.timestamp.timeIntervalSince1970 * 1000) },
            eta: eta,
            delay: delay,
            dest: session.destinationName,
            times: session.legs.map { [Int($0.startTime.timeIntervalSince1970 * 1000), Int($0.endTime.timeIntervalSince1970 * 1000)] }
        )
        session.enqueueRelay { await RelayClient.shared.publishLiveShare(update) }
    }

    func finish(arrived: Bool, session: OnboardSession) {
        guard isSharing else { return }
        if arrived { update(from: session, force: true) }
        uploadTask?.cancel()
        uploadTask = nil
        let wasActive = status == .active
        status = .ended
        url = nil
        viewers = 0
        let token = token
        let viewersTask = viewersTask
        self.viewersTask = nil
        session.enqueueRelay {
            if wasActive { await RelayClient.shared.endLiveShare(token: token, arrived: arrived) }
            viewersTask?.cancel()
        }
    }

    private func observeViewers() {
        viewersTask?.cancel()
        let id = shareId
        viewersTask = Task { [weak self] in
            for await state in await RelayClient.shared.liveShare(id: id) {
                guard let self, !Task.isCancelled, self.status == .active else { return }
                self.isConfirmed = true
                if let count = state.viewers, count != self.viewers {
                    withAnimation(.snappy) { self.viewers = count }
                }
            }
        }
    }

    private func reupload(_ session: OnboardSession) {
        guard uploadTask == nil, Date() >= nextUploadAt else { return }
        let itinerary = session.sharedItinerary
        let key = Self.legsKey(itinerary.legs)
        uploadTask = Task { [weak self] in
            let result = await ItinerarySharer().uploadItinerary(itinerary, expiresInHours: Self.itineraryLifetimeHours)
            guard let self, !Task.isCancelled else { return }
            self.uploadTask = nil
            guard self.status == .active else { return }
            if case .success(let identifier) = result, Self.isValidItineraryId(identifier) {
                self.itineraryId = identifier
                self.plannedArrival = itinerary.endTime
                self.uploadedLegsKey = key
                self.lastSignature = ""
                self.update(from: session, force: true)
            } else {
                self.nextUploadAt = Date().addingTimeInterval(30)
            }
        }
    }

    private static func phaseName(_ phase: OnboardPhase) -> String {
        switch phase {
        case .walking: "walking"
        case .waiting: "waiting"
        case .riding: "riding"
        case .arrived: "arrived"
        }
    }

    private static func legsKey(_ legs: [Leg]) -> String {
        legs.map { "\($0.mode.rawValue)|\($0.tripId ?? "")|\($0.from.stopId ?? "")|\($0.to.stopId ?? "")" }.joined(separator: ";")
    }

    private static func isValidItineraryId(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }

    private static func makeToken() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return base64URL(Data(bytes))
    }

    static func shareId(for token: String) -> String {
        String(base64URL(Data(SHA256.hash(data: Data("lux-live:\(token)".utf8)))).prefix(22))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension OnboardSession {
    var sharedItinerary: Itinerary {
        let start = legs.first?.startTime ?? Date()
        let end = legs.last?.endTime ?? start
        return Itinerary(
            duration: max(1, Int(end.timeIntervalSince(start))),
            startTime: start,
            endTime: end,
            transfers: max(0, legs.filter(\.isTransit).count - 1),
            legs: legs
        )
    }
}

@MainActor
@Observable
final class LiveShareFollower {
    let shareId: String
    private(set) var state: LiveShareState?
    private(set) var waitedOut = false

    @ObservationIgnored var onItineraryChange: ((Itinerary) -> Void)?
    @ObservationIgnored private var itineraryId: String
    @ObservationIgnored private var loadingItineraryId: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    init(shareId: String, itineraryId: String) {
        self.shareId = shareId
        self.itineraryId = itineraryId
    }

    nonisolated static func isValidShareId(_ id: String) -> Bool {
        id.count == 22 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }

    var coordinate: CLLocationCoordinate2D? { state?.coordinate }

    func start() {
        guard task == nil, state?.isLive != false else { return }
        let id = shareId
        task = Task { [weak self] in
            for await state in await RelayClient.shared.liveShare(id: id) {
                guard let self, !Task.isCancelled else { return }
                self.apply(state)
                if !state.isLive { break }
            }
        }
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, !Task.isCancelled, self.state == nil else { return }
            withAnimation(.snappy) { self.waitedOut = true }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    private func apply(_ state: LiveShareState) {
        withAnimation(.easeInOut(duration: 0.9)) { self.state = state }
        if waitedOut { waitedOut = false }
        guard state.isLive, let next = state.itin, next != itineraryId, next != loadingItineraryId else { return }
        loadingItineraryId = next
        Task { [weak self] in
            let result = await ItinerarySharer().downloadItinerary(next)
            guard let self, self.loadingItineraryId == next else { return }
            self.loadingItineraryId = nil
            if case .success(let itinerary) = result {
                self.itineraryId = next
                self.onItineraryChange?(itinerary)
            }
        }
    }
}
