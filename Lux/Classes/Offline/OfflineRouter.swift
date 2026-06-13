import Foundation
import LuxCom

public protocol OfflineDataProvider: Sendable {
    func departures(stopId: String, time: Date, arriveBy: Bool, both: Bool, numberOfEvents: Int) async throws -> StopTimes
    func geocode(text: String, type: LocationType?, place: (Double, Double)?) async throws -> [SearchResult]
    func reverseGeocode(place: (Double, Double), type: LocationType?) async throws -> [SearchResult]
    func trip(tripId: String) async throws -> Itinerary
}

public enum OfflineError: LocalizedError {
    case tripPlanningUnavailable
    case notAvailableOffline

    public var errorDescription: String? {
        switch self {
        case .tripPlanningUnavailable:
            return String(localized: "La planification d’itinéraire est indisponible hors ligne.")
        case .notAvailableOffline:
            return String(localized: "Cette information est indisponible hors ligne.")
        }
    }
}

public final class OfflineRouter: @unchecked Sendable {
    public static let shared = OfflineRouter()

    private let lock = NSLock()
    private var provider: OfflineDataProvider?
    private var offlineActive = false

    private init() {}

    public func register(_ provider: OfflineDataProvider?) {
        lock.lock(); defer { lock.unlock() }
        self.provider = provider
    }

    public func setOfflineActive(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        offlineActive = value
    }

    public var active: OfflineDataProvider? {
        lock.lock(); defer { lock.unlock() }
        return offlineActive ? provider : nil
    }

    public var isOfflineActive: Bool { active != nil }
}
