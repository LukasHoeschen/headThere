import SwiftUI

// MARK: - Share code view

struct ShareCodeView: View {
    @Environment(LocationIdentity.self) private var identity

    private var pairingURL: URL {
        URL(string: "compassto://pair?code=\(identity.ownCode)")!
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Code").font(.caption).foregroundStyle(.secondary)
                Text(identity.ownCode).font(.system(.body, design: .monospaced)).bold()
            }
            Spacer()
            ShareLink(
                item: pairingURL,
                subject: Text("Compass To"),
                message: Text("Add me in Compass To so we can share locations.")
            ) {
                Label("Share My Code", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
    }
}
