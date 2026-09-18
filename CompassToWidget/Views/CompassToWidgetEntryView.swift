import WidgetKit
import SwiftUI

struct CompassToWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        if let item = entry.item, let origin = entry.ownCoordinate {
            let bearing = item.bearing(from: origin)
            let distance = item.distance(from: origin)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.caption2)
                            .foregroundStyle(Color(widgetHex: item.colorHex))
                        Text(item.name)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }

                    Text(formatWidgetDistance(distance))
                        .font(.title2.bold().monospacedDigit())

                    if let countdown = item.countdownText {
                        Text(countdown)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 2)

                    if let ownTimestamp = entry.ownLocationTimestamp {
                        Text("My location: \(formatWidgetRelative(ownTimestamp))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    if item.isPerson, let personUpdated = item.lastUpdated {
                        Text("Person: \(formatWidgetRelative(personUpdated))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CompassRoseView(bearing: bearing, color: Color(widgetHex: item.colorHex))
                    .frame(width: 74, height: 74)
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "location.slash")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Edit the widget to choose a place or person.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
