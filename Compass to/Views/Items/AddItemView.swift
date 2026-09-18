import SwiftUI
import _SwiftData_SwiftUI
import MapKit
import CoreLocation

struct AddItemView: View {
    var initialPersonCode: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationIdentity.self) private var identity
    @Query private var existingItems: [TrackedItem]

    @AppStorage("isPro") private var isPro: Bool = false
    @State private var showPaywall = false

    @State private var selectedType: TrackedItemType = .location
    @State private var name: String = ""
    @State private var selectedColor: String = "#FF6B6B"

    // Location
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var pinCoordinate: CLLocationCoordinate2D? = nil
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var showSearchResults: Bool = false
    @State private var placeKind: PlaceKind = .city
    @State private var hasEventDate: Bool = false
    @State private var eventDate: Date = Date()

    // Person
    @State private var personCode: String = ""

    var canConfirm: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (selectedType == .person || pinCoordinate != nil)
    }

    /// Whether adding the currently selected type would exceed the free-tier limit.
    private var wouldExceedFreeLimit: Bool {
        guard !isPro else { return false }
        switch selectedType {
        case .person:
            return existingItems.filter { $0.type == .person }.count >= freePersonLimit
        case .location:
            return existingItems.filter { $0.type == .location }.count >= freeLocationLimit
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $selectedType) {
                        Label("Place", systemImage: "mappin.and.ellipse").tag(TrackedItemType.location)
                        Label("Person", systemImage: "person.fill").tag(TrackedItemType.person)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Name", text: $name)
                    ColorPickerRow(selected: $selectedColor)
                }

                if selectedType == .location {
                    locationSection
                } else {
                    personSection
                }
            }
            .navigationTitle(selectedType == .location ? "Add Place" : "Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if wouldExceedFreeLimit { showPaywall = true }
                        else { save() }
                    }
                    .disabled(!canConfirm)
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
        }
        .onAppear {
            selectedColor = nextItemColor(count: existingItems.count)
            if let code = initialPersonCode {
                selectedType = .person
                personCode = code
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        Section {
            Picker("Kind", selection: $placeKind) {
                ForEach(PlaceKind.allCases) { kind in
                    Label(kind.label, systemImage: kind.systemImage).tag(kind)
                }
            }

            Toggle("Add Date", isOn: $hasEventDate)
            if hasEventDate {
                DatePicker("Date", selection: $eventDate, displayedComponents: .date)
            }
        } footer: {
            Text("A date is handy for something like a vacation spot: the compass will then show right next to the direction how long until it's time — like \u{201c}in 2 weeks\u{201d}.")
        }

        Section("Map") {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search…", text: $searchText)
                    .onSubmit { performSearch() }
                    .submitLabel(.search)
                if !searchText.isEmpty {
                    Button { searchText = ""; searchResults = []; showSearchResults = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showSearchResults && !searchResults.isEmpty {
                ForEach(searchResults, id: \.self) { item in
                    Button {
                        select(mapItem: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Unknown").foregroundStyle(.primary)
                            if let addr = item.placemark.title {
                                Text(addr).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if let coord = pinCoordinate {
                        Marker("", coordinate: coord)
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture { screenPos in
                    if let coord = proxy.convert(screenPos, from: .local) {
                        pinCoordinate = coord
                        showSearchResults = false
                        searchText = ""
                        searchResults = []
                    }
                }
            }

            if pinCoordinate != nil {
                Label("Location set", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Text("Tap the map to drop a pin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var personSection: some View {
        Section("Share Location") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Send each other your code (via link) and enter the other person's code here. Locations are exchanged end-to-end encrypted through your own server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ShareCodeView()

            TextField("Other person's code", text: $personCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchText
        MKLocalSearch(request: req).start { response, _ in
            searchResults = response?.mapItems ?? []
            showSearchResults = true
        }
    }

    private func select(mapItem: MKMapItem) {
        pinCoordinate = mapItem.placemark.coordinate
        if name.isEmpty { name = mapItem.name ?? "" }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: mapItem.placemark.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
        searchResults = []
        showSearchResults = false
        searchText = ""
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let lat: Double
        let lon: Double

        if selectedType == .location, let coord = pinCoordinate {
            lat = coord.latitude
            lon = coord.longitude
        } else {
            // Person: placeholder location; real sharing pending
            lat = 0
            lon = 0
        }

        let item = TrackedItem(
            name: trimmed,
            type: selectedType,
            latitude: lat,
            longitude: lon,
            colorHex: selectedColor
        )
        if selectedType == .location {
            item.kind = placeKind
            item.eventDate = hasEventDate ? eventDate : nil
        }
        let trimmedCode = personCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedType == .person && !trimmedCode.isEmpty {
            item.sharingCode = trimmedCode
        }
        modelContext.insert(item)
        dismiss()

        if selectedType == .person && !trimmedCode.isEmpty {
            fetchPeerPublicKey(for: item, code: trimmedCode)
        }
    }

    /// Runs after dismiss so adding a person doesn't block on the network;
    /// the peer's key just becomes available once this completes.
    private func fetchPeerPublicKey(for item: TrackedItem, code: String) {
        let service = LocationSharingService(identity: identity)
        Task {
            if let key = try? await service.fetchPublicKey(for: code) {
                item.peerPublicKey = key
            }
        }
    }
}
