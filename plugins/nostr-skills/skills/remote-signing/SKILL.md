---
name: remote-signing
description: >-
  Nostr remote signing and key management advisor. Helps integrate NIP-46
  bunkers, NIP-07 browser extensions, NIP-55 Android signers, and signer
  libraries (nostr-tools, NDK, nostr-login, rust-nostr, nostr-sdk-jvm,
  nostr-sdk-swift, nostr-sdk-ios, fiatjaf.com/nostr, nostr-java, nostr4j,
  pynostr) into applications across TS, Rust, JVM, Apple, Go, and Python.
  Invoke for questions about nsecBunker, Amber, nsec.app, key custody
  patterns, signer connection flows, or building apps that delegate signing
  across PWA, web, mobile, and desktop platforms.
argument-hint: "[question about Nostr remote signing or key management]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: remote-signing-researcher
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Follow the
refresh procedure described in your agent system prompt (fetch NIP specs and
library sources, write findings to agent memory only — never modify plugin
files).

If memory is fresh, proceed directly to answering.

## User Question

$ARGUMENTS

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [nip-46-protocol.md](nip-46-protocol.md) | NIP-46 remote signing protocol: message format, connection flows, methods, auth challenges |
| [signing-nips-reference.md](signing-nips-reference.md) | NIP-07, NIP-55, NIP-44, NIP-49, NIP-19 and other signing-related NIPs |
| [signer-implementations.md](signer-implementations.md) | nsecBunker, nsec.app, Amber, Aegis, nos2x, FROSTR, Gossip and other signers |
| [platform-best-practices.md](platform-best-practices.md) | PWA, web, and desktop integration patterns, security guidelines, UX recommendations |
| [libraries-and-sdks.md](libraries-and-sdks.md) | TS (nostr-tools, NDK, nostr-login, nostr-signer-connector, Nostrify), Rust (rust-nostr), JVM (nostr-sdk-jvm, nostr-java, nostr4j), Apple (nostr-sdk-ios, nostr-sdk-swift), Go (fiatjaf.com/nostr), Python (pynostr) |

Read the relevant documents to answer the user's question. Consult your agent
memory for additional context and prior findings.

## Response Format

- **Default to library usage.** Show how to accomplish the task using a
  language-appropriate library (nostr-tools/NDK for TS, rust-nostr for Rust,
  nostr-sdk-jvm for Android/Kotlin, nostr-sdk-ios or nostr-sdk-swift for
  Apple, fiatjaf.com/nostr for Go, pynostr for Python, nostr-java/nostr4j
  for pure JVM). Only explain protocol internals when the user explicitly
  asks or when it's needed to integrate correctly. For broader SDK
  selection beyond signing, defer to the **nostr-sdks** skill.
- Pick the right approach for the user's platform. If unsure, ask.
- Include concrete code examples showing library API calls.
- Cite NIP numbers when explaining why something works a certain way.
- Distinguish between production-ready and experimental signer implementations.
- Always emphasize security: never accept raw nsec, use NIP-46 or NIP-07
  for signing, ncryptsec for backup.
- If you need to fetch live source code or NIP specs to verify details, do so.
