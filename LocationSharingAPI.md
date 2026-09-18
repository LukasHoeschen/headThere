# Location Sharing: API Specification (v1)

## Why this approach and not another

- **Find My / "Where is?"** has no public API for reading another person's live location. Ruled out.
- **iCloud/CloudKit sharing (`CKShare`)** would be possible, but SwiftData doesn't support it directly (it only syncs *your own* data across *your own* devices). You'd have to build raw CloudKit plus an invitation UI, bypassing SwiftData. Unnecessarily complex for what we want.
- **A custom server** is the pragmatic route — but built so that the server itself **needs no cryptography**: it's just a "dumb" store for encrypted data blobs. The actual encryption happens entirely on the two iPhones. As a result:
  - the server is extremely simple (4 HTTP endpoints, no crypto library needed, regardless of what language it's written in),
  - the server operator (including you yourself, if the server gets hacked) can't read the locations — they only ever see ciphertext.

CryptoKit is used on the iPhone for this (built into iOS, no extra package needed). *Swift-crypto* would only be relevant if the server itself ran in Swift (e.g. Vapor) and also needed crypto code there — but that's not the case here, since the server never decrypts anything.

## Basic principle

Every person has a random **code** (this already exists in the app: `ShareCodeView` in `AddItemView.swift`). Additionally, every person has a **key pair** (Curve25519), stored only locally on the device (Keychain). Only the **code** is exchanged (e.g. via a Messages share). The server is then used once to exchange **public keys** (public keys are meant to be public — that's the whole point of Diffie-Hellman). Both sides locally compute the same secret key from that — it never travels over the network.

After that, each person encrypts their own location with this shared key and uploads it; the other person downloads it and decrypts it locally.

```
Person A                         Server (dumb, no crypto)                Person B
--------                         ---------------------------             --------
Generate keypair A                                                      Generate keypair B
PUT /users/{codeA}/key  ────────▶  stores publicKeyA
                                    ◀──────────  PUT /users/{codeB}/key   stores publicKeyB

GET /users/{codeB}/key ─────────▶  returns publicKeyB
                                    ◀──────────  GET /users/{codeA}/key   returns publicKeyA

sharedKey = ECDH(privA, pubB)                                           sharedKey = ECDH(privB, pubA)
   (== same key on both sides, without it ever being transmitted)

encrypts location with sharedKey, separately per counterpart
PUT /users/{codeA}/location/{codeB} ─▶  stores only ciphertext (overwrites the previous value for this pair)
                                    ◀────────── GET /users/{codeA}/location/{codeB}   (Person B fetches & decrypts)
```

## HTTP endpoints

Everything is JSON over HTTPS. `{code}` is the existing sharing code from the app. Live server: `https://lukas.hoeschen.org/apps/compass-to/api/`.

**Response format (what the server actually returns):** every response is wrapped in an envelope, not the raw object shown in the examples below:

```json
{ "success": true, "data": { ... actual payload as described below ... } }
```

or, on error:

```json
{ "success": false, "message": "..." }
```

The examples below show only the contents of `data`.

### 1. Publish public key

```
PUT /users/{code}/key
Content-Type: application/json

{ "publicKey": "<base64, 32 bytes>" }

→ 200 OK
```

Called once when the app starts, or when a new key is generated (e.g. after a reinstall). Overwrites any previously stored key for this code.

### 2. Fetch a person's public key

```
GET /users/{code}/key

→ 200 OK
{ "publicKey": "<base64, 32 bytes>" }

→ 404, if nothing has been stored for this code yet
```

Called once, right after entering the other person's code in "Add Person".

### 3. Publish your own (encrypted) location for a specific person

```
PUT /users/{myCode}/location/{forCode}
Content-Type: application/json

{
  "ciphertext": "<base64>",
  "timestamp": "2026-09-16T18:30:00Z"
}

→ 200 OK
```

**Important — why `{forCode}` is part of the path:** the location is encrypted with the shared key derived from `myCode` and `forCode` (see ECDH above) — that's a *pairwise* key. If the location were stored only once per `myCode` (without `forCode`), only exactly one counterpart could decrypt it. So if more than one person tracks you, you publish a separate, separately-encrypted entry for each of them.

`ciphertext` is the AES-GCM "combined" result (nonce + encrypted data + auth tag in one blob, see below) — the server doesn't need to understand the content, only store it. The server keeps **only the latest value** per (`myCode`, `forCode`) pair (no history needed, since it's about the current location).

### 4. Fetch a person's location (that they published for you)

```
GET /users/{ownerCode}/location/{myCode}

→ 200 OK
{
  "ciphertext": "<base64>",
  "timestamp": "2026-09-16T18:30:00Z"
}

→ 404, if this person hasn't published anything for you yet
```

Called periodically (e.g. every 30–60s, as long as the app is open/active in the background) to refresh the tracked person's location. `myCode` here is your own code (you're the recipient), `ownerCode` is the code of the person whose location you want to fetch.

