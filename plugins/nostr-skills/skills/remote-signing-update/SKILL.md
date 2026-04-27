---
name: remote-signing-update
description: >-
  Maintenance skill that refreshes the Nostr remote signing knowledge base by
  fetching the latest NIP specifications, library releases, and signer
  implementations. Updates agent memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific NIP, library, or signer to update]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: remote-signing-researcher
---

## Knowledge Refresh Task

You are running a knowledge refresh for the Nostr remote signing knowledge
base. This is a maintenance task — do NOT answer user questions, only update
your agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest NIP Specifications

Fetch the raw NIP markdown files from GitHub to check for spec updates:

| NIP | URL to fetch |
|---|---|
| NIP-46 (Remote Signing) | https://raw.githubusercontent.com/nostr-protocol/nips/master/46.md |
| NIP-07 (window.nostr) | https://raw.githubusercontent.com/nostr-protocol/nips/master/07.md |
| NIP-55 (Android Signer) | https://raw.githubusercontent.com/nostr-protocol/nips/master/55.md |
| NIP-44 (Versioned Encryption) | https://raw.githubusercontent.com/nostr-protocol/nips/master/44.md |
| NIP-49 (Key Encryption) | https://raw.githubusercontent.com/nostr-protocol/nips/master/49.md |
| NIP-19 (Bech32 Entities) | https://raw.githubusercontent.com/nostr-protocol/nips/master/19.md |

### 2. Fetch Latest from Libraries and Signers

| Source | URL to fetch |
|---|---|
| nostr-tools | https://github.com/nbd-wtf/nostr-tools |
| NDK | https://github.com/nostr-dev-kit/ndk |
| nostr-login | https://github.com/nostrband/nostr-login |
| rust-nostr | https://github.com/rust-nostr/nostr/blob/master/CHANGELOG.md |
| nostr-sdk-jvm | https://central.sonatype.com/artifact/io.github.rust-nostr/nostr-sdk |
| nostr-sdk-swift | https://github.com/rust-nostr/nostr-sdk-swift/releases |
| nostr-sdk-ios | https://github.com/nostr-sdk/nostr-sdk-ios/releases |
| fiatjaf.com/nostr | https://pkg.go.dev/fiatjaf.com/nostr |
| nostr-java | https://github.com/tcheeric/nostr-java/releases |
| nostr4j | https://github.com/NostrGameEngine/nostr4j |
| pynostr | https://pypi.org/project/pynostr/ |
| nsecbunkerd | https://github.com/kind-0/nsecbunkerd |
| nsec.app (noauth) | https://github.com/nostrband/noauth |
| Amber | https://github.com/greenart7c3/Amber |
| Aegis | https://github.com/ZharlieW/Aegis |
| FROSTR/bifrost | https://github.com/frostr-org/bifrost |
| nostr-keyx | https://github.com/susumuota/nostr-keyx |

**For each source, capture:**
- Current version numbers (package.json, Cargo.toml, release tags)
- README changes
- New or modified API surface
- Breaking changes or deprecation notices
- NIP spec status changes (draft → standard, new methods added)

### 3. Search for Recent Developments

Use WebSearch for:
- "NIP-46 remote signing" — spec updates, new implementations
- "nsecbunker" OR "nsec.app" — service changes
- "nostr signer" new implementations
- "FROSTR" OR "nostr threshold signing" — ecosystem developments
- "nostr NIP-07 NIP-55" — browser/Android signer updates
- "nostr-tools" OR "NDK" signer API changes
- "rust-nostr" OR "nostr-sdk-jvm" OR "nostr-sdk-swift" release notes
- "fiatjaf.com/nostr" OR "go-nostr" Go SDK changes
- "pynostr" OR "nostr-java" OR "nostr4j" release activity

### 4. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Current version numbers of key libraries and signers
- NIP spec status (draft/standard/deprecated)
- Summary of what changed since last fetch

**Topic files** — update or create as needed:

| File | What to record |
|---|---|
| `integration-patterns.md` | New or changed signer integration patterns across libraries |
| `gotchas.md` | New pitfalls discovered, resolved issues |
| `changelog.md` | Version changes, NIP spec updates, breaking changes |
| `corrections.md` | Anything that differs from the supporting documents shipped with the plugin — these corrections take precedence when answering |

### 5. Report

Output a concise summary of what was found:
- Key changes since last refresh
- New version numbers
- NIP spec changes
- Any corrections to the shipped supporting documents
- Issues encountered (404s, missing data, etc.)
