import SwiftUI
import MapKit
import CoreLocation

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let locationManager: LocationManager

    @Bindable var item: TrackedItem
    var startInEditMode: Bool = false

    @State private var showDeleteAlert = false
    @State private var editName: String = ""
    @State private var editColor: String = ""
    @State private var editCoordinate: CLLocationCoordinate2D?
    @State private var editCameraPosition: MapCameraPosition = .automatic
    @State private var editPlaceKind: PlaceKind = .city
    @State private var editHasEventDate: Bool = false
    @State private var editEventDate: Date = Date()
    @State private var isEditing = false

    @AppStorage("useMiles") private var useMiles: Bool = false

    var distance: String {
        guard let loc = locationManager.userLocation else { return "–" }
        return formatDistance(item.distance(from: loc), useMiles: useMiles)
    }

    var bearingAngle: Double {
        guard let loc = locationManager.userLocation else { return 0 }
        let bearing = item.bearing(from: loc)
        return (bearing - locationManager.heading + 360).truncatingRemainder(dividingBy: 360)
    }

    var body: some View {
        Form {
            Section {
                if isEditing {
                    TextField("Name", text: $editName)
                } else {
                    HStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 12, height: 12)
                        Text(item.name).font(.headline)
                        Spacer()
                        Image(systemName: item.type == .person ? "person.fill" : item.kind.systemImage)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if item.type == .location {
                Section {
                    if isEditing {
                        Picker("Kind", selection: $editPlaceKind) {
                            ForEach(PlaceKind.allCases) { kind in
                                Label(kind.label, systemImage: kind.systemImage).tag(kind)
                            }
                        }
                        Toggle("Add Date", isOn: $editHasEventDate)
                        if editHasEventDate {
                            DatePicker("Date", selection: $editEventDate, displayedComponents: .date)
                        }
                    } else {
                        LabeledContent("Kind") {
                            Label(item.kind.label, systemImage: item.kind.systemImage)
                        }
                        if let countdown = item.countdownText {
                            LabeledContent("Date") {
                                Text(countdown.capitalized)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    if isEditing {
                        Text("A date is handy for something like a vacation spot: the compass will then show right next to the direction how long until it's time — like \u{201c}in 2 weeks\u{201d}.")
                    }
                }
            }

            if isEditing {
                Section("Color") {
                    editColorRow
                }
            }

            Section("Distance") {
                HStack {
                    Text(distance).font(.title2.bold())
                    Spacer()
                    Image(systemName: "location.north.fill")
                        .font(.title2)
                        .foregroundStyle(item.color)
                        .rotationEffect(.degrees(bearingAngle))
                }
            }

            if item.type == .person {
                Section("Person") {
                    LabeledContent("Last Update") {
                        Text(item.lastUpdated.map { $0.formatted(.relative(presentation: .named)) } ?? "Never")
                            .foregroundStyle(.secondary)
                    }
                    if let code = item.sharingCode {
                        LabeledContent("Sharing Code") {
                            Text(code)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Section("Map") {
                    if isEditing {
                        MapReader { proxy in
                            Map(position: $editCameraPosition) {
                                Marker("", coordinate: editCoordinate ?? item.coordinate)
                            }
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture { screenPos in
                                if let coord = proxy.convert(screenPos, from: .local) {
                                    editCoordinate = coord
                                }
                            }
                        }
                        Text("Tap the map to move the pin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Map {
                            Marker("", coordinate: editCoordinate ?? item.coordinate)
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            Section {
                Button {
                    withAnimation { item.isFavorite.toggle() }
                } label: {
                    Label(
                        item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: item.isFavorite ? "star.fill" : "star"
                    )
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing { applyEdits() }
                    else { beginEditing() }
                    isEditing.toggle()
                }
            }
        }
        .alert("Delete?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(item.name)\" will be permanently deleted.")
        }
        .onAppear {
            if startInEditMode {
                beginEditing()
                isEditing = true
            }
        }
    }

    @ViewBuilder
    private var editColorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(itemColorPalette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(.white, lineWidth: editColor == hex ? 2.5 : 0).padding(2))
                        .overlay(Circle().stroke(Color(hex: hex), lineWidth: editColor == hex ? 1.5 : 0))
                        .onTapGesture { editColor = hex }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func beginEditing() {
        editName = item.name
        editColor = item.colorHex
        editCoordinate = item.coordinate
        editCameraPosition = .region(
            MKCoordinateRegion(
                center: item.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
        editPlaceKind = item.kind
        editHasEventDate = item.eventDate != nil
        editEventDate = item.eventDate ?? Date()
    }

    private func applyEdits() {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { item.name = trimmed }
        item.colorHex = editColor
        if item.type == .location {
            if let coord = editCoordinate {
                item.latitude = coord.latitude
                item.longitude = coord.longitude
            }
            item.kind = editPlaceKind
            item.eventDate = editHasEventDate ? editEventDate : nil
        }
    }
}
