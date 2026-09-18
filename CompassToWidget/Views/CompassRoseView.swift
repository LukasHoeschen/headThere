import SwiftUI

/// A small compass bezel: N/E/S/W around the rim, a red marker pinned at true
/// north, and the tracked item's own arrow inside pointing at its bearing.
struct CompassRoseView: View {
    let bearing: Double
    let color: Color

    private let cardinals: [(label: String, angle: Double)] = [
        ("N", 0), ("E", 90), ("S", 180), ("W", 270)
    ]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2

            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.35), lineWidth: 1)

                ForEach(cardinals, id: \.label) { cardinal in
                    Text(cardinal.label)
                        .font(.system(size: size * 0.14, weight: .bold))
                        .foregroundStyle(cardinal.label == "N" ? .red : .secondary)
                        .rotationEffect(.degrees(-cardinal.angle))
                        .offset(y: -radius + size * 0.14)
                        .rotationEffect(.degrees(cardinal.angle))
                }

                // North marker sitting right on the rim.
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: size * 0.1))
                    .foregroundStyle(.red)
                    .offset(y: -radius + size * 0.02)

                // The tracked item's own direction, inside the rose.
                Image(systemName: "location.north.fill")
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(bearing))
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
