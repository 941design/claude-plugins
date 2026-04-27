---
name: nostr-sdks
description: >-
  Cross-language Nostr SDK selection and usage advisor. Helps pick the right
  library for the user's language and platform across nostr-tools (TS), NDK,
  rust-nostr, fiatjaf.com/nostr (Go), nostr-java, nostr4j, nostr-sdk-jvm,
  nostr-sdk-ios (native Swift), nostr-sdk-swift (UniFFI), pynostr, and more.
  Covers event publishing, subscriptions, NIP support, project status,
  cross-SDK interop, and bindings vs native trade-offs. Invoke when the user
  is choosing or learning a Nostr SDK in any language beyond pure NIP-46
  signing (use the remote-signing skill for that).
argument-hint: "[question about a Nostr SDK or library selection]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: nostr-sdk-researcher
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Follow the
refresh procedure described in your agent system prompt (fetch SDK repos,
release notes, and NIP support tables — write findings to agent memory only,
never modify plugin files).

If memory is fresh, proceed directly to answering.

## User Question

$ARGUMENTS

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [library-matrix.md](library-matrix.md) | All major Nostr SDKs by language/maturity/NIP support/activity, with strengths and trade-offs |
| [selection-guide.md](selection-guide.md) | Decision tree by language, platform, and use case; when to push back on a user's chosen library |
| [common-tasks.md](common-tasks.md) | Side-by-side code examples for keypair generation, publish, subscribe, and NIP-46 connect across SDKs |
| [interop-and-bindings.md](interop-and-bindings.md) | rust-nostr UniFFI family, the two distinct nostr-sdk-ios projects, archived/legacy projects, wire compatibility |

Read the relevant documents to answer the user's question. Consult your agent
memory for additional context and prior findings.

## Response Format

- **Default to language-native first.** Match the user's stack rather than
  pushing one SDK universally. nostr-tools/NDK for TS, rust-nostr for Rust,
  fiatjaf.com/nostr for Go, pynostr for Python, nostr-sdk-ios for native
  Apple, etc.
- **Surface bindings as a fallback** when cross-platform parity matters
  (rust-nostr → nostr-sdk-jvm + nostr-sdk-swift).
- **Always check archive/legacy status** before recommending: go-nostr is
  archived (use fiatjaf.com/nostr), python-nostr is feature-frozen (use
  pynostr), NostrKit is minimal (use nostr-sdk-ios), Rhodium is incomplete
  (use nostr-sdk-jvm for KMP).
- **Show concrete code** for the chosen library — don't just name it.
- **Cite NIP numbers** when explaining behavior; defer to the
  remote-signing skill for deep NIP-46/07/55 specifics.
- **Flag pre-1.0 / alpha** status (rust-nostr family, marmot-ts, Rhodium).
- **Watch out for name collisions** — distinguish rust-nostr/nostr-sdk-swift
  (UniFFI) from nostr-sdk/nostr-sdk-ios (native) from damus-io/nostr-sdk
  (Damus's own implementation).
- If you need to fetch live source or release notes to verify an API
  surface, do so.
