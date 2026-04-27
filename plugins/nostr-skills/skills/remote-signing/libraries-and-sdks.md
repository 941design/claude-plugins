# Libraries and SDKs

> Scope: this document covers libraries with first-class **signer**
> integration (NIP-46 / NIP-07 / NIP-55 / NIP-49). For general-purpose
> Nostr SDK selection across languages — including SDKs without dedicated
> signer abstractions — see the **nostr-sdks** skill.

## Overview

| Library | Platform | NIP Support | Best For |
|---------|----------|-------------|----------|
| **nostr-tools** | JS/TS | 07, 46 | Low-level control |
| **NDK** | TS, Dart, React Native | 07, 46, 55 (Dart) | Full-featured framework |
| **nostr-login** | JS (drop-in) | 07, 46 | Complete login widget |
| **nostr-signer-connector** | TS | 07, 46, 49 | Unified signer interface |
| **Nostrify** | TS (JSR) | 07, 46 | Standard interfaces |
| **rust-nostr** (`nostr-sdk` crate) | Rust | 46, 55 | Desktop/backend, source for UniFFI bindings |
| **nostr-sdk-jvm** | Kotlin/JVM (UniFFI) | 46, 55 | Android, JVM apps with rust-nostr parity |
| **nostr-sdk-swift** | Swift (UniFFI) | 46, 55 | Apple platforms via rust-nostr core |
| **nostr-sdk-ios** | Swift (native) | 46 | Native iOS/macOS apps, idiomatic Swift |
| **fiatjaf.com/nostr** | Go (successor to `nbd-wtf/go-nostr`) | 46 | Go services, relays, hybrid clients |
| **nostr-java** | Java | Helper-level signing | Pure-Java JVM apps, ~25 NIPs |
| **nostr4j** | JVM (high-perf, JS-transpilable) | 46, 47 | Throughput-sensitive JVM/Android |
| **pynostr** | Python | Helper-level signing | Python apps and bots |

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

- NIP-46 signer support (`Nip46Signer`)
- Android signer library for NIP-55
- Cross-compilation targets
- Suitable for desktop apps, backend services, CLI tools
- Source of truth for the UniFFI bindings shipped as `nostr-sdk-jvm`,
  `nostr-sdk-swift`, `nostr-sdk-python`, etc.

### NIP-46 Usage

```rust
use nostr_sdk::prelude::*;

let app_keys = Keys::generate();
let uri = NostrConnectURI::parse("bunker://...")?;
let signer = Nip46Signer::new(uri, app_keys, Duration::from_secs(60), None).await?;
let client = Client::with_signer(signer);
```

---

## nostr-sdk-jvm (Kotlin / JVM, UniFFI)

- **Repo:** https://github.com/rust-nostr/nostr-sdk-ffi
- **Maven Central:** `io.github.rust-nostr:nostr-sdk` (v0.44.x baseline)
- **Generates from:** rust-nostr core via UniFFI — same API surface as
  the Rust crate

### NIP-46 Usage (Kotlin)

```kotlin
import rust.nostr.sdk.*

val appKeys = Keys.generate()
val uri = NostrConnectUri.parse("bunker://...")
val signer = NostrConnect(uri, appKeys, 60u, null)
val client = ClientBuilder().signer(signer).build()
```

### Characteristics

- Same protocol semantics as rust-nostr — useful when you ship Android
  alongside a Rust backend or iOS UniFFI client
- Larger binary footprint than pure-Java alternatives; rust-nostr v0.41+
  reduced UniFFI binary size considerably
- NIP-55 (Amber) interop via the rust-nostr Android signer module

---

## nostr-sdk-swift (Swift, UniFFI)

- **Repo:** https://github.com/rust-nostr/nostr-sdk-swift
- **Distribution:** Swift Package Manager
- **Generates from:** rust-nostr core via UniFFI

### Characteristics

- Same NIP-46 / NIP-44 / NIP-49 surface as `nostr-sdk-jvm`
- Best for Apple-platform projects that also ship Android/Rust clients
  with shared semantics
- Larger binary than the native `nostr-sdk-ios` library; pick this when
  cross-platform parity matters more than bundle size
- **Distinct project from** `nostr-sdk/nostr-sdk-ios` (see below)

---

## nostr-sdk-ios (native Swift)

- **Repo:** https://github.com/nostr-sdk/nostr-sdk-ios
- **Distribution:** Swift Package Manager
- **Implementation:** pure Swift, OpenSats-funded, separate org from
  rust-nostr and Damus

### Features

- NIP-46 client integration
- Idiomatic Swift APIs (Codable, async/await)
- Smallest footprint of the iOS-native options for full SDK functionality

### Characteristics

- Best default for native iOS/macOS apps that want first-class Swift
- Choose `nostr-sdk-swift` (UniFFI) instead when you need API parity with
  Android/Rust clients

---

## fiatjaf.com/nostr (Go)

- **Module:** https://pkg.go.dev/fiatjaf.com/nostr
- **Successor to:** `github.com/nbd-wtf/go-nostr` (archived 2026-01-24)

### Features

