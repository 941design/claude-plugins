# Nostr SDK Library Matrix

A comparative reference of major Nostr SDKs across languages. Use this to
pick the right library for the user's stack. The selection-guide.md document
provides the decision tree; this matrix lists facts.

> Statuses, version numbers, and traction notes reflect a baseline as of
> 2026-04. The agent's memory holds the latest fetched values — trust memory
> over this table when they differ.

## Overview Matrix

| Library | Language / Platform | Maturity | Active | Auth/Distribution |
|---|---|---|---|---|
| [nostr-tools](https://github.com/nbd-wtf/nostr-tools) | TypeScript / JS | Production | Yes | npm `nostr-tools`, JSR `@nostr/tools` |
| [NDK](https://github.com/nostr-dev-kit/ndk) | TypeScript, Dart, RN | Production | Yes | npm `@nostr-dev-kit/ndk` (+ subpackages) |
| [rust-nostr](https://github.com/rust-nostr/nostr) | Rust | Alpha (pre-1.0) | Yes | crates.io `nostr-sdk` |
| [fiatjaf.com/nostr](https://pkg.go.dev/fiatjaf.com/nostr) | Go | Active | Yes | Go module `fiatjaf.com/nostr` (successor to `nbd-wtf/go-nostr`, archived 2026-01-24) |
| [nostr-java](https://github.com/tcheeric/nostr-java) | Java | Mature | Yes | Maven; ~25 NIPs |
| [nostr4j](https://github.com/NostrGameEngine/nostr4j) | JVM (high-perf, JS-transpilable) | Active | Yes | `maven.rblb.it/NostrGameEngine` |
| [nostr-sdk-jvm](https://central.sonatype.com/artifact/io.github.rust-nostr/nostr-sdk) | Kotlin/JVM (UniFFI from rust-nostr) | Alpha | Yes | Maven Central `io.github.rust-nostr:nostr-sdk` |
| [nostr-sdk-ios](https://github.com/nostr-sdk/nostr-sdk-ios) | Swift / Apple platforms (native) | Active | Yes | Swift Package Manager |
| [nostr-sdk-swift](https://github.com/rust-nostr/nostr-sdk-swift) | Swift / Apple platforms (UniFFI from rust-nostr) | Alpha | Yes | SwiftPM |
| [pynostr](https://github.com/holgern/pynostr) | Python | Mature | Yes | PyPI `pynostr` |
| [python-nostr](https://github.com/jeffthibault/python-nostr) | Python | Legacy | Limited | Original; superseded by `pynostr` |
| [Rhodium](https://github.com/KotlinGeekDev/Rhodium) | Kotlin Multiplatform (JVM, Android, Linux, macOS/iOS) | Early / incomplete | Slow | GitHub source |
| [NostrKit](https://github.com/cnixbtc/NostrKit) | Swift (minimal data types only) | Old | Stale | SwiftPM |

## Feature Matrix

Numbers are 0–10 self-rated by the maintainers/community as of input. "Yes"
in NIP columns means first-class API support; "Helper" means manual
construction is required.

| Library | Maturity | Features | Traction | NIP-01 | NIP-19 | NIP-44 | NIP-46 | NIP-07 | NIP-55 |
|---|---|---|---|---|---|---|---|---|---|
| nostr-tools | 9 | 9 | 10 | Yes | Yes | Yes | Yes | Yes | n/a |
| NDK | 8 | 9 | 9 | Yes | Yes | Yes | Yes | Yes | Yes (Dart) |
| rust-nostr | 8 | 9 | 8 | Yes | Yes | Yes | Yes | n/a | Yes |
| fiatjaf.com/nostr (Go) | 8 | 8 | 8 | Yes | Yes | Yes | Yes | n/a | n/a |
| nostr-java | 7 | 7 | 5 | Yes | Yes | Yes | Helper | n/a | n/a |
| nostr-sdk-jvm | 7 | 9 | 4 | Yes | Yes | Yes | Yes | n/a | Yes |
| nostr-sdk-ios (native) | 6 | 7 | 5 | Yes | Yes | Yes | Yes | n/a | n/a |
| nostr-sdk-swift (UniFFI) | 7 | 9 | 4 | Yes | Yes | Yes | Yes | n/a | n/a |
| pynostr | 6 | 6 | 5 | Yes | Yes | Helper | Helper | n/a | n/a |
| python-nostr | 5 | 5 | 4 | Yes | Yes | No | No | n/a | n/a |
| Rhodium (KMP) | 5 | 6 | 3 | Yes | Helper | No | No | n/a | n/a |
| NostrKit | 4 | 5 | 3 | Yes | No | No | No | n/a | n/a |

## Strengths and Tradeoffs

### nostr-tools (TypeScript)
- **Best for:** browser apps, Node servers, low-level control
- **Strength:** maximum traction; canonical reference for TS Nostr APIs
- **Watch:** no opinion on state/storage — pair with NDK or your own layer

### NDK (TypeScript/Dart/RN)
- **Best for:** full-featured Nostr apps, outbox model, multi-relay
- **Strength:** signer abstraction, caching, subscription management,
  React/Svelte integrations
- **Watch:** higher abstraction can hide protocol details; some publish
  paths re-sign pre-signed events (use `NDKEvent.publish(relaySet, ...)`)

### rust-nostr / nostr-sdk
- **Best for:** desktop apps, backend services, mobile via UniFFI bindings
- **Strength:** single battle-tested core powering JVM, Swift, Python, JS
  bindings — consistent API across platforms
- **Watch:** still pre-1.0; UniFFI binary size historically a concern
  (improved in recent releases)

### fiatjaf.com/nostr (Go)
- **Best for:** Go relays, hybrid client/server tools, CLI utilities
- **Strength:** comprehensive Go library covering relays, clients, NIPs
- **Watch:** API breaking from old `nbd-wtf/go-nostr` — migrate when stable

### nostr-java vs nostr4j (JVM)
- **nostr-java** — older, more NIPs, conservative API
- **nostr4j** — high-throughput, memory-efficient, transpilable to JS,
  better NIP-46/47 support
- **Watch:** prefer **nostr-sdk-jvm** for new code unless you need
  JS-transpilable code or want a pure-Java codebase

### nostr-sdk-ios (native) vs nostr-sdk-swift (UniFFI)
- **nostr-sdk-ios** — pure Swift, OpenSats-funded, idiomatic Apple APIs
- **nostr-sdk-swift** — UniFFI bindings to rust-nostr, shares core with JVM
- **Tradeoff:** native = better Swift ergonomics; UniFFI = same core as
  Android/desktop bindings

### Python: pynostr vs python-nostr
- Use **pynostr** (holgern). It forked from python-nostr, swapped to
  `coincurve` (Windows support), and is actively maintained. The original
  python-nostr is feature-frozen.

### Rhodium (KMP) and NostrKit (Swift)
- **Rhodium** — community KMP attempt; "still in development and very
  incomplete" per its own README. Avoid for production.
- **NostrKit** — minimal Swift data types only. No NIP-46, no NIP-44.
  Superseded by nostr-sdk-ios and nostr-sdk-swift.
