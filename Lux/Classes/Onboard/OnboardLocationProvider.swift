//
//  OnboardLocationProvider.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import CoreLocation
import UIKit

@MainActor
final class OnboardLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var backgroundSession: AnyObject?

    var onLocation: ((CLLocation) -> Void)?
    var onHeading: ((CLHeading) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .otherNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.headingFilter = 3
        manager.pausesLocationUpdatesAutomatically = false
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private var isRunning = false

    @objc private func didEnterBackground() {
        manager.stopUpdatingHeading()
    }

    @objc private func willEnterForeground() {
        guard isRunning else { return }
        manager.startUpdatingHeading()
    }

    var isSaving = false {
        didSet {
            guard isSaving != oldValue else { return }
            manager.desiredAccuracy = isSaving ? kCLLocationAccuracyNearestTenMeters : kCLLocationAccuracyBestForNavigation
        }
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        if #available(iOS 17.0, *) {
            (backgroundSession as? CLBackgroundActivitySession)?.invalidate()
            backgroundSession = CLBackgroundActivitySession()
        }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        isRunning = true
        if UIApplication.shared.applicationState != .background {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        isRunning = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manager.allowsBackgroundLocationUpdates = false
        if #available(iOS 17.0, *) {
            (backgroundSession as? CLBackgroundActivitySession)?.invalidate()
        }
        backgroundSession = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.onLocation?(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in self.onHeading?(newHeading) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("onboard location error: \(error.localizedDescription)")
    }
}
