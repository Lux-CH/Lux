//
//  LiveVehicleTrack.swift
//  Lux
//
//  Created by Constantin Clerc on 25.09.2026.
//

import CoreLocation

struct LiveVehicleTrack {
    let path: RoutePath
    private(set) var vehicle: RelayClient.CrowdVehicle
    private var reportedAlong: CLLocationDistance
    private var receivedAt: Date
    private var correction: CLLocationDistance = 0

    private static let maxProjection: TimeInterval = 20
    private static let settleTime: TimeInterval = 0.8
    private static let maxCorrection: CLLocationDistance = 300

    init?(path: RoutePath, vehicle: RelayClient.CrowdVehicle, receivedAt: Date, hint: CLLocationDistance? = nil) {
        guard !path.isEmpty, let projection = path.project(vehicle.coordinate, hint: hint) else { return nil }
        self.path = path
        self.vehicle = vehicle
        self.reportedAlong = projection.along
        self.receivedAt = receivedAt
    }

    mutating func update(with vehicle: RelayClient.CrowdVehicle, at date: Date) {
        guard let projection = path.project(vehicle.coordinate, hint: reportedAlong) else { return }
        let shown = along(at: date)
        self.vehicle = vehicle
        reportedAlong = projection.along
        receivedAt = date
        correction = 0
        let gap = shown - along(at: date)
        correction = abs(gap) < Self.maxCorrection ? gap : 0
    }

    func along(at date: Date, limit: CLLocationDistance? = nil) -> CLLocationDistance {
        let age = min(Self.maxProjection, max(0, date.timeIntervalSince(receivedAt)))
        var target = reportedAlong + max(0, vehicle.speed ?? 0) * age
        if let limit, reportedAlong <= limit {
            target = min(target, limit)
        }
        target = min(target, path.length)
        return target + correction * exp(-age / Self.settleTime)
    }

    func coordinate(at date: Date, limit: CLLocationDistance? = nil) -> CLLocationCoordinate2D? {
        path.coordinate(at: along(at: date, limit: limit))
    }
}
