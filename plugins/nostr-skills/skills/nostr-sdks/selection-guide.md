# SDK Selection Guide

The default stance is **language-native first** — match the user's existing
stack before pushing a particular ecosystem. This document encodes that as
a decision tree.

## Step 1 — What's the host language/platform?

| Stack | First choice | Backup |
|---|---|---|
| Browser, Node, Bun, Deno, JSR | nostr-tools | NDK (if framework-level abstractions wanted) |
| React/Svelte/Vue web app | NDK | nostr-tools + custom layer |
| React Native | NDK Mobile | nostr-tools |
| Rust desktop / backend / CLI | rust-nostr (`nostr-sdk` crate) | — |
| Go service, relay, CLI | fiatjaf.com/nostr | nbd-wtf/go-nostr (legacy, archived 2026-01-24) |
| Java service / Android backend | nostr-sdk-jvm (rust-nostr UniFFI) | nostr-java (pure Java) or nostr4j (high-perf) |
| Kotlin Android app | nostr-sdk-jvm | nostr4j |
| iOS / macOS native Swift | nostr-sdk-ios (native) | nostr-sdk-swift (UniFFI to rust-nostr) |
| Cross-platform mobile (Flutter) | NDK Dart | rust-nostr via FFI |
| Python | pynostr (`holgern/pynostr`) | python-nostr (legacy, feature-frozen) |
| Kotlin Multiplatform | nostr-sdk-jvm where possible; Rhodium incomplete | — |

## Step 2 — What features do you need?

Some features collapse choices fast:

| Need | Recommendation |
|---|---|
| Outbox model + relay management | NDK (TS) or rust-nostr |
| NIP-46 remote signing | nostr-tools, NDK, rust-nostr (+ bindings), nostr-sdk-ios, nostr4j |
| NIP-55 Android signer (Amber) | NDK Dart, rust-nostr, nostr-sdk-jvm |
| NIP-44 v2 encryption | nostr-tools, NDK, rust-nostr (+ bindings) |
| NIP-EE / Marmot (MLS group messaging) | MDK (Rust) or marmot-ts (TS) — see marmot skill |
| High-throughput JVM | nostr4j |
| Battle-tested protocol core across platforms | rust-nostr family (Rust + JVM + Swift bindings) |

## Step 3 — Project-status filters

Before recommending, filter out problematic options:

- **Archived:** `nbd-wtf/go-nostr` (2026-01-24) → use `fiatjaf.com/nostr`
- **Legacy / feature-frozen:** `python-nostr` (use `pynostr`)
- **Incomplete / experimental:** `Rhodium` (use `nostr-sdk-jvm` for KMP work)
- **Minimal scope:** `NostrKit` (no NIP-46, no NIP-44 — use
  `nostr-sdk-ios` or `nostr-sdk-swift`)

## Decision Tree

```
Q: What language/platform?
├── TypeScript / JavaScript
│   ├── Need full framework? ──→ NDK
│   └── Want low-level control? ──→ nostr-tools
├── Rust ──→ rust-nostr (`nostr-sdk` crate)
├── Go ──→ fiatjaf.com/nostr
├── JVM (Java/Kotlin)
│   ├── Want shared core with Swift/Rust? ──→ nostr-sdk-jvm (UniFFI)
│   ├── Pure Java + many NIPs? ──→ nostr-java
│   └── High-perf or JS-transpilable? ──→ nostr4j
├── Swift / Apple
│   ├── Idiomatic Swift, native API? ──→ nostr-sdk-ios
│   └── Shared core with Android/Rust? ──→ nostr-sdk-swift (UniFFI)
├── Python ──→ pynostr (holgern)
├── Kotlin Multiplatform
│   └── nostr-sdk-jvm covers most needs; Rhodium not yet ready
└── Flutter / Dart ──→ NDK Dart
```

## Cross-Cutting Recommendations

- **For new applications:** prefer SDKs with active commits in the last
  90 days and clear release cadence. Skip libraries with stale READMEs.
- **For server-side signing only:** rust-nostr or fiatjaf.com/nostr
  (less ceremony than full SDK frameworks).
- **For multi-platform apps where API parity matters:** rust-nostr family
  (Rust + nostr-sdk-jvm + nostr-sdk-swift) shares one core via UniFFI.
- **For projects that ship to end-users on iOS:** evaluate native
  `nostr-sdk-ios` first — UniFFI binaries can inflate app size, though
  rust-nostr has reduced this in recent releases.

## When to Push Back on the User's Choice

A user explicitly asks for a specific SDK. When should the advisor suggest
otherwise?

- They request `nbd-wtf/go-nostr` → suggest `fiatjaf.com/nostr` (archived)
- They request `python-nostr` → suggest `pynostr` (the active fork)
- They request `NostrKit` → ask what features they need; suggest
  `nostr-sdk-ios` if they need NIP-46/44
- They request `Rhodium` for production → suggest `nostr-sdk-jvm` until
  Rhodium reaches maturity
- They request a JVM library and need NIP-46 → recommend `nostr-sdk-jvm`
  or `nostr4j` over `nostr-java`
