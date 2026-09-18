import Foundation
import SwiftData
import CoreLocation
import WidgetKit

/// Runs the "publish my location to peers, fetch theirs, refresh the widget
/// snapshot" work whenever a new location comes in — from LocationManager's
/// delegate callback, which fires the same way whether the update came from
/// continuous foreground tracking or a significant-location-change background
/// wake. That's what makes sharing work without both people having the app open.
@MainActor
final class LocationSyncCoordinator {
    private let modelContainer: ModelContainer
    private let identity: LocationIdentity
    private var lastSyncDate: Date?
    private let minSyncInterval: TimeInterval = 25

    init(modelContainer: ModelContainer, identity: LocationIdentity) {
        self.modelContainer = modelContainer
        self.identity = identity
    }

    func sync(location: CLLocation) async {
        if let last = lastSyncDate, Date().timeIntervalSince(last) < minSyncInterval {
            return
        }
        lastSyncDate = Date()

        let context = ModelContext(modelContainer)
        let items = (try? context.fetch(FetchDescriptor<TrackedItem>())) ?? []
        let service = LocationSharingService(identity: identity)
        // Toggled off from Settings → "Stop Sharing Location". Pairings stay intact
        // and we still fetch peers' locations below — this only pauses publishing ours.
        let sharingEnabled = UserDefaults.standard.object(forKey: "locationSharingEnabled") as? Bool ?? true

        for person in items.filter({ $0.type == .person }) {
            guard let peerCode = person.sharingCode else { continue }

            // Retry the one-time key fetch if it never succeeded (e.g. the
            // server wasn't reachable yet when this person was added).
            if person.peerPublicKey == nil {
                person.peerPublicKey = try? await service.fetchPublicKey(for: peerCode)
            }
            guard let peerKey = person.peerPublicKey else { continue }

            if sharingEnabled {
                try? await service.publishLocation(
                    location.coordinate,
                    forPeerCode: peerCode,
                    peerPublicKey: peerKey
                )
            }

            if let coordinate = try? await service.fetchLocation(ownerCode: peerCode, ownerPublicKey: peerKey) {
                person.latitude = coordinate.latitude
                person.longitude = coordinate.longitude
                person.lastUpdated = Date()
            }
        }

        try? context.save()

        WidgetDataBridge.write(
            items: items,
            ownLatitude: location.coordinate.latitude,
            ownLongitude: location.coordinate.longitude,
            ownLocationTimestamp: location.timestamp
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
}
