import SwiftUI
import MapKit

/// Embedded map mode for the main screen — replaces the compass in place.
struct MapOverviewView: View {
    let items: [TrackedItem]
    @Binding var cameraPosition: MapCameraPosition

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(items.filter { $0.type != .person || $0.lastUpdated != nil }) { item in
                if item.type == .person {
                    Annotation(item.name, coordinate: item.coordinate) {
                        PersonLocationMarker(item: item)
                    }
                } else {
                    Annotation(item.name, coordinate: item.coordinate, anchor: .bottom) {
                        LocationPinMarker(item: item)
                    }
                }
            }
        }
        .onAppear { fitAll() }
    }

    private func fitAll() {
        let located = items.filter { $0.type != .person || $0.lastUpdated != nil }
        guard !located.isEmpty else { return }
        if located.count == 1 {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: located[0].coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
            return
        }
        let lats = located.map(\.latitude)
        let lons = located.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.02, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.02, (maxLon - minLon) * 1.4)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}
