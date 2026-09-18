import Foundation
import SwiftData
import SwiftUI
import CoreLocation

enum TrackedItemType: String, Codable {
    case location
    case person
}

/// Categorizes `.location` items so the icon (and, for some kinds, an optional
/// date) can reflect what kind of place it is.
enum PlaceKind: String, Codable, CaseIterable, Identifiable {
    case city
    case home
    case vacation
    case work
    case restaurant
    case event

    var id: String { rawValue }

    var label: String {
        switch self {
        case .city: return "City"
        case .home: return "Home"
        case .vacation: return "Vacation"
        case .work: return "Work"
        case .restaurant: return "Restaurant"
        case .event: return "Event"
        }
    }

    // No dedicated palm-tree symbol exists in SF Symbols; beach.umbrella reads
    // clearly as "vacation" instead.
    var systemImage: String {
        switch self {
        case .city: return "building.2.fill"
        case .home: return "house.fill"
        case .vacation: return "beach.umbrella.fill"
        case .work: return "briefcase.fill"
        case .restaurant: return "fork.knife"
        case .event: return "calendar"
        }
    }
}

@Model
final class TrackedItem: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var type: TrackedItemType = TrackedItemType.location
    var colorHex: String = "#FF6B6B"
    var isFavorite: Bool = false
    var createdAt: Date = Date()

    // Location (static for .location; last shared for .person)
    var latitude: Double = 0
    var longitude: Double = 0
    var lastUpdated: Date?

    // Person: custom server sharing code + their Curve25519 public key (fetched once at pairing time)
    var sharingCode: String?
    var peerPublicKey: Data?

    // Location: what kind of place it is, plus an optional date (e.g. when a vacation starts)
    var placeKind: String = PlaceKind.city.rawValue
    var eventDate: Date?

    var kind: PlaceKind {
        get { PlaceKind(rawValue: placeKind) ?? .city }
        set { placeKind = newValue.rawValue }
    }

    init(
        name: String,
        type: TrackedItemType,
        latitude: Double,
        longitude: Double,
        colorHex: String,
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.colorHex = colorHex
        self.isFavorite = isFavorite
        self.createdAt = Date()
    }

    var color: Color { Color(hex: colorHex) }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(from loc: CLLocation) -> Double {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: loc)
    }

    /// A localized "in 2 weeks" style string, or nil if there's no upcoming date.
    var countdownText: String? {
        guard let eventDate, eventDate > Date() else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: eventDate, relativeTo: Date())
    }

    func bearing(from loc: CLLocation) -> Double {
        let lat1 = loc.coordinate.latitude.toRadians()
        let lon1 = loc.coordinate.longitude.toRadians()
        let lat2 = latitude.toRadians()
        let lon2 = longitude.toRadians()
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x).toDegrees() + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - Helpers

extension Double {
    func toRadians() -> Double { self * .pi / 180 }
    func toDegrees() -> Double { self * 180 / .pi }
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    func toHex() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// Free-tier limits — Pro (gated behind @AppStorage("isPro")) removes both.
let freePersonLimit = 1
let freeLocationLimit = 5

let itemColorPalette = [
    "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
    "#FECA57", "#FF9FF3", "#54A0FF", "#5F27CD",
    "#00D2D3", "#FF9F43", "#1DD1A1", "#C8D6E5"
]

func nextItemColor(count: Int) -> String {
    itemColorPalette[count % itemColorPalette.count]
}

func formatDistance(_ meters: Double, useMiles: Bool) -> String {
    if useMiles {
        let feet = meters * 3.28084
        if feet < 1000 { return "\(Int(feet.rounded()))ft" }
        let miles = meters / 1609.344
        return miles < 10 ? String(format: "%.1fmi", miles) : "\(Int(miles.rounded()))mi"
    }
    if meters < 1000 { return "\(Int(meters.rounded()))m" }
    let km = meters / 1000
    return km < 10 ? String(format: "%.1fkm", km) : "\(Int(km.rounded()))km"
}
