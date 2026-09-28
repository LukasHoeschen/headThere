import Foundation
import Observation

/// Picks up incoming `compassto://pair?code=XXXX` links (see the ShareLink in
/// AddItemView) and hands the code to whoever is showing the "add person" flow.
@Observable
final class PairingRouter {
    var pendingCode: String?

    func handle(_ url: URL) {
        print("[App][PairingRouter] handling url: \(url)")
        guard url.scheme == "compassto", url.host == "pair" else {
            print("[App][PairingRouter] url scheme/host didn't match compassto://pair, ignoring")
            return
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            print("[App][PairingRouter] couldn't extract non-empty code query item, ignoring")
            return
        }
        print("[App][PairingRouter] extracted code: \(code)")
        pendingCode = code
    }
}
