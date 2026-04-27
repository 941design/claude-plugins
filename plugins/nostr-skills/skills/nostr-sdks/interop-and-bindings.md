# Interop, Bindings, and Ecosystem Caveats

This document captures the non-obvious relationships between SDKs:
which ones share a core, which ones are forks, which are archived, and
which produce identical wire output across languages.

## The rust-nostr UniFFI Family

`rust-nostr` (Rust crate `nostr-sdk`) is the core; UniFFI generates
language bindings that share that core. They publish:

| Binding | Repo | Distribution | Notes |
|---|---|---|---|
| Rust | `rust-nostr/nostr` | crates.io `nostr-sdk` | Source of truth |
| Kotlin / JVM | `rust-nostr/nostr-sdk-ffi` (sources) | Maven Central `io.github.rust-nostr:nostr-sdk` | "nostr-sdk-jvm" |
| Swift | `rust-nostr/nostr-sdk-swift` | SwiftPM | UniFFI bindings; **distinct** from native `nostr-sdk-ios` |
| Python | `rust-nostr/nostr-sdk-ffi` | PyPI `nostr-sdk` | UniFFI |
| JavaScript / WASM | `rust-nostr/nostr-sdk-ffi` | npm `@rust-nostr/nostr-sdk` | Distinct from `nostr-tools` |

**API parity:** the bindings expose nearly the same surface across
languages, so an Android Kotlin client and an iOS Swift client built on
the rust-nostr family share semantics.

**Trade-off:** UniFFI binaries add to app size. rust-nostr v0.41+
significantly reduced binding size, but pure-language SDKs
(`nostr-tools`, `nostr-sdk-ios`, `nostr-java`, `pynostr`) are still
smaller and more idiomatic.

## Two Different "nostr-sdk-ios" Projects

There are two Swift packages people sometimes call "nostr-sdk-ios":

### `nostr-sdk/nostr-sdk-ios` (native)
- Org: `nostr-sdk` (separate from Damus, separate from rust-nostr)
- Pure Swift implementation
- OpenSats-funded
- Idiomatic Apple APIs (Codable, Combine where appropriate)
- Best for native iOS/macOS apps that want first-class Swift

### `rust-nostr/nostr-sdk-swift` (UniFFI)
- Swift bindings over rust-nostr's Rust core
- API mirrors the Rust SDK
- Best when you also ship Android/Rust clients with shared semantics
- Larger binary footprint than native; trade-off for parity

**When asked about "nostr-sdk for iOS":** ask which one. Default
recommendation = native `nostr-sdk-ios` for greenfield iOS projects;
UniFFI variant when cross-platform parity matters.

## Damus's Separate `nostr-sdk`

The `damus-io/nostr-sdk` crate is a **distinct** Rust implementation
that powers Damus iOS. Some Damus tooling has migrated away from it
toward `nostr-types` (also damus-io). This is **not** related to
`rust-nostr/nostr-sdk` despite the name collision. Recommend
`rust-nostr/nostr-sdk` for greenfield work; only touch `damus-io/nostr-sdk`
if you're contributing to Damus itself.

## Archived / Legacy Projects

| Project | Status | Successor |
|---|---|---|
| `nbd-wtf/go-nostr` | Archived 2026-01-24 | `fiatjaf.com/nostr` (same author, breaking API, new features) |
| `jeffthibault/python-nostr` | Feature-frozen | `holgern/pynostr` (active fork) |
| `marmot-protocol/nostr-openmls` | Archived | `nostr-mls` crate within rust-nostr |
| `cnixbtc/NostrKit` | Stale | `nostr-sdk/nostr-sdk-ios` or `rust-nostr/nostr-sdk-swift` |

## Forks and Spinoffs

- `holgern/pynostr` forked `jeffthibault/python-nostr`, swapped
  `secp256k1` for `coincurve` (Windows compatibility), and continued
  development independently.
- `Memory-of-Snow/nostr-java-fork` is a fork of `tcheeric/nostr-java`;
  the upstream is still active so use upstream unless you need a
  specific fork patch.
- `NostrGameEngine/nostr4j` is a from-scratch JVM library, not a fork.

## Cross-Implementation Wire Compatibility

All compliant SDKs produce the same wire format (kind / created_at /
tags / content / sig) for kind 1 events. Where they differ:

- **NIP-44 v2 encryption:** consistent across nostr-tools, NDK,
  rust-nostr, nostr-java (recent), pynostr (recent). Older versions of
  python-nostr lack NIP-44.
- **NIP-19 entities:** consistent — but bech32 prefixes for new entities
  (`naddr`, `nevent`, `nrelay`) ship at different cadences. nostr-tools
  and rust-nostr typically lead.
- **NIP-46 message format:** in lockstep across nostr-tools, NDK,
  rust-nostr, nostr-sdk-jvm, nostr-sdk-swift, nostr-sdk-ios. Older
  python-nostr / Rhodium / NostrKit do not implement NIP-46.

## Picking Bindings vs Native

| Goal | Pick |
|---|---|
| Smallest app binary | Native (nostr-tools, nostr-sdk-ios, nostr-java, pynostr) |
| One core / many platforms | rust-nostr UniFFI family |
| Existing Rust backend | rust-nostr crate + UniFFI on the client |
| Idiomatic Kotlin / Swift API | nostr-java / nostr4j; nostr-sdk-ios |
| Quickest start | nostr-tools (TS) or pynostr (Python) |

## Notes for the Agent

When the user asks "what's the best Nostr library for X":

1. Surface the **language-native** SDK first, per the default stance.
2. Note the **rust-nostr family** as a fallback if cross-platform
   parity matters.
3. Always check archive/legacy status (table above) before recommending.
4. When binaries are about to be shipped to end users, factor in size:
   UniFFI binaries are larger than native equivalents.
