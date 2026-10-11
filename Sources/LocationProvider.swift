
import Foundation
import CoreLocation
import Combine

/// Central location source for this app.
///
/// When simulation is active, effectiveLocation uses the selected
/// simulated coordinate, regardless of incoming real GPS updates.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published private(set) var realLocation: CLLocation?
    @Published private(set) var simulatedLocation: CLLocation?
    @Published private(set) var isSimulating = false
    @Published private(set) var effectiveLocation: CLLocation?
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationError: String?

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest

        authorization = manager.authorizationStatus

        // Request permission before relying on GPS updates.
        manager.requestWhenInUseAuthorization()

        if authorization == .authorizedWhenInUse ||
           authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    // MARK: - Simulation

    /// Activate or update the simulated location.
    func simulate(_ coordinate: CLLocationCoordinate2D) {
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            locationError = "Invalid coordinates."
            return
        }

        let location = CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )

        simulatedLocation = location
        isSimulating = true
        locationError = nil

        publish()
    }

    /// Stop simulation and use the latest real GPS location.
    func useRealLocation() {
        isSimulating = false
        locationError = nil
        publish()
    }

    // MARK: - Location Publishing

    private func publish() {
        effectiveLocation = isSimulating
            ? simulatedLocation
            : realLocation
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }

        realLocation = location
        locationError = nil

        // Real GPS updates won't replace the simulated effective location.
        publish()
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        authorization = manager.authorizationStatus

        switch authorization {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()

        case .denied, .restricted:
            manager.stopUpdatingLocation()
            locationError = "Location access is denied or restricted."

        case .notDetermined:
            break

        @unknown default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        locationError = error.localizedDescription
        print("Location error: \(error.localizedDescription)")
    }
}
