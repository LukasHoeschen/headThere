import SwiftUI

/// Vertical bar at the screen edge for changing the compass zoom level.
/// Swiping up decreases the shown distance (zoom in), swiping down increases it (zoom out).
/// The mapping from finger position to zoom level is logarithmic, matching the fixed
/// distance steps shown as tick labels.
struct ZoomBarView: View {
    @Binding var zoomDistance: Double
    @Binding var userInteracted: Bool
    let onLeftEdge: Bool

    @AppStorage("useMiles") private var useMiles: Bool = false

    private let minLog = 2.0                    // 100 m
    private let maxLog = log10(20_000_000.0)     // 20,000 km (~ antipodal distance)
    private let steps: [Double] = [100, 1_000, 10_000, 100_000, 1_000_000, 20_000_000]

    private func fraction(for distance: Double) -> Double {
        let f = (log10(distance) - minLog) / (maxLog - minLog)
        return min(max(f, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let trackX: CGFloat = onLeftEdge ? 14 : geo.size.width - 14

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(.gray.opacity(0.2))
                    .frame(width: 3, height: h)
                    .position(x: trackX, y: h / 2)

                ForEach(steps, id: \.self) { step in
                    tickRow(step: step, trackX: trackX, y: fraction(for: step) * h)
                }

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 11, height: 11)
                    .shadow(radius: 1, y: 1)
                    .position(x: trackX, y: fraction(for: zoomDistance) * h)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let frac = min(max(val.location.y / h, 0), 1)
                        let log = minLog + frac * (maxLog - minLog)
                        zoomDistance = pow(10, log)
                        userInteracted = true
                    }
            )
        }
        .frame(width: 60)
    }

    @ViewBuilder
    private func tickRow(step: Double, trackX: CGFloat, y: CGFloat) -> some View {
        HStack(spacing: 4) {
            if !onLeftEdge {
                Text(formatDistance(step, useMiles: useMiles))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Rectangle()
                .fill(.gray.opacity(0.45))
                .frame(width: 6, height: 1.5)
            if onLeftEdge {
                Text(formatDistance(step, useMiles: useMiles))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .position(x: trackX + (onLeftEdge ? 26 : -26), y: y)
    }
}
