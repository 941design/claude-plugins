# Signing-Related NIPs Reference

## NIP-01: Basic Protocol (Foundation)

- Every Nostr user has a secp256k1 keypair (32-byte private, 32-byte public)
- Event ID: SHA-256 of canonical JSON `[0, pubkey, created_at, kind, tags, content]`
- Signature: 64-byte BIP-340 Schnorr signature over the event ID
- This defines the exact signing operation that NIP-46 remote signers perform

## NIP-07: Browser Extension Signing (window.nostr)

**Status:** Standard, Optional

Required methods:
```typescript
interface WindowNostr {
    getPublicKey(): Promise<string>;           // Returns hex pubkey
    signEvent(event: UnsignedEvent): Promise<SignedEvent>;  // Signs event
}
```

Optional methods:
```typescript
interface WindowNostr {
    nip04?: {                                   // DEPRECATED
        encrypt(pubkey: string, plaintext: string): Promise<string>;
        decrypt(pubkey: string, ciphertext: string): Promise<string>;
    };
    nip44?: {                                   // Modern encryption
        encrypt(pubkey: string, plaintext: string): Promise<string>;
        decrypt(pubkey: string, ciphertext: string): Promise<string>;
    };
}
```

- Extension holds private key, performs signing locally
- Web page never has access to the private key
- Extensions should set `"run_at": "document_end"` in manifest
- Limited to web browsers — cannot be used on mobile or native apps
- Popular extensions: nos2x, Alby, nostr-keyx

## NIP-55: Android Signer Application

**Status:** Standard

Two communication mechanisms:

### Intents (Interactive)

Uses `nostrsigner:` URI scheme. Key methods:

| Method | Intent Data | Returns |
|--------|------------|---------|
| `get_public_key` | (none) | pubkey + packageName |
| `sign_event` | Event JSON | signature + signed event |
| `nip04_encrypt` | Plaintext | Ciphertext |
| `nip04_decrypt` | Ciphertext | Plaintext |
| `nip44_encrypt` | Plaintext | Ciphertext |
| `nip44_decrypt` | Ciphertext | Plaintext |
| `decrypt_zap_event` | Event JSON | Decrypted event |

Detection: resolve Intent with `nostrsigner` scheme in AndroidManifest.xml:
```xml
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="nostrsigner" />
    </intent>
</queries>
```

### Content Resolvers (Background)

For pre-authorized operations without user interaction:
- URI: `content://com.example.signer.OPERATION_TYPE`
- Parameters passed as projection array
- Returns null if not pre-authorized

### Web Integration

```
nostrsigner:<data>?type=<method>&pubKey=<hex>&callbackUrl=<url>&returnType=<signature|event>
```

## NIP-44: Versioned Encryption (v2)

**Status:** Standard

Powers the NIP-46 transport layer:

- **Key Exchange:** secp256k1 ECDH
- **Key Derivation:** HKDF-SHA256 (salt: `nip44-v2`)
- **Cipher:** ChaCha20 (RFC 8439)
- **Authentication:** HMAC-SHA256 over nonce + ciphertext
- **Padding:** Power-of-two scheme, min 32 bytes, max 65,535
- **Payload:** version (1B) || nonce (32B) || ciphertext || MAC (32B), base64

**Limitations:** No forward secrecy, no deniability, no post-quantum security.

## NIP-49: Private Key Encryption (ncryptsec)

**Status:** Standard

Encrypts private keys with a password for storage/transport:

- **KDF:** scrypt (LOG_N 16–22, r=8, p=1, 16-byte random salt)
- **Cipher:** XChaCha20-Poly1305 with 24-byte random nonce
- **Password:** NFKC Unicode normalized
- **Key security byte:** 0x00 (insecure handling), 0x01 (secure), 0x02 (unknown)
- **Output:** bech32 `ncryptsec1...` (91 bytes pre-encoding)
- **LOG_N cost:** 16 = 64 MiB ~100ms, 20 = 1 GiB ~2s, 22 = 4 GiB

