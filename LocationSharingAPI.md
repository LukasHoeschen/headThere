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

**As of v2 (see "Shares" below), endpoint 3 (`PUT .../location/{forCode}`) now requires an active share from `myCode` to `forCode` — it returns `403` without one.** This is what makes sharing implicitly one-sided-to-start instead of requiring both people to add each other.

## v2: Shares — automatic, one-sided pairing

Originally, both people had to add each other's code for sharing to be mutual: A adding B only ever made A publish-to/fetch-from B; B only received A's location if B *also* manually added A. Now, adding someone (entering their code) is enough on its own — the other side is discovered and reciprocates automatically the next time their app syncs, no manual add needed from them.

This adds a third table, `code → { fromCode → nameCiphertext }` ("who is actively sending me their location, and what name did they encrypt for me"), and three endpoints:

### 5. Start sharing your location with someone

```
PUT /users/{fromCode}/share/{toCode}
Content-Type: application/json

{ "nameCiphertext": "<base64>" }

→ 200 OK
```

Called once when adding a person (after fetching their public key), and again whenever "Share my location" is toggled back on for them. `nameCiphertext` is your own display name (see `ownName` in `LocationIdentity`), AES-GCM encrypted with the same pairwise key as locations — so `toCode` can decrypt it and show "you're now receiving Alice's location" without the server ever seeing a plaintext name. Upsert, like endpoint 1.

### 6. Stop sharing your location with someone

```
DELETE /users/{fromCode}/share/{toCode}

→ 200 OK
```

Called when "Share my location" is toggled off for a person. Deletes the share row and the last location stored for that pair, so nothing stale remains fetchable afterwards. This does **not** affect the reverse direction — `toCode` may still be actively sharing back with `fromCode` independently.

### 7. Discover who is sharing with you

```
GET /users/{code}/shares

→ 200 OK
[
  { "fromCode": "...", "nameCiphertext": "<base64>", "createdAt": "2026-09-16T18:30:00Z" },
  ...
]
```

Polled alongside the location fetch. For every `fromCode` with no matching local entry yet, the app fetches their public key, decrypts `nameCiphertext` for a display name, and creates the person locally — this is the "automatic, no manual add needed" part. Once discovered, the relationship is symmetric: the app also starts sharing back (endpoint 5) unless the person later toggles that off.

### Two independent ways to stop sharing

- **"Share my location" toggle off** (endpoint 6) — stops *them* receiving *your* location. You keep receiving theirs.
- **Deleting the person locally** — stops *you* receiving *their* location (purely local; their share to you on the server is untouched until they also stop it). It does not call endpoint 6, so if you still have "Share my location" on for them, they keep receiving yours even after you delete them from your list — turn the toggle off first if you want both stopped.

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

- **Data model:** three tables/maps: `code → publicKey` (endpoint 1/2), `(code, forCode) → { ciphertext, timestamp }` (endpoint 3/4), and `(fromCode, toCode) → nameCiphertext` (endpoint 5/6/7, see `Server/migration_shares.sql`). No user login, no passwords — the code *is* the credential.
- **PHP reference implementation:** see `Server/*.php` in this repo — mirrors the live server's endpoints one-to-one (uses the same `db.php` helpers: `safeCode()`, `getJsonBody()`, `sendError()`, `sendSuccess()`, and a mysqli `$db`). All queries there use prepared statements (`$db->prepare()->bind_param()`), not string interpolation — worth keeping if `db.php`'s `safeCode()` is ever loosened, since two of the original four endpoints (`get_location.php`, `get_key.php`) built SQL by interpolating `$_GET` values with only `safeCode()` and no `real_escape_string()`.
- **Routing:** this repo only has the leaf PHP files, not whatever maps `users/{code}/key` etc. to them (`.htaccess`/front controller, not checked in here). The three new routes (`PUT`/`DELETE users/{fromCode}/share/{toCode}`, `GET users/{code}/shares`) need to be added there by hand, following the same pattern as the four existing routes.
- **Code length:** done — `LocationIdentity` generates 16 random characters (excluding 0/O/1/I/L to avoid confusion), no longer the old 8-character UUID-based ones.
- **Known bug (as of 2026-09-17):** `GET /users/{code}/key` returns `405 Method Not Allowed` on the live server (PUT on the same path works). Without a working GET, nobody can fetch another person's public key — the entire pairing handshake fails, even though the location endpoints (PUT/GET) already work correctly. Needs to be fixed on the server (routing for GET on this path is presumably missing).
- **No real live tracking:** this is polling, not push. "Good enough" is fine for this project; if real live updates are wanted later, the next step would be a simple WebSocket or a silent push notification that triggers a fetch — but that's v2, not needed now.
- **Cleanup:** periodically delete old entries (e.g. no update in > 30 days) so the database doesn't grow unbounded.
- **Rate limiting:** simple IP-based limiting is enough to make abuse/DoS harder — doesn't need to be elaborate.

## Status of the app-side implementation

The app side is implemented (see `LocationIdentity.swift`, `LocationSharingService.swift`, `KeychainStore.swift`): key generation + Keychain, all 4 endpoints including envelope handling, pairing via `compassto://pair?code=` links, periodic publish/fetch every 30s in `ContentView`. The server runs at `https://lukas.hoeschen.org/apps/compass-to/api/` (set as the default in Settings, changeable there too) — apart from the open GET-`/key` bug above, the location side has already been verified to work.
