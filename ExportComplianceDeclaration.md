# Encryption Use Declaration — HeadThere

**App name:** HeadThere (formerly "Compass to")
**Bundle ID:** org.hoeschen.lukas.Compass-to
**Developer:** Lukas Hoeschen

## Purpose of encryption in this app

HeadThere lets a user share their live location with specific contacts. Location
data is end-to-end encrypted on-device before it is sent to a relay server, so
the server only ever stores/forwards opaque ciphertext blobs and cannot read
any location data.

## Algorithms used

All cryptographic operations are performed using Apple's **CryptoKit**
framework (part of iOS/macOS), which implements only standard, publicly
documented, non-proprietary algorithms:

| Purpose | Algorithm | Standard reference |
|---|---|---|
| Key agreement (per-contact shared secret) | X25519 / Curve25519 ECDH | RFC 7748 |
| Key derivation | HKDF with SHA-256 | RFC 5869 |
| Symmetric encryption of location payloads | AES-256-GCM (authenticated encryption) | NIST SP 800-38D / FIPS 197 |
| Transport | Standard HTTPS/TLS (`URLSession`) | — |

- Key length for the symmetric cipher: 256 bits (AES-256).
- No proprietary, custom-designed, or non-standard cryptographic algorithms
  are implemented anywhere in the app. No algorithm has been modified from its
  published specification.
- The app does not implement its own cipher, hash function, or key-exchange
  protocol — it exclusively calls Apple's CryptoKit APIs (`Curve25519.KeyAgreement`,
  `HKDF`, `AES.GCM`), which ship as part of the operating system.
- The relay server component performs no cryptography at all; it stores and
  forwards ciphertext it cannot decrypt.

## Availability

This encryption functionality is used in all versions of the app distributed
worldwide, including France, and is not restricted to any particular customer
category. The app is intended for general/mass-market consumer use (personal
location sharing between family/friends), is publicly available for download,
and is not sold, customized, or licensed for any government, military, or
restricted end use.

## Classification basis

Because the app uses only standard, publicly available encryption algorithms
provided by Apple's operating system (CryptoKit) for confidentiality of
personal data, and is a mass-market consumer app, it is submitted for
export/import classification under the applicable "standard cryptographic
algorithm, mass-market" provisions (see U.S. EAR Category 5 Part 2, Note 4 /
License Exception ENC/TSU; and the French simplified declaration regime for
products implementing only standard, published algorithms).