Security: Zero symmetric key after use. Do NOT publish encrypted keys to
relays (enables offline brute-force).

## NIP-19: Bech32-Encoded Entities

**Status:** Standard

| Prefix | Content | Bytes |
|--------|---------|-------|
| `npub` | Public key | 32 |
| `nsec` | Private key | 32 |
| `note` | Event ID | 32 |
| `nprofile` | Pubkey + relay hints | TLV |
| `nevent` | Event ref + metadata | TLV |
| `naddr` | Addressable event | TLV |

**Critical:** `npub`/`nsec` are for display/QR/user input ONLY. Use hex
format in NIP-01 events and NIP-05 JSON.

## NIP-06: Mnemonic Key Derivation

**Status:** Standard

- BIP-39 mnemonic → BIP-32 HD derivation
- Path: `m/44'/1237'/<account>'/0/0`
- 1237 = Nostr's SLIP-44 coin type
- Deterministic: same mnemonic always produces same keypair

## NIP-26: Delegated Event Signing

**Status: UNRECOMMENDED** — superseded by NIP-46

- Delegation tag: `["delegation", delegator_pubkey, conditions, token]`
- Conditions: `kind=<n>&created_at<N&created_at>N`
- No revocation mechanism
- NIP-46 is preferred: events look identical to self-signed, no extra tags
  needed, revocation is immediate (disconnect session)

## NIP-59: Gift Wrap

**Status:** Standard

Three-layer encryption for metadata-private communication:

1. **Rumor** — unsigned event (plausible deniability)
2. **Seal (kind 13)** — NIP-44 encrypts rumor to receiver, signed by sender
3. **Gift Wrap (kind 1059)** — NIP-44 encrypts seal with ephemeral key

Used by NIP-17 (private DMs). Remote signers handling DMs must support the
full wrap/unwrap flow via `nip44_encrypt`, `nip44_decrypt`, and `sign_event`.

## NIP-42: Relay Authentication

**Status:** Standard

- Relay sends `["AUTH", <challenge>]`
- Client signs kind `22242` event with challenge + relay URL tags
- If relay auth requires the USER's identity, client must ask remote signer
  to sign the auth event via `sign_event`

## NIP-98: HTTP Authentication

**Status:** Standard

- Kind `27235` events as Bearer tokens in Authorization headers
- Tags: `["u", URL]`, `["method", HTTP-verb]`, optional `["payload", SHA-256]`
- `Authorization: Nostr <base64-signed-event>`
- Remote signer can sign NIP-98 events for authenticated web requests

## NIP-0b: Sub-Key Management (PROPOSED — PR #1482)

- Sub-keys publish with `b` tag referencing master pubkey
- Master maintains kind `10100` event listing authorized sub-keys
- Attestation states: active, inactive, revoked
- Not merged; significant technical concerns remain

## NIP-41: Key Rotation (PROPOSED)

- Kind `1776` events for pubkey whitelisting
- Only one active sub-key at a time
- Exists only as a branch, not merged

## Method Parity Across Signing NIPs

| Operation | NIP-07 | NIP-46 | NIP-55 |
|-----------|--------|--------|--------|
| Get public key | `getPublicKey()` | `get_public_key` | `get_public_key` intent |
| Sign event | `signEvent()` | `sign_event` | `sign_event` intent |
| NIP-04 encrypt | `nip04.encrypt()` | `nip04_encrypt` | `nip04_encrypt` intent |
| NIP-04 decrypt | `nip04.decrypt()` | `nip04_decrypt` | `nip04_decrypt` intent |
| NIP-44 encrypt | `nip44.encrypt()` | `nip44_encrypt` | `nip44_encrypt` intent |
| NIP-44 decrypt | `nip44.decrypt()` | `nip44_decrypt` | `nip44_decrypt` intent |
| Ping | N/A | `ping` | N/A |
| Switch relays | N/A | `switch_relays` | N/A |
| Decrypt zap | N/A | N/A | `decrypt_zap_event` |
