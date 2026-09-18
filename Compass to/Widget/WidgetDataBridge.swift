import Foundation

/// The main app's side of the App Group hand-off to CompassToWidget. There's no
/// SwiftData sharing across the two targets — instead the app periodically writes a
/// small JSON snapshot the widget can read without needing CoreLocation or the
/// model container itself. See CompassToWidget/WidgetDataBridge.swift for the
/// widget-side twin of these two structs — keep both in sync if either changes.
struct WidgetSnapshotItem: Codable {
    let id: String
    let name: String
    let colorHex: String
    let systemImage: String
    let isPerson: Bool
    let latitude: Double
    let longitude: Double
    let eventDate: Date?
    let lastUpdated: Date?
}

struct WidgetSnapshot: Codable {
    let ownLatitude: Double
    let ownLongitude: Double
    let ownLocationTimestamp: Date
    let items: [WidgetSnapshotItem]
}

enum WidgetDataBridge {
    static let appGroupID = "group.org.hoeschen.lukas.Compass-to"

    static func write(items: [TrackedItem], ownLatitude: Double, ownLongitude: Double, ownLocationTimestamp: Date) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let snapshotItems = items.compactMap { item -> WidgetSnapshotItem? in
            if item.type == .person && item.lastUpdated == nil { return nil }
            return WidgetSnapshotItem(
                id: item.id.uuidString,
                name: item.name,
                colorHex: item.colorHex,
                systemImage: item.type == .person ? "person.fill" : item.kind.systemImage,
                isPerson: item.type == .person,
                latitude: item.latitude,
                longitude: item.longitude,
                eventDate: item.eventDate,
                lastUpdated: item.lastUpdated
            )
        }

        let snapshot = WidgetSnapshot(
            ownLatitude: ownLatitude,
            ownLongitude: ownLongitude,
            ownLocationTimestamp: ownLocationTimestamp,
            items: snapshotItems
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: "widgetSnapshot")
        }
    }
}
