//
//  LocationManager.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//
//  https://needone.app/get-location-coordinates-using-cllocationmanager-in-swift/

import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var permissionDenied = false
    @Published var errorMessage: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.distanceFilter = 10.0
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        
        self.authorizationStatus = locationManager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.heading = newHeading
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.location = locations.last
            self.errorMessage = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.permissionDenied = false
                self.locationManager.startUpdatingLocation()
                self.locationManager.startUpdatingHeading()
            case .denied, .restricted:
                self.permissionDenied = true
                self.errorMessage = "Location access was denied. Please enable it in Settings to use the app properly."
            case .notDetermined:
                self.permissionDenied = false
                self.errorMessage = "Waiting for location permission..."
            @unknown default:
                self.permissionDenied = true
                self.errorMessage = "Unknown authorization status"
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.permissionDenied = true
                    self.errorMessage = "Location access was denied. Please enable it in Settings."
                case .locationUnknown:
                    self.errorMessage = "Unable to determine your location. Please try again later."
                default:
                    self.errorMessage = "Error retrieving location: \(error.localizedDescription)"
                }
            } else {
                self.errorMessage = "Error retrieving location: \(error.localizedDescription)"
            }
        }
    }
    
    func requestLoc() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
}