## Cryptography on the iPhone (CryptoKit)

```swift
import CryptoKit

// 1. Once: generate your own key pair and store it in the Keychain
let privateKey = Curve25519.KeyAgreement.PrivateKey()
let publicKeyData = privateKey.publicKey.rawRepresentation   // → base64 for PUT /users/{code}/key

// 2. After entering the other person's code: fetch their public key (GET /users/{code}/key)
let peerPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKeyData)

// 3. Compute the shared key (identical on both devices, never transmitted)
let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: "compass-to-location-v1".data(using: .utf8)!,
    sharedInfo: Data(),
    outputByteCount: 32
)

// 4. Encrypt your own location (before PUT /users/{code}/location)
let payload = try JSONEncoder().encode(["lat": lat, "lon": lon])
let sealedBox = try AES.GCM.seal(payload, using: symmetricKey)
let ciphertextBase64 = sealedBox.combined!.base64EncodedString()   // → "ciphertext" field

// 5. Decrypt the other person's location (after GET /users/{code}/location)
let sealedBoxIn = try AES.GCM.SealedBox(combined: Data(base64Encoded: ciphertextBase64)!)
let decrypted = try AES.GCM.open(sealedBoxIn, using: symmetricKey)
let location = try JSONDecoder().decode([String: Double].self, from: decrypted)
```

The `symmetricKey` is cached locally in the Keychain (per contact/code), so steps 1–3 don't need to be repeated on every location update.

## Notes for the server implementation

- **Data model:** two tables/maps: `code → publicKey` (from endpoint 1/2) and `(code, forCode) → { ciphertext, timestamp }` (from endpoint 3/4). No user login, no passwords — the code *is* the credential.
- **Code length:** done — `LocationIdentity` generates 16 random characters (excluding 0/O/1/I/L to avoid confusion), no longer the old 8-character UUID-based ones.
- **Known bug (as of 2026-09-17):** `GET /users/{code}/key` returns `405 Method Not Allowed` on the live server (PUT on the same path works). Without a working GET, nobody can fetch another person's public key — the entire pairing handshake fails, even though the location endpoints (PUT/GET) already work correctly. Needs to be fixed on the server (routing for GET on this path is presumably missing).
- **No real live tracking:** this is polling, not push. "Good enough" is fine for this project; if real live updates are wanted later, the next step would be a simple WebSocket or a silent push notification that triggers a fetch — but that's v2, not needed now.
- **Cleanup:** periodically delete old entries (e.g. no update in > 30 days) so the database doesn't grow unbounded.
- **Rate limiting:** simple IP-based limiting is enough to make abuse/DoS harder — doesn't need to be elaborate.

## Status of the app-side implementation

The app side is implemented (see `LocationIdentity.swift`, `LocationSharingService.swift`, `KeychainStore.swift`): key generation + Keychain, all 4 endpoints including envelope handling, pairing via `compassto://pair?code=` links, periodic publish/fetch every 30s in `ContentView`. The server runs at `https://lukas.hoeschen.org/apps/compass-to/api/` (set as the default in Settings, changeable there too) — apart from the open GET-`/key` bug above, the location side has already been verified to work.
