import SwiftUI
import SwiftData

/// Everything about how person-to-person sharing works, plus the controls that
/// used to live in Settings — moved here since it's specifically about the
/// "People" part of the list, not a general app setting.
struct LocationSharingInfoView: View {
    @AppStorage("locationSharingEnabled") private var locationSharingEnabled: Bool = true
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationIdentity.self) private var identity
    @Query private var items: [TrackedItem]

    @State private var showResetConfirm = false

    private var pairingURL: URL {
        URL(string: "compassto://pair?code=\(identity.ownCode)")!
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("My Code") {
                    Text(identity.ownCode)
                        .font(.system(.body, design: .monospaced))
                }
                TextField(
                    "Your Name",
                    text: Binding(
                        get: { identity.ownName },
                        set: { identity.ownName = $0 }
                    )
                )
                ShareLink(
                    item: pairingURL,
                    subject: Text("HeadThere"),
                    message: Text("Add me in HeadThere so we can share locations.")
                ) {
                    Label("Share My Invite Link", systemImage: "square.and.arrow.up")
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
            } footer: {
                Text("Your name is sent (encrypted) to people you share with, so they know who's sharing. Stopping sharing here pauses sending your location to everyone until you resume.")
            }

            Section("How it works") {
                VStack(alignment: .leading, spacing: 12) {
                    explanation(
                        icon: "link",
                        title: "Adding someone",
                        text: "You can only add a person by opening their invite link — nobody types the long code by hand. Opening it starts sharing your location with them right away, and you automatically start receiving theirs too, without them doing anything on their end."
                    )
                    explanation(
                        icon: "location.slash",
                        title: "\"Share My Location\" toggle (on a person)",
                        text: "Turns off only your sending to that person. You keep receiving their location until you separately remove them."
                    )
                    explanation(
                        icon: "trash",
                        title: "Removing a person from your list",
                        text: "Stops both directions at once: you stop receiving their location, and they stop receiving yours."
                    )
                    explanation(
                        icon: "exclamationmark.triangle",
                        title: "\"No longer receiving\"",
                        text: "Shown when someone you were receiving turns their sharing off (or removes you). They disappear from the compass and map so you're never shown an outdated location as if it were current."
                    )
                }
                .padding(.vertical, 4)
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset Location Sharing", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Removes everyone you're tracking and generates a brand new code and name. People who had your old code can no longer reach you with it.")
            }
        }
        .navigationTitle("Location Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Location Sharing?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { performReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes everyone you're tracking and generates a brand new code and name. People who had your old code can no longer reach you with it. This can't be undone.")
        }
    }

    @ViewBuilder
    private func explanation(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func performReset() {
        for item in items where item.type == .person {
            modelContext.delete(item)
        }
        identity.regenerate()
        Task {
            do {
                try await LocationSharingService(identity: identity).registerOwnPublicKey()
                print("[App][LocationSharingInfoView] registered new public key after reset")
            } catch {
                print("[App][LocationSharingInfoView] failed to register new public key after reset: \(error)")
            }
        }
    }
}
