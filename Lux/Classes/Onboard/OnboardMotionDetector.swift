//
//  OnboardMotionDetector.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import CoreMotion
import CoreLocation

@MainActor
final class OnboardMotionDetector {
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private var pedometerSpeed: (speed: Double, at: Date)?
    private var lastVehicleActivity: Date = .distantPast
    private var lastFootActivity: Date = .distantPast
    private var recentSpeeds: [(speed: CLLocationSpeed, at: Date)] = []

    func start() {
        if CMPedometer.isPaceAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let pace = data?.currentPace?.doubleValue ?? data?.averageActivePace?.doubleValue, pace > 0 else { return }
                let speed = 1 / pace
                guard speed > 0.3, speed < 3.5 else { return }
                Task { @MainActor in
                    guard let self else { return }
                    let smoothed = self.pedometerSpeed.map { $0.speed * 0.7 + speed * 0.3 } ?? speed
                    self.pedometerSpeed = (smoothed, Date())
                }
            }
        }
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity, activity.confidence != .low else { return }
            if activity.automotive {
                self.lastVehicleActivity = Date()
            } else if activity.walking || activity.running || activity.stationary {
                self.lastFootActivity = Date()
            }
        }
    }

    func stop() {
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
    }

    var walkingSpeed: Double? {
        guard let pedometerSpeed, Date().timeIntervalSince(pedometerSpeed.at) < 20 else { return nil }
        return pedometerSpeed.speed
    }

    func record(_ location: CLLocation) {
        guard location.speed >= 0, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100 else { return }
        recentSpeeds.append((location.speed, location.timestamp))
        recentSpeeds.removeAll { location.timestamp.timeIntervalSince($0.at) > 30 }
    }

    var isInVehicle: Bool {
        let now = Date()
        let motionSaysVehicle = now.timeIntervalSince(lastVehicleActivity) < 30 && lastVehicleActivity >= lastFootActivity
        let fast = recentSpeeds.filter { now.timeIntervalSince($0.at) < 20 }
        let speedSaysVehicle = fast.count >= 3 && fast.allSatisfy { $0.speed > 7 }
        return motionSaysVehicle || speedSaysVehicle
    }
}
