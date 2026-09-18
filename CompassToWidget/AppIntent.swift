import WidgetKit
import AppIntents

struct TrackableItemEntity: AppEntity {
    var id: String
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Place or Person" }
    static var defaultQuery = TrackableItemEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TrackableItemEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TrackableItemEntity] {
        let items = WidgetDataBridge.read()?.items ?? []
        return items
            .filter { identifiers.contains($0.id) }
            .map { TrackableItemEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [TrackableItemEntity] {
        let items = WidgetDataBridge.read()?.items ?? []
        return items.map { TrackableItemEntity(id: $0.id, name: $0.name) }
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Place or Person" }
    static var description: IntentDescription { "Choose what to show in the widget." }

    @Parameter(title: "Selection")
    var selection: TrackableItemEntity?
}
