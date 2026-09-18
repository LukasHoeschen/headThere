import SwiftUI

// MARK: - Bottom sheet

struct ItemListSheet: View {
    let items: [TrackedItem]
    let locationManager: LocationManager
    let onSelect: (TrackedItem) -> Void

    @Environment(PairingRouter.self) private var pairingRouter
    @AppStorage("isPro") private var isPro: Bool = false

    @State private var showAdd = false
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var editingItem: TrackedItem?
    @State private var pendingPairCode: String?

    /// True once both free-tier limits are used up — at that point "+" should go
    /// straight to the paywall instead of a form that can't actually save anything.
    private var freeQuotaExhausted: Bool {
        guard !isPro else { return false }
        let personCount = items.filter { $0.type == .person }.count
        let locationCount = items.filter { $0.type == .location }.count
        return personCount >= freePersonLimit && locationCount >= freeLocationLimit
    }

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
                        Section {
                            ForEach(items) { item in
                                Button {
                                    onSelect(item)
                                } label: {
                                    ItemRow(item: item, locationManager: locationManager)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
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
                            }
                        } footer: {
                            Text("Press and hold an entry to edit it.")
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
                        if freeQuotaExhausted { showPaywall = true }
                        else { showAdd = true }
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
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
            .sheet(item: $editingItem) { item in
                NavigationStack {
                    ItemDetailView(locationManager: locationManager, item: item, startInEditMode: true)
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
}
