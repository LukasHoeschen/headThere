import SwiftUI

// MARK: - Bottom sheet

struct ItemListSheet: View {
    let items: [TrackedItem]
    let locationManager: LocationManager
    let onSelect: (TrackedItem) -> Void

    @Environment(PairingRouter.self) private var pairingRouter

    @State private var showAdd = false
    @State private var showSettings = false
    @State private var editingItem: TrackedItem?
    @State private var detailItem: TrackedItem?
    @State private var pendingPairCode: String?

    private var favoriteItems: [TrackedItem] { items.filter(\.isFavorite) }
    private var peopleItems: [TrackedItem] { items.filter { $0.type == .person && !$0.isFavorite } }
    private var placeItems: [TrackedItem] { items.filter { $0.type == .location && !$0.isFavorite } }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Places",
                        systemImage: "mappin.slash",
                        description: Text("Tap + to add a place or a person.")
                    )
                } else {
                    List {
                        if !favoriteItems.isEmpty {
                            Section("Favorites") {
                                ForEach(favoriteItems) { item in
                                    row(for: item)
                                }
                            }
                        }

                        Section {
                            ForEach(peopleItems) { item in
                                row(for: item)
                            }
                            NavigationLink {
                                LocationSharingInfoView()
                            } label: {
                                Label("How Location Sharing Works", systemImage: "questionmark.circle")
                            }
                        } header: {
                            Text("People")
                        }

                        Section {
                            ForEach(placeItems) { item in
                                row(for: item)
                            }
                        } header: {
                            Text("Places")
                        } footer: {
                            Text("Press and hold an entry to edit it, or swipe for more actions.")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Places & People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddItemView(initialPersonCode: pendingPairCode)
                    .onDisappear { pendingPairCode = nil }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $editingItem) { item in
                NavigationStack {
                    ItemDetailView(locationManager: locationManager, item: item, startInEditMode: true)
                }
            }
            .sheet(item: $detailItem) { item in
                NavigationStack {
                    ItemDetailView(locationManager: locationManager, item: item, startInEditMode: false)
                }
            }
            .onChange(of: pairingRouter.pendingCode) { _, newCode in
                guard let code = newCode else { return }
                pendingPairCode = code
                showAdd = true
                pairingRouter.pendingCode = nil
            }
        }
    }

    @ViewBuilder
    private func row(for item: TrackedItem) -> some View {
        Button {
            onSelect(item)
        } label: {
            ItemRow(item: item, locationManager: locationManager)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                detailItem = item
            } label: {
                Label("Details", systemImage: "info.circle")
            }
            Button {
                editingItem = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                withAnimation { item.isFavorite.toggle() }
            } label: {
                Label(
                    item.isFavorite ? "Remove Favorite" : "Favorite",
                    systemImage: item.isFavorite ? "star.slash" : "star.fill"
                )
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation { item.isFavorite.toggle() }
            } label: {
                Label(
                    item.isFavorite ? "Remove" : "Favorite",
                    systemImage: item.isFavorite ? "star.slash" : "star.fill"
                )
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            Button {
                detailItem = item
            } label: {
                Label("Details", systemImage: "info.circle")
            }
            .tint(.blue)
        }
    }
}
