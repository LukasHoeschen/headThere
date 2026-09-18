import SwiftUI

// MARK: - Item row

struct ItemRow: View {
    let item: TrackedItem
    let locationManager: LocationManager

    @AppStorage("useMiles") private var useMiles: Bool = false

    var distance: String {
        guard let loc = locationManager.userLocation else { return "–" }
        return formatDistance(item.distance(from: loc), useMiles: useMiles)
    }

    var bearingAngle: Double {
        guard let loc = locationManager.userLocation else { return 0 }
        let b = item.bearing(from: loc)
        return (b - locationManager.heading + 360).truncatingRemainder(dividingBy: 360)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(item.color.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: item.type == .person ? "person.fill" : item.kind.systemImage)
                    .foregroundStyle(item.color)
                    .font(.system(size: 15))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.name).font(.subheadline.bold())
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                    }
                }
                if item.type == .person, let updated = item.lastUpdated {
                    Text(updated.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let countdown = item.countdownText {
                    Text(countdown.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text(distance)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(item.color)
                    .rotationEffect(.degrees(bearingAngle))
            }
        }
        .padding(.vertical, 2)
    }
}
