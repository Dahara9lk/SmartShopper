//
//  LocationService.swift
//  SmartShopper

//  Core Location wrapper: asks for permission and publishes the user's location.

import Foundation
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isPreciseLocation = true
    @Published private(set) var lastLocation: CLLocation?

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 25   // only update after moving 25 m (saves battery)
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

// "Allowed While Using", "Always", "Denied"...
    var statusText: String {
        switch authorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While Using"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        default: return "Not Set"
        }
    }

// Shows the iOS "Allow location?" popup.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

// Needed for store alerts while the app is closed.
    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        guard isAuthorized else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

// Waits (up to ~5 seconds) for the first GPS fix.
    func waitForLocation() async -> CLLocation? {
        if let lastLocation { return lastLocation }
        startUpdating()
        for _ in 0..<20 {
            if let lastLocation { return lastLocation }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return lastLocation
    }

//CLLocationManagerDelegate
    
// Delegate calls are "nonisolated", so we hop back to the main actor to update the UI values.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let precise = manager.accuracyAuthorization == .fullAccuracy
        Task { @MainActor in
            self.authorizationStatus = status
            self.isPreciseLocation = precise
            if self.isAuthorized {
                self.startUpdating()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = latest
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
// Errors such as "location unknown" are temporary - Core Location keeps trying.
    }
}