- NIP-46 client + bunker support
- Comprehensive Go library — relays, clients, NIP helpers, CLI utilities
- API breaks vs `nbd-wtf/go-nostr`; new features added in the move

### NIP-46 Usage

```go
import (
    "fiatjaf.com/nostr"
    "fiatjaf.com/nostr/nip46"
)

ptr, _ := nip46.ParseBunkerURL("bunker://...")
signer, _ := nip46.NewSigner(ctx, localSecretKey, ptr)
event, _ := signer.SignEvent(ctx, &nostr.Event{...})
```

### Characteristics

- Best for Go services, relay implementations, hybrid client/server tools
- The maintained replacement for `go-nostr` — migrate when the API stabilises

---

## nostr-java (Java)

- **Repo:** https://github.com/tcheeric/nostr-java
- **Coverage:** ~25 NIPs (core protocol, encryption, payments, NIP-19)
- **NIP-46:** helper-level — manual construction of `kind: 24133` requests
  rather than a turnkey `Nip46Signer` class

### Characteristics

- Pure Java implementation — no Rust toolchain, no UniFFI binary bundling
- Best when the project must remain pure-Java or when JVM tooling
  excludes native libraries
- For first-class NIP-46 prefer `nostr-sdk-jvm` (UniFFI) or `nostr4j`

---

## nostr4j (JVM)

- **Repo:** https://github.com/NostrGameEngine/nostr4j
- **Maven:** `maven.rblb.it/NostrGameEngine`
- **NIPs:** 01, 04, 05, 07, 09, 24, 39, 40, 44, 46, 47, 49, 50

### Characteristics

- High-throughput, memory-efficient JVM library
- Transpilable to JavaScript via TeaVM — useful for shared client/server
  code that targets browser and JVM
- First-class NIP-46 + NIP-47 (Nostr Wallet Connect) support
- Smaller community than the rust-nostr family but a fully native JVM
  alternative

---

## pynostr (Python)

- **Repo:** https://github.com/holgern/pynostr
- **PyPI:** `pynostr`
- **Forked from:** `jeffthibault/python-nostr` (the original is now
  feature-frozen — use pynostr for new work)

### Characteristics

- Uses `coincurve` instead of `secp256k1`, so it works on Windows
- NIP-26 delegation, NIP-19 encoding, proof-of-work helpers
- NIP-46 support is helper-level — manual encrypted DM construction
  rather than a turnkey signer class
- Best for Python bots, scripts, server-side tooling

---

## Libraries Intentionally Skipped

These libraries are not recommended for new signer-integration work:

| Library | Reason | Use Instead |
|---|---|---|
| `nbd-wtf/go-nostr` | Archived 2026-01-24 | `fiatjaf.com/nostr` |
| `jeffthibault/python-nostr` | Feature-frozen | `pynostr` |
| `cnixbtc/NostrKit` | Minimal — no NIP-46, no NIP-44 | `nostr-sdk-ios` (native) or `nostr-sdk-swift` (UniFFI) |
| `KotlinGeekDev/Rhodium` | Author marks as "still in development and very incomplete" | `nostr-sdk-jvm` (Kotlin Multiplatform via UniFFI) |
| `damus-io/nostr-sdk` | Damus-internal Rust crate, distinct from `rust-nostr/nostr-sdk` | `rust-nostr/nostr-sdk` |

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
| Custom TS/JS integration | nostr-tools | Maximum control |
| Multi-signer support (TS) | nostr-signer-connector | Unified interface |
| Rust backend/desktop/CLI | rust-nostr | Native performance, FFI source |
| Android/Kotlin app with NIP-46 | nostr-sdk-jvm | Shared core with iOS/Rust |
| Native iOS/macOS app | nostr-sdk-ios | Idiomatic Swift, smallest footprint |
| iOS app sharing core with Android | nostr-sdk-swift | UniFFI parity with nostr-sdk-jvm |
| Go service / relay | fiatjaf.com/nostr | Successor to archived go-nostr |
| Pure-Java app | nostr-java | No native deps, ~25 NIPs |
| High-perf JVM | nostr4j | NIP-46/47, JS-transpilable |
| Python app/bot | pynostr | Active fork, Windows-compatible |
| Standard interfaces (TS) | Nostrify | Swappable implementations |

### Decision Tree

1. **Need a login widget?** → nostr-login (drop-in, zero custom UI)
2. **Building a full Nostr app in TS?** → NDK (comprehensive framework)
3. **Just need TS signing?** → nostr-signer-connector (unified interface)
4. **Need low-level TS/JS control?** → nostr-tools (raw protocol access)
5. **Rust backend / CLI?** → rust-nostr
6. **Android (Kotlin)?** → nostr-sdk-jvm; for pure-Java pick nostr-java or
   nostr4j (high-perf)
7. **iOS native?** → nostr-sdk-ios (native) or nostr-sdk-swift (UniFFI)
8. **Go?** → fiatjaf.com/nostr (NOT the archived nbd-wtf/go-nostr)
9. **Python?** → pynostr (NOT the legacy python-nostr)
10. **Cross-language parity?** → rust-nostr family (nostr-sdk-jvm +
    nostr-sdk-swift) — same core, same semantics
