import Foundation
import Observation

/// Picks up incoming `compassto://pair?code=XXXX` links (see the ShareLink in
/// AddItemView) and hands the code to whoever is showing the "add person" flow.
@Observable
final class PairingRouter {
    var pendingCode: String?

    func handle(_ url: URL) {
        guard url.scheme == "compassto", url.host == "pair" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { return }
        pendingCode = code
    }
}
