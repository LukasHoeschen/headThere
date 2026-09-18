import WidgetKit
import SwiftUI
import CoreLocation

struct CompassToWidget: Widget {
    let kind: String = "CompassToWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            CompassToWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Compass To")
        .description("Shows direction and distance to a place or a person.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension Color {
    init(widgetHex hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#Preview(as: .systemMedium) {
    CompassToWidget()
} timeline: {
    SimpleEntry(date: .now, item: nil, ownCoordinate: nil, ownLocationTimestamp: nil)
}
