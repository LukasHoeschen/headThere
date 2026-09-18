import SwiftUI

/// Location-dot style marker, used for tracked people.
struct PersonLocationMarker: View {
    let item: TrackedItem

    var body: some View {
        ZStack {
            Circle()
                .fill(item.color.opacity(0.22))
                .frame(width: 34, height: 34)
            Circle()
                .fill(item.color)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
    }
}
