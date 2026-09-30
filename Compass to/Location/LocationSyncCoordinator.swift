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
        // Throttled silently — this runs on every location update (often
        // multiple times a minute), so logging the routine skip would drown
        // out everything else.
        if let last = lastSyncDate, Date().timeIntervalSince(last) < minSyncInterval {
            return
        }
        lastSyncDate = Date()
        print("[App][LocationSync] sync() starting")

        // Must be the container's mainContext, not a fresh ModelContext(modelContainer):
        // @Query in the views reads from mainContext, and SwiftData doesn't merge
        // changes saved from a separate context instance back into it.
        let context = modelContainer.mainContext
        var items = (try? context.fetch(FetchDescriptor<TrackedItem>())) ?? []
        var people = items.filter { $0.type == .person }
        print("[App][LocationSync] fetched \(items.count) items, \(people.count) of type person")
        let service = LocationSharingService(identity: identity)
        // Toggled off from Settings → "Stop Sharing Location". Pairings stay intact
        // and we still fetch peers' locations below — this only pauses publishing ours.
        let sharingEnabled = UserDefaults.standard.object(forKey: "locationSharingEnabled") as? Bool ?? true

        // Auto-discovery: anyone actively sending *their* location to me shows up
        // here even if I never entered their code myself — that's what makes
        // adding someone a one-sided action instead of requiring both people to add
        // each other.
        do {
            let incoming = try await service.fetchIncomingShares()
            print("[App][LocationSync] fetchIncomingShares succeeded, \(incoming.count) incoming share(s)")
            for share in incoming
            where share.fromCode != identity.ownCode
                && !people.contains(where: { $0.sharingCode == share.fromCode }) {
                let name = share.name?.trimmingCharacters(in: .whitespaces)
                let newPerson = TrackedItem(
                    name: (name?.isEmpty == false ? name! : share.fromCode),
                    type: .person,
                    latitude: 0,
                    longitude: 0,
                    colorHex: nextItemColor(count: items.count + people.count)
                )
                newPerson.sharingCode = share.fromCode
                context.insert(newPerson)
                people.append(newPerson)
                items.append(newPerson)
                print("[App][LocationSync] auto-added person for incoming share from \(share.fromCode)")
            }
        } catch {
            print("[App][LocationSync] fetchIncomingShares failed: \(error)")
        }

        for person in people {
            guard let peerCode = person.sharingCode else {
                print("[App][LocationSync] person \(person.name) has no sharingCode, skipping")
                continue
            }

            // Retry the one-time key fetch if it never succeeded (e.g. the
            // server wasn't reachable yet when this person was added).
            if person.peerPublicKey == nil {
                do {
                    person.peerPublicKey = try await service.fetchPublicKey(for: peerCode)
                    print("[App][LocationSync] fetchPublicKey succeeded for \(peerCode)")
                } catch {
                    print("[App][LocationSync] fetchPublicKey failed for \(peerCode): \(error)")
                }
            }
            guard let peerKey = person.peerPublicKey else {
                print("[App][LocationSync] no peerPublicKey for \(peerCode), skipping publish/fetch")
                continue
            }

            // Sharing my location to them is independent of receiving theirs (below) —
            // isSharingBack is what the per-person "Share my location" toggle controls.
            if sharingEnabled && person.isSharingBack {
                do {
                    try await service.shareLocation(withPeerCode: peerCode, peerPublicKey: peerKey)
                    print("[App][LocationSync] shareLocation succeeded for \(peerCode)")
                } catch {
                    print("[App][LocationSync] shareLocation failed for \(peerCode): \(error)")
                }
                do {
                    try await service.publishLocation(
                        location.coordinate,
                        forPeerCode: peerCode,
                        peerPublicKey: peerKey
                    )
                    print("[App][LocationSync] publishLocation succeeded for \(peerCode)")
                } catch {
                    print("[App][LocationSync] publishLocation failed for \(peerCode): \(error)")
                }
            }

            do {
                if let result = try await service.fetchLocation(ownerCode: peerCode, ownerPublicKey: peerKey) {
                    person.latitude = result.coordinate.latitude
                    person.longitude = result.coordinate.longitude
                    person.lastUpdated = result.timestamp
                    person.isReceivingActive = true
                    print("[App][LocationSync] fetchLocation succeeded for \(peerCode): \(result.coordinate.latitude), \(result.coordinate.longitude), published \(result.timestamp)")
                } else {
                    // Distinguish "never shared yet" from "stopped sharing": only the
                    // latter (we'd received from them before) should surface in the UI.
                    if person.lastUpdated != nil {
                        person.isReceivingActive = false
                    }
                    print("[App][LocationSync] fetchLocation for \(peerCode) returned no location (active: \(person.isReceivingActive))")
                }
            } catch {
                print("[App][LocationSync] fetchLocation failed for \(peerCode): \(error)")
            }
        }

        do {
            try context.save()
            print("[App][LocationSync] context.save() succeeded")
        } catch {
            print("[App][LocationSync] context.save() failed: \(error)")
        }

        WidgetDataBridge.write(
            items: items,
            ownLatitude: location.coordinate.latitude,
            ownLongitude: location.coordinate.longitude,
            ownLocationTimestamp: location.timestamp
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
}
