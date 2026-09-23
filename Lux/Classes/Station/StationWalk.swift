//
//  StationWalk.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import Foundation
import LuxCom

/// A walk inside a railway station: changing trains, going from the street to a
/// platform, or from a platform out to the street.
struct StationWalk: Equatable {
    enum Kind: Equatable { case transfer, entering, leaving }

    let kind: Kind
    let uic: Int
    /// Track the rider arrives on (transfer, leaving).
    let fromTrack: String?
    /// Track the rider departs from (transfer, entering).
    let toTrack: String?

    init?(legs: [Leg], index: Int) {
        guard legs.indices.contains(index), !legs[index].isTransit else { return nil }
        let arrival = index > 0 && legs[index - 1].mode.isMainlineRail ? legs[index - 1].to : nil
        let departure = index + 1 < legs.count && legs[index + 1].mode.isMainlineRail ? legs[index + 1].from : nil
        let arrivalStation = StationLayout.uic(fromStopId: arrival?.stopId)
        let departureStation = StationLayout.uic(fromStopId: departure?.stopId)

        if let arrivalStation, arrivalStation == departureStation {
            kind = .transfer
            uic = arrivalStation
        } else if let departureStation {
            kind = .entering
            uic = departureStation
        } else if let arrivalStation {
            kind = .leaving
            uic = arrivalStation
        } else {
            return nil
        }
        fromTrack = kind == .entering ? nil : arrival.flatMap(Self.track)
        toTrack = kind == .leaving ? nil : departure.flatMap(Self.track)
    }

    private static func track(of place: Place) -> String? {
        let track = (place.track ?? place.scheduledTrack)?.trimmingCharacters(in: .whitespaces)
        return track?.isEmpty == false ? track : nil
    }

    /// "la voie 7" / "le quai A", to slot into a sentence.
    static func trackPhrase(_ track: String) -> String {
        Int(track) != nil ? String(localized: "la voie \(track)") : String(localized: "le quai \(track)")
    }
}
