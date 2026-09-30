import SwiftUI

struct SettingsView: View {
    @AppStorage("zoomBarOnLeft") private var zoomBarOnLeft: Bool = false
    @AppStorage("useMiles") private var useMiles: Bool = false
    @AppStorage("isPro") private var isPro: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var purchaseManager

    @State private var showPaywall = false

    private let privacyPolicyURL = URL(string: "https://lukas.hoeschen.org/apps/headThere/privacy.html")!
    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            Form {
                if !isPro {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("HeadThere Pro", systemImage: "location.north.circle.fill")
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
                        Text("Places are always free and unlimited. Free includes \(freePersonLimit) person — Pro unlocks unlimited people.")
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

                Section("Legal") {
                    Link(destination: privacyPolicyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: eulaURL) {
                        Label("Terms of Use (EULA)", systemImage: "doc.text")
                    }
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
