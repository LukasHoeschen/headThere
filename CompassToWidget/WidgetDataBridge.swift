import Foundation
import CoreLocation

/// Widget-side twin of Compass to/WidgetDataBridge.swift's structs. The widget
/// extension can't share the main app's SwiftData model directly, so the app
/// writes this same shape as JSON into the App Group; keep both copies in sync.
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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Bearing from true north to this item, seen from `origin` — CoreLocation has
    /// no built-in bearing-between-two-points, so this mirrors the main app's formula.
    func bearing(from origin: CLLocationCoordinate2D) -> Double {
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180
        let lat2 = latitude * .pi / 180
        let lon2 = longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    func distance(from origin: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: origin.latitude, longitude: origin.longitude))
    }

    /// A localized "in 2 Wochen" style string, or nil if there's no upcoming date.
    var countdownText: String? {
        guard let eventDate, eventDate > Date() else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: eventDate, relativeTo: Date())
    }
}

struct WidgetSnapshot: Codable {
    let ownLatitude: Double
    let ownLongitude: Double
    let ownLocationTimestamp: Date
    let items: [WidgetSnapshotItem]

    var ownCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: ownLatitude, longitude: ownLongitude)
    }
}

enum WidgetDataBridge {
    static let appGroupID = "group.org.hoeschen.lukas.Compass-to"

    static func read() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: "widgetSnapshot") else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

func formatWidgetDistance(_ meters: Double) -> String {
    if meters < 1000 { return "\(Int(meters.rounded()))m" }
    let km = meters / 1000
    return km < 10 ? String(format: "%.1fkm", km) : "\(Int(km.rounded()))km"
}

private let widgetRelativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f
}()

func formatWidgetRelative(_ date: Date) -> String {
    widgetRelativeFormatter.localizedString(for: date, relativeTo: Date())
}
