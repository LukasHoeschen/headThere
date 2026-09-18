import Foundation
import CryptoKit
import CoreLocation

enum LocationSharingError: Error {
    case noServerConfigured
    case invalidResponse
    case server(Int)
    case notFound
}

private struct PublicKeyPayload: Codable {
    let publicKey: String
}

private struct LocationPayload: Codable {
    let ciphertext: String
    let timestamp: String
}

/// The server wraps every response body in this envelope.
private struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let message: String?
}

/// Talks to the self-hosted relay server described in LocationSharingAPI.md.
/// The server only ever sees opaque ciphertext — all encryption/decryption happens
/// here, on-device, using a per-pair key derived via Curve25519 + HKDF.
struct LocationSharingService {
    let identity: LocationIdentity

    private var baseURL: URL? {
        let raw = UserDefaults.standard.string(forKey: "serverBaseURL")
            ?? "https://lukas.hoeschen.org/apps/headThere/api/"
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    // MARK: Key exchange

    func registerOwnPublicKey() async throws {
        guard let base = baseURL else { throw LocationSharingError.noServerConfigured }
        let url = base.appendingPathComponent("users/\(identity.ownCode)/key")
        let body = PublicKeyPayload(publicKey: identity.publicKeyData.base64EncodedString())
        try await put(body, to: url)
    }

    func fetchPublicKey(for code: String) async throws -> Data {
        guard let base = baseURL else { throw LocationSharingError.noServerConfigured }
        let url = base.appendingPathComponent("users/\(code)/key")
        let payload: PublicKeyPayload = try await get(url)
        guard let data = Data(base64Encoded: payload.publicKey) else { throw LocationSharingError.invalidResponse }
        return data
    }

    // MARK: Location publish/fetch

    /// Publishes my current location, encrypted specifically for one contact.
    /// Must be called once per person tracking me, since the encryption key is pairwise.
    func publishLocation(
        _ coordinate: CLLocationCoordinate2D,
        forPeerCode peerCode: String,
        peerPublicKey: Data
    ) async throws {
        guard let base = baseURL else { throw LocationSharingError.noServerConfigured }
        let key = try symmetricKey(peerPublicKeyData: peerPublicKey)
        let payload = try JSONEncoder().encode(["lat": coordinate.latitude, "lon": coordinate.longitude])
        let sealedBox = try AES.GCM.seal(payload, using: key)
        guard let combined = sealedBox.combined else { throw LocationSharingError.invalidResponse }

        let url = base.appendingPathComponent("users/\(identity.ownCode)/location/\(peerCode)")
        let body = LocationPayload(
            ciphertext: combined.base64EncodedString(),
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        try await put(body, to: url)
    }

    /// Fetches and decrypts the location a contact has published for me.
    /// Returns nil if they haven't published one yet.
    func fetchLocation(ownerCode: String, ownerPublicKey: Data) async throws -> CLLocationCoordinate2D? {
        guard let base = baseURL else { throw LocationSharingError.noServerConfigured }
        let url = base.appendingPathComponent("users/\(ownerCode)/location/\(identity.ownCode)")

        let payload: LocationPayload
        do {
            payload = try await get(url)
        } catch LocationSharingError.notFound {
            return nil
        }

        let key = try symmetricKey(peerPublicKeyData: ownerPublicKey)
        guard let combinedData = Data(base64Encoded: payload.ciphertext) else {
            throw LocationSharingError.invalidResponse
        }
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        let coords = try JSONDecoder().decode([String: Double].self, from: decrypted)
        guard let lat = coords["lat"], let lon = coords["lon"] else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: Crypto

    private func symmetricKey(peerPublicKeyData: Data) throws -> SymmetricKey {
        let peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKeyData)
        let sharedSecret = try identity.privateKey.sharedSecretFromKeyAgreement(with: peerKey)
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("compass-to-location-v1".utf8),
            sharedInfo: Data(),
            outputByteCount: 32
        )
    }

    // MARK: HTTP primitives

    private func put<T: Encodable>(_ body: T, to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LocationSharingError.server((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw LocationSharingError.invalidResponse }
        if http.statusCode == 404 { throw LocationSharingError.notFound }
        guard (200..<300).contains(http.statusCode) else { throw LocationSharingError.server(http.statusCode) }
        let envelope = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
        guard envelope.success, let payload = envelope.data else { throw LocationSharingError.notFound }
        return payload
    }
}
