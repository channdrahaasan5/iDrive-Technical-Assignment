import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    private let manager = CLLocationManager()

    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5 // meters
        // do not request permission automatically here; request from UI when needed
    }

    func requestWhenInUsePermission() {
        manager.requestWhenInUseAuthorization()
    }

    // Request Always permission, following the recommended flow:
    // - If notDetermined, first request WhenInUse and then request Always after grant.
    private var requestAlwaysAfterWhenInUse: Bool = false
    func requestAlwaysPermission() {
        let s = manager.authorizationStatus
        if s == .notDetermined {
            requestAlwaysAfterWhenInUse = true
            manager.requestWhenInUseAuthorization()
        } else if s == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        } else {
            // denied/restricted -> the app should show an alert to open Settings
            print("Cannot request Always: status=", s.rawValue)
        }
    }

    func startUpdates() {
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async { self.lastLocation = loc }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Could publish errors if needed
        print("Location failure:", error)
    }
}

