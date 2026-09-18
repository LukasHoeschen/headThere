import SwiftUI

struct SettingsView: View {
    @AppStorage("zoomBarOnLeft") private var zoomBarOnLeft: Bool = false
    @AppStorage("useMiles") private var useMiles: Bool = false
    @AppStorage("isPro") private var isPro: Bool = false
    @AppStorage("locationSharingEnabled") private var locationSharingEnabled: Bool = true
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationIdentity.self) private var identity
    @Environment(PurchaseManager.self) private var purchaseManager

    @State private var showPaywall = false

    private var pairingURL: URL {
        URL(string: "compassto://pair?code=\(identity.ownCode)")!
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isPro {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Compass To Pro", systemImage: "location.north.circle.fill")
                                Spacer()
                                if isPro {
                                    Text("Active").foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                            }
                        }
                        if !isPro {
                            Button("Restore Purchases") {
                                Task { await purchaseManager.restorePurchases() }
                            }
                        }
                    } footer: {
                        Text("Free: \(freePersonLimit) person and \(freeLocationLimit) places. Pro unlocks unlimited.")
                    }
                }
                
                Section("Settings") {
                    Toggle("Show Zoom Bar on the left", isOn: $zoomBarOnLeft)
                
                    Picker("Unit", selection: $useMiles) {
                        Text("Meters / Kilometers").tag(false)
                        Text("Feet / Miles").tag(true)
                    }
                }
                
                Section {
                    NavigationLink("Contact") {
                        ContactView()
                    }
                }
                
                Section {
                    LabeledContent("My Code") {
                        Text(identity.ownCode)
                            .font(.system(.body, design: .monospaced))
                    }
                    ShareLink(
                        item: pairingURL,
                        subject: Text("Compass To"),
                        message: Text("Add me in Compass To so we can share locations.")
                    ) {
                        Label("Share My Location Code", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        locationSharingEnabled.toggle()
                    } label: {
                        Label(
                            locationSharingEnabled ? "Stop Sharing Location" : "Resume Sharing Location",
                            systemImage: locationSharingEnabled ? "location.slash.fill" : "location.fill"
                        )
                    }
                    .foregroundStyle(locationSharingEnabled ? .red : .accentColor)
                } header: {
                    Text("Location Sharing")
                } footer: {
                    Text("People you've added can only see your location while sharing is on. Stopping sharing keeps your pairings, but pauses sending them your location until you resume.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
        }
    }
}
