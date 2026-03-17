# Libraries and SDKs

## Overview

| Library | Platform | NIP Support | Best For |
|---------|----------|-------------|----------|
| **nostr-tools** | JS/TS | 07, 46 | Low-level control |
| **NDK** | TS, Dart, React Native | 07, 46, 55 (Dart) | Full-featured framework |
| **nostr-login** | JS (drop-in) | 07, 46 | Complete login widget |
| **nostr-signer-connector** | TS | 07, 46, 49 | Unified signer interface |
| **Nostrify** | TS (JSR) | 07, 46 | Standard interfaces |
| **rust-nostr** | Rust | 46, 55 | Desktop/backend |

---

## nostr-tools (nbd-wtf/nostr-tools)

- **Repo:** https://github.com/nbd-wtf/nostr-tools
- **npm:** `nostr-tools` / **JSR:** `@nostr/tools`
- **Requires:** TypeScript >= 5.0

### NIP-46 Support

Available via `@nostr/tools/nip46` or `nostr-tools/nip46`:

- `BunkerSigner` — NIP-46 remote signer client
- `createNostrConnectURI()` — generate nostrconnect:// URIs
- Supports both client-initiated and bunker-initiated flows

### NIP-07 Support

```typescript
import { nip07 } from 'nostr-tools'
// window.nostr methods available through nip07 helpers
```

### Characteristics

- Low-level, maximum control over implementation details
- No opinion on state management or UI
- Good for custom integrations

---

## NDK (Nostr Development Kit)

- **Repo:** https://github.com/nostr-dev-kit/ndk
- **Monorepo:** TypeScript, Dart, React Native

### Signer Adapters

| Signer | Class | Platform |
|--------|-------|----------|
| Private key | `NDKPrivateKeySigner` | All |
| NIP-07 extension | `NDKNip07Signer` | Browser |
| NIP-46 remote | `NDKNip46Signer` | All |
| Amber (NIP-55) | Dart implementation | Android |
| BIP-340 built-in | Dart implementation | All |

### NIP-46 Usage

```typescript
import NDK from '@nostr-dev-kit/ndk'
import { NDKNip46Signer } from '@nostr-dev-kit/ndk'

const ndk = new NDK({ explicitRelayUrls: ['wss://relay.example.com'] })
await ndk.connect()

// From bunker:// URI
const signer = new NDKNip46Signer(ndk, bunkerPubkey, {
    relayUrls: ['wss://relay.nsecbunker.com'],
    secret: 'the-secret'
})
await signer.blockUntilReady()

ndk.signer = signer
```

### Characteristics

- Higher-level abstraction than nostr-tools
- Includes outbox model, caching, relay management
- NDK Mobile provides React Native implementations
- Dart version has NIP-55 (Amber) support

---

## nostr-login (nostrband)

- **Repo:** https://github.com/nostrband/nostr-login
- **Website:** https://nostrlogin.org/

### Drop-in Integration

```html
<script src="https://www.unpkg.com/nostr-login@latest/dist/unpkg.js"
  data-dark-mode="true"
  data-bunkers="nsec.app,highlighter.com"
  data-perms="sign_event:1,nip44_encrypt"
  data-methods="extension,connect,readOnly">
</script>
```

### Features

- Unified login widget supporting multiple methods
- Extension login (NIP-07)
- Nostr Connect login (NIP-46)
- Read-only login (npub only)
- Account switching between multiple identities
- OAuth-like sign-up flow for new users
- **Provides `window.nostr` polyfill** — existing NIP-07 code works unchanged
- Customizable via HTML data attributes

### Configuration Attributes

| Attribute | Purpose |
|-----------|---------|
| `data-dark-mode` | Enable dark theme |
| `data-bunkers` | Comma-separated bunker provider domains |
| `data-perms` | NIP-46 permissions to request |
| `data-methods` | Allowed login methods |
| `data-theme` | Custom CSS theme |

### Best For

Applications wanting complete authentication UI out of the box with zero
custom code for the login flow.

---

## nostr-signer-connector (jiftechnify)

- **Repo:** https://github.com/jiftechnify/nostr-signer-connector

### Unified Interface

```typescript
interface NostrSigner {
    getPublicKey(): Promise<string>
    signEvent(event: UnsignedEvent): Promise<SignedEvent>
    nip04Encrypt(pubkey: string, plaintext: string): Promise<string>
    nip04Decrypt(pubkey: string, ciphertext: string): Promise<string>
    nip44Encrypt(pubkey: string, plaintext: string): Promise<string>
    nip44Decrypt(pubkey: string, ciphertext: string): Promise<string>
    getRelays?(): Promise<Record<string, RelayPolicy>>
}
```

### Signer Types

| Class | Source |
|-------|--------|
| `SecretKeySigner` | Raw private key or ncryptsec (NIP-49) |
| `Nip07ExtensionSigner` | Browser extension (window.nostr) |
| `Nip46RemoteSigner` | NIP-46 bunker connection |

### NIP-49 Support

```typescript
import { SecretKeySigner } from 'nostr-signer-connector'

// Import from ncryptsec
const signer = await SecretKeySigner.fromEncryptedKey(ncryptsecString, password)
```

### Session Persistence

Supports session persistence and resumption for NIP-46 connections — can
reconnect without requiring the user to re-approve.

---

## Nostrify

- **Docs:** https://nostrify.dev/sign/connect
- **JSR:** `@nostrify/nostrify`

### Signer Interface

Modeled directly on NIP-07 (`NostrSigner`):
```typescript
interface NostrSigner {
    getPublicKey(): Promise<string>
    signEvent(event: EventTemplate): Promise<NostrEvent>
    nip04?: NIP04Signer
    nip44?: NIP44Signer
}
```

### NConnectSigner

```typescript
import { NConnectSigner } from '@nostrify/nostrify'

const signer = new NConnectSigner({
    relay: pool, // NostrRelay or pool instance
    pubkey: remoteSigner Pubkey,
    signer: clientSigner, // ephemeral keypair
})
```

### Characteristics

- Standard interfaces so implementations are swappable
- Includes relay management, event stores, other building blocks
- TypeScript-first, JSR distribution

---

## rust-nostr

- **Repo:** https://github.com/rust-nostr/nostr
- **Crate:** `nostr-sdk`

### Features

- NIP-46 signer support
- Android signer library for NIP-55
- Cross-compilation targets
- Suitable for desktop apps, backend services, CLI tools

---

## Nostr Connect SDK

- **Repo:** https://github.com/nostr-connect/connect
- TypeScript SDK specifically for NIP-46 integration
- Focused implementation for Nostr Connect flows

---

## Library Selection Guide

| Use Case | Recommended Library | Reason |
|----------|-------------------|--------|
| Quick prototype | nostr-login | Zero-code login widget |
| Production web app | NDK | Full framework, signer abstraction |
| Custom integration | nostr-tools | Maximum control |
| Multi-signer support | nostr-signer-connector | Unified interface |
| Rust backend/desktop | rust-nostr | Native performance |
| Standard interfaces | Nostrify | Swappable implementations |

### Decision Tree

1. **Need a login widget?** → nostr-login (drop-in, zero custom UI)
2. **Building a full Nostr app?** → NDK (comprehensive framework)
3. **Just need signing?** → nostr-signer-connector (unified interface)
4. **Need low-level control?** → nostr-tools (raw protocol access)
5. **Rust/native?** → rust-nostr
