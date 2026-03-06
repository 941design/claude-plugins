# MIP Specifications

## Overview

| MIP | Title | Status | Required? |
|-----|-------|--------|-----------|
| MIP-00 | Credentials & Key Packages | Review | Yes |
| MIP-01 | Group Construction & Marmot Group Data Extension | Review | Yes |
| MIP-02 | Welcome Events | Review | Yes |
| MIP-03 | Group Messages | Review | Yes |
| MIP-04 | Encrypted Media | Review | No |
| MIP-05 | Push Notifications | Draft | No |

---

## MIP-00: Credentials & Key Packages

Defines identity and key distribution.

### Credential Format

- **Type:** `BasicCredential`
- **Content:** Raw 32-byte Nostr public key (secp256k1)
- **Signing key:** Separate from Nostr identity key, rotated regularly

### KeyPackage Structure

Each KeyPackage contains:
- A BasicCredential with the Nostr public key
- A unique Ed25519 signing key (rotated per package)
- Capability advertisements including required extensions
- GREASE values injected per RFC 9420 Section 13.5

### Nostr Publication

- Published as kind **443** events, base64-encoded with TLS serialization
- `i` tag contains hex-encoded `KeyPackageRef` (hash per RFC 9420 §17.1)
- Optional `-` tag (NIP-70) for protected events
- Relay locations advertised via kind **10051** events

---

## MIP-01: Group Construction

Defines group creation and the Marmot Group Data Extension.

### Group IDs

Two random 32-byte identifiers:
- **MLS group ID** — internal, used by the MLS layer
- **nostr_group_id** — external, used for relay routing (`h` tag)

### Marmot Group Data Extension (0xF2EE)

Embedded in the MLS GroupContext:

```
version:          uint16 (currently 2)
nostr_group_id:   32 bytes
name:             UTF-8, length-prefixed
description:      UTF-8, length-prefixed
admin_pubkeys:    concatenated raw 32-byte secp256k1 keys
relays:           individually length-prefixed WebSocket URLs
image_hash:       optional, 32 bytes (SHA-256)
image_key:        optional, 32 bytes
image_nonce:      optional, 12 bytes
image_upload_key: optional, 32 bytes
```

### Required Extensions

Groups must include three MLS extensions:
1. `required_capabilities`
2. `ratchet_tree`
3. `marmot_group_data` (0xF2EE)

### Encoding Versions

- **v1:** Fixed 16-bit length prefixes
- **v2:** QUIC-style variable-length integers (current)

---

## MIP-02: Welcome Events

Defines member invitation flow.

### Invitation Sequence

1. Admin creates an MLS Commit adding the new member
2. Admin publishes the Commit to relays as kind 445
3. **Admin waits for relay acknowledgment** (critical ordering)
4. Admin sends kind **444** Welcome Event via NIP-59 gift-wrapping
5. Welcome Events are **intentionally unsigned** (prevents accidental public
   relay leakage)

### New Member Processing

1. Process the Welcome message
2. Join the group
3. Delete `init_key` material
4. Perform a **self-update within 24 hours** (rotate key material)

---

## MIP-03: Group Messages

Defines encrypted messaging and state evolution.

### Message Encryption (Double Layer)

**Inner layer (MLS):**
- Standard MLS group encryption
- Forward secrecy, post-compromise security, sender authentication

**Outer layer (ChaCha20-Poly1305):**
```
exporter_secret = MLS-Exporter("marmot", "group-event", 32)
nonce = random 12 bytes
content = base64(nonce || ciphertext)
```

### Event Construction

- Application messages (kind 9 chat, kind 7 reactions) are wrapped as
  unsigned Nostr events ("rumors")
- Rumors are MLS-encrypted, then ChaCha20 encrypted
- Published as kind **445** events with **ephemeral secp256k1 keypairs**
  (never reused)
- `h` tag contains `nostr_group_id` for relay routing

### State Evolution

- **Proposals:** Any member can propose changes
- **Commits:** Only admins can apply non-self-update Commits
- **Self-updates:** Any member can rotate their own key material

### Commit Race Resolution

When multiple Commits target the same epoch:
1. Earliest `created_at` wins
2. Ties broken by lexicographically smallest event `id`
3. Clients maintain epoch snapshots for rollback
4. If a better Commit arrives after one is applied, rollback and re-apply

---

## MIP-04: Encrypted Media (Optional)

Defines encrypted file/image sharing.

### Encryption

- **Algorithm:** ChaCha20-Poly1305
- **Key derivation:** HKDF from a random seed
- **Nonce:** Random 12 bytes per file

### Storage

- Uses **Blossom** protocol (HTTP blob storage addressed by SHA-256 hash)
- Upload authentication via Nostr NIP-98 signatures
- Supports mirroring across multiple Blossom servers

### Metadata

Encrypted media metadata is embedded in the Marmot Group Data Extension:
- `image_hash` — SHA-256 of the encrypted blob
- `image_key` — encryption seed
- `image_nonce` — ChaCha20 nonce
- `image_upload_key` — Blossom upload authentication seed

---

## MIP-05: Push Notifications (Draft)

Status: Draft. Not yet finalized.

Defines how push notifications can be delivered for group messages without
exposing message content to notification services.
