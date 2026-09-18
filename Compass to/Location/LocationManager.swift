import Foundation
import CoreLocation
import Observation
import UIKit

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    var userLocation: CLLocation?
    var heading: Double = 0
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Set once from Compass_toApp — lets a location update (foreground or a
    /// background significant-change wake) drive person-location sync directly,
    /// without depending on any SwiftUI view being on screen to notice.
    var syncCoordinator: LocationSyncCoordinator?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 1
        manager.requestAlwaysAuthorization()
        manager.startUpdatingHeading()

        // CLLocationManager reports headings relative to manager.headingOrientation,
        // which defaults to .portrait and never updates itself. Without tracking the
        // device's actual orientation here, the heading (and every bearing derived
        // from it) ends up off by 90/180/270° depending on how the phone is held.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        updateHeadingOrientation(for: UIDevice.current.orientation)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    @objc private func deviceOrientationDidChange() {
        updateHeadingOrientation(for: UIDevice.current.orientation)
    }

    /// Face-up, face-down, and unknown have no matching CLDeviceOrientation reading
    /// to switch to, so those are ignored and the last known orientation stands —
    /// that's also what happens naturally when the phone is held flat to read it.
    private func updateHeadingOrientation(for orientation: UIDeviceOrientation) {
        guard let clOrientation = CLDeviceOrientation(rawValue: Int32(orientation.rawValue)),
              clOrientation != .faceUp, clOrientation != .faceDown, clOrientation != .unknown else { return }
        manager.headingOrientation = clOrientation
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
        // Significant-change monitoring needs "Always" — it's what lets location
        // sharing keep working in the background without the app being open.
        if authorizationStatus == .authorizedAlways {
            manager.startMonitoringSignificantLocationChanges()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        userLocation = newLocation
        Task { await syncCoordinator?.sync(location: newLocation) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
