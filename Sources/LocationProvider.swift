import Foundation
import CoreLocation

/// Single source of location for the whole app.
/// Wraps CLLocationManager: when simulation is on, `effectiveLocation` returns the
/// simulated coordinate instead of the real GPS fix. Real GPS keeps updating underneath.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published private(set) var realLocation: CLLocation?
    @Published private(set) var simulatedLocation: CLLocation?
    @Published private(set) var isSimulating = false
    @Published private(set) var effectiveLocation: CLLocation?
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorization = manager.authorizationStatus
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func simulate(_ coordinate: CLLocationCoordinate2D) {
        simulatedLocation = CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        isSimulating = true
        publish()
    }

    func useRealLocation() {
        isSimulating = false
        publish()
    }

    private func publish() {
        effectiveLocation = isSimulating ? simulatedLocation : realLocation
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        realLocation = locations.last
        publish()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the last known location; nothing to do.
    }
}
