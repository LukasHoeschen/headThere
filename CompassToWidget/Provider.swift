import WidgetKit
import CoreLocation

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), item: nil, ownCoordinate: nil, ownLocationTimestamp: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let nextRefresh = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [entry(for: configuration)], policy: .after(nextRefresh))
    }

    private func entry(for configuration: ConfigurationAppIntent) -> SimpleEntry {
        let snapshot = WidgetDataBridge.read()
        let item: WidgetSnapshotItem?
        if let id = configuration.selection?.id {
            item = snapshot?.items.first { $0.id == id }
        } else {
            item = snapshot?.items.first
        }
        return SimpleEntry(
            date: Date(),
            item: item,
            ownCoordinate: snapshot?.ownCoordinate,
            ownLocationTimestamp: snapshot?.ownLocationTimestamp
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let item: WidgetSnapshotItem?
    let ownCoordinate: CLLocationCoordinate2D?
    let ownLocationTimestamp: Date?
}
