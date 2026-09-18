import SwiftUI
import CoreLocation

enum CompassZone { case middle, tooFar, tooClose }

// MARK: - Dynamic metrics

struct CompassMetrics {
    let outerR: CGFloat
    let arrowSize: CGFloat
    let labelFontSize: CGFloat
    let distFontSize: CGFloat
    let dotSize: CGFloat

    init(availableSize: CGSize) {
        let minDim = min(availableSize.width, availableSize.height)
        outerR        = min(minDim * 0.44, 280)
        arrowSize     = max(17, min(24, outerR * 0.115))
        labelFontSize = max(10, min(14, outerR * 0.075))
        distFontSize  = max(9,  min(12, outerR * 0.062))
        dotSize       = max(7,  min(11, outerR * 0.045))
    }
}

// MARK: - Item data

struct CompassItemData: Identifiable {
    var id: UUID { item.id }
    let item: TrackedItem
    let distance: Double
    let screenAngle: Double
    let zone: CompassZone
    let visualRadius: CGFloat
}

// MARK: - Ring marks (adaptive linear distance scale)

struct RingMark: Identifiable {
    let distance: Double
    var id: Double { distance }
    let radius: CGFloat
}

// MARK: - Compass view

struct CompassView: View {
    let items: [TrackedItem]
    let locationManager: LocationManager
    @Binding var zoomDistance: Double
    @Binding var userInteracted: Bool
    @Binding var equidistantMode: Bool

    @AppStorage("useMiles") private var useMiles: Bool = false

    private static let ringSteps: [Double] = [100, 1_000, 10_000, 100_000, 1_000_000, 20_000_000]

    // MARK: Data

    func itemsData(metrics: CompassMetrics) -> [CompassItemData] {
        guard let userLoc = locationManager.userLocation else { return [] }

        return items.compactMap { item in
            // A person with no successful location sync yet would otherwise sit at
            // the (0,0) placeholder coordinate and show a wildly wrong distance.
            if item.type == .person && item.lastUpdated == nil { return nil }

            let dist    = item.distance(from: userLoc)
            let bearing = item.bearing(from: userLoc)
            var angle   = (bearing - locationManager.heading).truncatingRemainder(dividingBy: 360)
            if angle < 0 { angle += 360 }
            let (zone, vr) = resolve(distance: dist, item: item, metrics: metrics)
            return CompassItemData(item: item, distance: dist, screenAngle: angle, zone: zone, visualRadius: vr)
        }
        .sorted { a, b in
            if a.item.isFavorite != b.item.isFavorite { return !a.item.isFavorite }
            return a.distance > b.distance
        }
    }

    // Below this fraction of the outer radius, items would visually crowd together
    // near the center point and their labels would overlap — so their radius is
    // floored here instead, giving close-together items room to fan out by bearing.
    private static let minVisualRatio: CGFloat = 0.05

    // Radius used for every item's arrow in equidistant mode, ignoring real distance.
    private static let equidistantRatio: CGFloat = 0.62

    private func resolve(
        distance: Double, item: TrackedItem, metrics: CompassMetrics
    ) -> (CompassZone, CGFloat) {
        if equidistantMode {
            return (.middle, Self.equidistantRatio * metrics.outerR)
        }
        if item.isFavorite && !userInteracted {
            return (.middle, metrics.outerR * 0.5)
        }
        if distance > zoomDistance {
            // Outside the visible scale
            return (.tooFar, metrics.outerR + 16)
        }
        let ratio = max(Self.minVisualRatio, CGFloat(distance / zoomDistance))
        if CGFloat(distance / zoomDistance) <= 0.12 {
            // In the Center as Small Dot
            return (.tooClose, ratio * metrics.outerR)
        }
        return (.middle, ratio * metrics.outerR)
    }

    // MARK: Ring marks

    // Only the round "1-prefixed" scale steps (100m, 1km, 10km, …) are ever shown,
    // and at most the two that are actually relevant at the current zoom level.
    private func ringMarks(metrics: CompassMetrics) -> [RingMark] {
        let candidates = Self.ringSteps.filter { $0 <= zoomDistance }
        return candidates.suffix(2).map { distance in
            RingMark(distance: distance, radius: metrics.outerR * CGFloat(distance / zoomDistance))
        }
    }

    // MARK: Zoom to favorites

