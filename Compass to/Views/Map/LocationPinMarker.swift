import SwiftUI

/// Classic teardrop map pin, used for static locations.
struct LocationPinMarker: View {
    let item: TrackedItem

    var body: some View {
        Image(systemName: item.kind.systemImage)
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(item.color)
            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
    }
}
