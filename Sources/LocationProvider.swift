
import Foundation
import CoreLocation
import Combine

/// Central location source for the entire app.
/// All location-dependent features should read `effectiveLocation`.
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

    /// Enable or update the simulated location.
    func simulate(_ coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )

        simulatedLocation = location
        isSimulating = true
        publish()
    }

    /// Return to using the device's real location.
    func useRealLocation() {
        isSimulating = false
        publish()
    }

    private func publish() {
        effectiveLocation = isSimulating
            ? simulatedLocation
            : realLocation
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        realLocation = location
        publish()
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        authorization = manager.authorizationStatus

        if authorization == .authorizedWhenInUse ||
           authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        print("Location error: \(error.localizedDescription)")
    }
}
