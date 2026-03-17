# NIP-46: Remote Signing Protocol

## Overview

NIP-46 establishes a protocol for secure two-way communication between a
**remote signer** (bunker) and a **client** application. The private key never
leaves the signer; signing requests are sent over Nostr relays as NIP-44
encrypted kind `24133` events.

## Entities and Keypairs

| Keypair | Holder | Purpose |
|---------|--------|---------|
| **Client keypair** | App | Ephemeral/disposable, encrypts communication channel |
| **Remote-signer keypair** | Bunker | Encrypts responses to client |
| **User keypair** | Bunker | The actual Nostr identity — signs events |

The client keypair is disposable and does not need to be communicated to the
user. The remote-signer keypair is NOT necessarily the same as the user keypair.

## Event Kind and Encryption

- Kind: **24133** (both requests and responses)
- Content: **NIP-44 encrypted** (upgraded from NIP-04; some older
  implementations may still use NIP-04)
- Tags: `["p", "<recipient-pubkey>"]`

## Request Format

```json
{
    "kind": 24133,
    "pubkey": "<client-keypair-pubkey>",
    "content": "<NIP-44-encrypted-payload>",
    "tags": [["p", "<remote-signer-pubkey>"]],
    "created_at": "<unix_timestamp>"
}
```

Decrypted payload (JSON-RPC-like):

```json
{
    "id": "<random_string>",
    "method": "<method_name>",
    "params": ["<param1>", "<param2>"]
}
```

## Response Format

```json
{
    "id": "<matching_request_id>",
    "result": "<result_string>",
    "error": "<optional_error_string>"
}
```

## Defined Methods

| Method | Parameters | Response | Description |
|--------|-----------|----------|-------------|
| `connect` | `[signer-pubkey, secret?, perms?]` | `"ack"` | Establish connection |
| `sign_event` | `[unsigned_event_json]` | Signed event JSON | Sign a Nostr event |
| `get_public_key` | `[]` | Hex pubkey | Get user's public key |
| `ping` | `[]` | `"pong"` | Health check |
| `nip04_encrypt` | `[third-party-pubkey, plaintext]` | Ciphertext | NIP-04 encrypt for third party |
| `nip04_decrypt` | `[third-party-pubkey, ciphertext]` | Plaintext | NIP-04 decrypt from third party |
| `nip44_encrypt` | `[third-party-pubkey, plaintext]` | Ciphertext | NIP-44 encrypt for third party |
| `nip44_decrypt` | `[third-party-pubkey, ciphertext]` | Plaintext | NIP-44 decrypt from third party |
| `switch_relays` | `[]` | Relay array or null | Update relay list |

**Important:** The encrypt/decrypt methods perform *application-level*
operations on behalf of the user (e.g., DMs). This is separate from the NIP-44
encryption on the kind 24133 transport layer.

## Connection Flow 1: Bunker-Initiated (bunker:// URI)

```
bunker://<remote-signer-pubkey>?relay=<wss://relay1>&relay=<wss://relay2>&secret=<token>
```

1. Signer generates `bunker://` URI with its pubkey, relays, and secret
2. User pastes URI into client application
3. Client parses URI, generates fresh ephemeral client keypair
4. Client connects to specified relays, subscribes to kind 24133 for its pubkey
5. Client sends `connect` request with the secret
6. Signer validates secret, responds with `"ack"`
7. Connection established

## Connection Flow 2: Client-Initiated (nostrconnect:// URI)

```
nostrconnect://<client-pubkey>?relay=<wss://relay>&secret=<random>&perms=<perms>&name=<app>&url=<url>&image=<icon>
```

Parameters:
- `relay` (required): Communication relay URLs
- `secret` (required): Random string to prevent spoofing
- `perms` (optional): Comma-separated permissions (`method[:param]`)
- `name`, `url`, `image` (optional): App metadata

1. Client generates keypair + random secret + URI
2. Client displays URI (or QR code) or redirects to signer's auth URL
3. Signer connects and sends `connect` response containing the secret
4. Client validates secret match
5. Client sends `switch_relays` request (signer may prefer different relays)
6. Connection established

## Auth Challenge Flow

When the signer needs user authorization:

1. Client sends request (e.g., `sign_event`)
2. Signer responds with `{"result": "auth_url", "error": "<URL>"}`
3. Client displays the URL (do NOT auto-open popups)
4. User visits URL and approves on signer's web interface
5. Signer sends actual response with the **same request `id`**

Handle duplicate `auth_url` messages gracefully; only show URL once.

## Discovery

### NIP-05

```
GET https://domain.com/.well-known/nostr.json?name=_
```

Response includes `nip46` field:
```json
{
    "names": {"_": "<remote-signer-pubkey>"},
    "nip46": {
        "relays": ["wss://relay1.example.com"],
        "nostrconnect_url": "https://domain.com/<nostrconnect-path>"
    }
}
```

### NIP-89

Kind `31990` events with `k` tag `"24133"` advertise NIP-46 capability.

## Permissions Model

Format: `method[:params]` comma-separated.

- `sign_event` — any event
- `sign_event:1` — kind 1 only
- `nip44_encrypt` — NIP-44 encryption
- `nip04_decrypt` — NIP-04 decryption

The `perms` parameter in connection URIs is a *request*; the signer may grant
a subset.

## Relay Requirements

- Remote signer controls which relays are used
- Client-initiated connections: client MUST send `switch_relays` immediately
- Clients should periodically call `switch_relays`
- Dedicated NIP-46 relays recommended (avoid rate limiting)
- Handle relay disconnects: reconnect + re-subscribe

## Security Considerations

1. **Key isolation**: User private key never leaves the signer
2. **Single-use secrets**: Signer SHOULD reject reused secrets
3. **NIP-44 encryption**: Authenticated encryption on transport layer
4. **No forward secrecy**: NIP-44 limitation — compromised key reveals past
5. **No deniability**: Messages provably from a specific sender
6. **Relay metadata**: Relays see traffic patterns but not content
7. **Auth URL safety**: Display URLs to users; don't silently navigate
8. **Ephemeral client keys**: Treat as disposable; not user identity