    private func zoomToFavorites() {
        guard let userLoc = locationManager.userLocation else { return }
        let favDists = items.filter(\.isFavorite).map { $0.distance(from: userLoc) }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            if let maxDist = favDists.max(), maxDist > 0 {
                // Furthest favorite lands at ~65% into the visible scale
                zoomDistance = maxDist / 0.65
            } else if !items.isEmpty {
                let allDists = items.map { $0.distance(from: userLoc) }
                zoomDistance = (allDists.max() ?? 5000) * 1.4
            }
            userInteracted = true
        }
    }

    // MARK: Magnifier (equidistant mode only)

    // Only the finger's angle around the true center matters, not how far out
    // it is. The zoom's focal point sits at that same angle but mirrored to
    // the opposite side, always at a fixed distance (the ring's own radius) —
    // so sweeping a finger once around the circle sweeps the focal point once
    // around too, on the far side, never sitting under the finger itself. The
    // entire compass (rings, center dot, every cursor) scales up around that
    // focal point, which is what pulls the covered-up items out from under
    // the finger — not just the items near it.
    private static let magnifierZoomScale: CGFloat = 1.5

    private func magnifierFingerAngle(fingerOffset: CGSize) -> Double {
        atan2(fingerOffset.width, -fingerOffset.height)
    }

    private func magnifierFocalPoint(fingerOffset: CGSize, metrics: CompassMetrics) -> CGSize {
        let displayAngle = magnifierFingerAngle(fingerOffset: fingerOffset) + .pi
        let ringRadius = Self.equidistantRatio * metrics.outerR
        return CGSize(
            width: sin(displayAngle) * ringRadius,
            height: -cos(displayAngle) * ringRadius
        )
    }

    @State private var isTouchingForMagnifier = false
    @State private var magnifierActive = false
    @State private var magnifierFingerOffset: CGSize?

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            let metrics = CompassMetrics(availableSize: geo.size)
            let focalPoint = magnifierFingerOffset.map {
                magnifierFocalPoint(fingerOffset: $0, metrics: metrics)
            }
            let zoomAnchor: UnitPoint = focalPoint.map {
                UnitPoint(x: 0.5 - 10 * ( $0.width / geo.size.width), y: 0.5 - 10 * ($0.height / geo.size.height))
            } ?? .center
            let zoomScale: CGFloat = (equidistantMode && magnifierActive) ? Self.magnifierZoomScale : 1.0

            ZStack {
                if equidistantMode {
                    // A single guide ring — no labels, no scale, just where the cursors sit.
                    Circle()
                        .stroke(.gray.opacity(0.16), lineWidth: 0.75)
                        .frame(
                            width: Self.equidistantRatio * metrics.outerR * 2,
                            height: Self.equidistantRatio * metrics.outerR * 2
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .scale(scale: 1.6).combined(with: .opacity)
                        ))
                } else {
                    // Adaptive concentric distance rings
                    ForEach(ringMarks(metrics: metrics)) { mark in
                        Circle()
                            .stroke(.gray.opacity(0.16), lineWidth: 0.75)
                            .frame(width: mark.radius * 2, height: mark.radius * 2)

                        Text(formatDistance(mark.distance, useMiles: useMiles))
                            .font(.system(size: max(8, metrics.distFontSize - 2), weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                            .offset(y: -mark.radius)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity),
                        removal: .scale(scale: 1.6).combined(with: .opacity)
                    ))
                }

                // Center dot
                Circle()
                    .fill(.gray.opacity(0.5))
                    .frame(width: 5, height: 5)

                if locationManager.userLocation == nil {
                    Text("Getting your\nlocation…")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                // Item indicators (tapping them has no effect)
                ForEach(itemsData(metrics: metrics)) { data in
                    SingleItemView(data: data, metrics: metrics)
                }
            }
            // The whole compass zooms in around the focal point opposite the finger,
            // moving every cursor (and the ring itself) at once.
            .scaleEffect(zoomScale, anchor: zoomAnchor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Double-tap anywhere → zoom to favorites
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { zoomToFavorites() }
            )
            // Press and hold (equidistant mode only) → magnifying lens that follows the finger.
            // A single DragGesture with minimumDistance 0 tracks the touch from the moment it
            // lands; a timer started at touch-down (not tied to onChanged firing again) decides
            // when the hold has lasted long enough to activate the lens — LongPressGesture's own
            // "hold still" tracking fought with then dragging, so this avoids composing the two.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard equidistantMode else { return }
                        magnifierFingerOffset = CGSize(
                            width: value.location.x - geo.size.width / 2,
                            height: value.location.y - geo.size.height / 2
                        )
                        if !isTouchingForMagnifier {
                            isTouchingForMagnifier = true
                            Task {
                                try? await Task.sleep(for: .seconds(0.2))
                                if isTouchingForMagnifier {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        magnifierActive = true
                                    }
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        isTouchingForMagnifier = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            magnifierActive = false
                        }
                        magnifierFingerOffset = nil
                    }
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: magnifierActive) { _, new in new }
        }
    }
}
