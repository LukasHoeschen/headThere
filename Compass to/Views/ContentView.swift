import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct ContentView: View {
    @Environment(LocationManager.self) private var locationManager
    @Query private var items: [TrackedItem]

    @State private var zoomDistance: Double = 5000
    @State private var userInteracted: Bool = false
    @State private var mapMode: Bool = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var equidistantMode: Bool = false

    @AppStorage("zoomBarOnLeft") private var zoomBarOnLeft: Bool = false

    var sortedItems: [TrackedItem] {
        guard let loc = locationManager.userLocation else { return items }
        let favs = items.filter(\.isFavorite).sorted { $0.distance(from: loc) < $1.distance(from: loc) }
        let rest = items.filter { !$0.isFavorite }.sorted { $0.distance(from: loc) < $1.distance(from: loc) }
        return favs + rest
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if mapMode {
                    MapOverviewView(items: items, cameraPosition: $mapCameraPosition)
                        .transition(.opacity)
                }
//                } else {
                    CompassView(
                        items: items,
                        locationManager: locationManager,
                        zoomDistance: $zoomDistance,
                        userInteracted: $userInteracted,
                        equidistantMode: $equidistantMode
                    )
                        .offset(y: mapMode ? UIScreen.main.bounds.height : 0)

                    if !equidistantMode {
                        ZoomBarView(
                            zoomDistance: $zoomDistance,
                            userInteracted: $userInteracted,
                            onLeftEdge: zoomBarOnLeft
                        )
                        .padding(.vertical, 40)
                        .padding(.bottom, 90)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: zoomBarOnLeft ? .leading : .trailing)
                        // Zoom level is meaningless in equidistant mode, so the bar
                        // slides out past the edge it's docked on instead of just fading.
                        .transition(.move(edge: zoomBarOnLeft ? .leading : .trailing).combined(with: .opacity))
                        .offset(x: mapMode ? (zoomBarOnLeft ? -500 : 500) : 0)
                    }
//                }
            }
            .navigationTitle(mapMode ? "Map" : "Compass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !mapMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation { equidistantMode.toggle() }
                        } label: {
                            Image(systemName: equidistantMode ? "ruler.fill" : "ruler")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.bouncy(duration: 0.6)) {
                            mapMode.toggle()
                        }
                    } label: {
                        Image(systemName: mapMode ? "location.north.circle" : "map")
                    }
                }
            }
            // Single persistent bottom sheet; add lives inside it
            .sheet(isPresented: .constant(true)) {
                ItemListSheet(
                    items: sortedItems,
                    locationManager: locationManager,
                    onSelect: { selectItem($0) }
                )
                .presentationDetents([.height(90), .medium, .large], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
                .interactiveDismissDisabled(true)
            }
        }
    }

    /// Tapping an item in the list brings it into view — on the map or the compass,
    /// whichever is currently shown — and collapses the sheet to its smallest
    /// detent so the view underneath is actually visible.
    private func selectItem(_ item: TrackedItem) {
        if mapMode {
            withAnimation {
                mapCameraPosition = .region(
                    MKCoordinateRegion(
                        center: item.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
                sheetDetent = .height(90)
            }
        } else if let loc = locationManager.userLocation {
            let dist = item.distance(from: loc)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                zoomDistance = max(dist / 0.65, 100)
                userInteracted = true
                sheetDetent = .height(90)
            }
        }
    }
}
