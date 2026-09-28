import Foundation
import CryptoKit
import Observation

/// This device's own pairing identity: a long random sharing code plus a
/// Curve25519 key pair, persisted in the Keychain so it survives relaunches.
@Observable
final class LocationIdentity {
    private static let codeKey = "compassto.ownCode"
    private static let privateKeyKey = "compassto.ownPrivateKey"
    private static let nameKey = "compassto.ownName"

    private(set) var ownCode: String
    private(set) var privateKey: Curve25519.KeyAgreement.PrivateKey

    // Not a secret, just how we present ourselves to people we share with —
    // sent (encrypted) alongside shares so they know who's tracking/tracked.
    var ownName: String {
        didSet { UserDefaults.standard.set(ownName, forKey: Self.nameKey) }
    }

    var publicKeyData: Data { privateKey.publicKey.rawRepresentation }

    init() {
        ownName = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        if let data = KeychainStore.load(for: Self.privateKeyKey),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) {
            privateKey = key
        } else {
            let key = Curve25519.KeyAgreement.PrivateKey()
            KeychainStore.save(key.rawRepresentation, for: Self.privateKeyKey)
            privateKey = key
        }

        if let codeData = KeychainStore.load(for: Self.codeKey),
           let code = String(data: codeData, encoding: .utf8) {
            ownCode = code
        } else {
            let code = Self.generateCode()
            KeychainStore.save(Data(code.utf8), for: Self.codeKey)
            ownCode = code
        }
    }

    /// Wipes this device's identity (code, keypair, name) and generates a brand
    /// new one in place — no relaunch needed. People who had the old code can no
    /// longer reach this device; used for the "Reset Location Sharing" debug flow.
    func regenerate() {
        KeychainStore.delete(for: Self.privateKeyKey)
        KeychainStore.delete(for: Self.codeKey)

        let key = Curve25519.KeyAgreement.PrivateKey()
        KeychainStore.save(key.rawRepresentation, for: Self.privateKeyKey)
        privateKey = key

        let code = Self.generateCode()
        KeychainStore.save(Data(code.utf8), for: Self.codeKey)
        ownCode = code

        ownName = ""
    }

    // Excludes visually ambiguous characters (0/O, 1/I/L) since the code can
    // still be read out or typed by hand as a fallback to the share link.
    private static func generateCode(length: Int = 16) -> String {
        let chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
