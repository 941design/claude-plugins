---
name: nostr-sdks-update
description: >-
  Maintenance skill that refreshes the cross-language Nostr SDK knowledge
  base by fetching latest releases, NIP support tables, and project status
  for nostr-tools, NDK, rust-nostr, fiatjaf.com/nostr, nostr-java, nostr4j,
  nostr-sdk-jvm/swift/ios, pynostr, and other tracked SDKs. Updates agent
  memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific SDK or language to update]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: nostr-sdk-researcher
---

## Knowledge Refresh Task

You are running a knowledge refresh for the Nostr SDK knowledge base. This
is a maintenance task — do NOT answer user questions, only update your
agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Library Repositories

Fetch README and recent release notes for each SDK:

| SDK | URL to fetch |
|---|---|
| nostr-tools | https://github.com/nbd-wtf/nostr-tools/releases |
| NDK | https://github.com/nostr-dev-kit/ndk/releases |
| rust-nostr | https://github.com/rust-nostr/nostr/blob/master/CHANGELOG.md |
| nostr-sdk-jvm (Maven) | https://central.sonatype.com/artifact/io.github.rust-nostr/nostr-sdk |
| nostr-sdk-swift (UniFFI) | https://github.com/rust-nostr/nostr-sdk-swift/releases |
| nostr-sdk-ios (native) | https://github.com/nostr-sdk/nostr-sdk-ios/releases |
| fiatjaf.com/nostr (Go) | https://pkg.go.dev/fiatjaf.com/nostr |
| go-nostr (archived legacy) | https://github.com/nbd-wtf/go-nostr |
| nostr-java | https://github.com/tcheeric/nostr-java/releases |
| nostr4j | https://github.com/NostrGameEngine/nostr4j |
| pynostr | https://pypi.org/project/pynostr/ |
| python-nostr (legacy) | https://github.com/jeffthibault/python-nostr |
| Rhodium | https://github.com/KotlinGeekDev/Rhodium |
| NostrKit | https://github.com/cnixbtc/NostrKit |

**For each source, capture:**
- Current version numbers (npm, JSR, crates.io, Maven Central, PyPI, SwiftPM)
- New or modified API surfaces
- Newly supported NIPs / dropped NIPs
- Breaking changes or deprecation notices
- Last commit timestamp; flag stale projects (>180 days inactive)
- Archive status changes

### 2. Search for Recent Developments

Use WebSearch for:
- "rust-nostr release" — version bumps, new bindings
- "nostr SDK new library" — emerging libraries to consider tracking
- "nostr-tools" / "NDK" major release notes
- "nostr go library" / "fiatjaf.com/nostr" — Go ecosystem updates
- "nostr Kotlin Swift" — JVM/Apple binding updates

### 3. Verify Project Status

For each tracked SDK:
- Is it still active? (commits in last 90 days)
- Has it been archived, renamed, or moved?
- Have new forks or successors emerged?
- Have new bindings appeared (UniFFI, FFI, JNI)?

If a new SDK is observed in the ecosystem, add it to the matrix in agent
memory (not the shipped supporting docs) for inclusion in a future update
release.

### 4. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Current version numbers for each tracked SDK
- Summary of what changed since last fetch
- Any newly archived / renamed / forked projects

**Topic files** — update or create as needed:

| File | What to record |
|---|---|
| `library-matrix.md` | Updated maturity / activity / NIP-support data per SDK |
| `new-libraries.md` | Newly observed Nostr SDKs not yet in shipped docs |
| `gotchas.md` | API quirks, name collisions, binding pitfalls discovered |
| `changelog.md` | Version bumps, breaking changes, archive notices |
| `corrections.md` | Anything that differs from shipped supporting documents — these corrections take precedence when answering |

### 5. Report

Output a concise summary of what was found:
- Key changes since last refresh
- New version numbers
- New or archived libraries
- Any corrections to the shipped supporting documents
- Issues encountered (404s, missing data, etc.)
