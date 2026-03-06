---
name: marmot-update
description: >-
  Maintenance skill that refreshes the Marmot Protocol knowledge base by
  fetching the latest from all primary repositories and documentation sites.
  Updates agent memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific repo or topic to update]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: marmot-researcher
---

## Knowledge Refresh Task

You are running a knowledge refresh for the Marmot Protocol knowledge base.
This is a maintenance task — do NOT answer user questions, only update your
agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Fetch README and key source files from each repository. Use WebFetch for raw
GitHub content and WebSearch for recent developments.

**Repositories to check:**

| Source | URL to fetch |
|---|---|
| Protocol spec | https://github.com/marmot-protocol/marmot |
| MDK (Rust) | https://github.com/parres-hq/mdk |
| marmot-ts | https://github.com/marmot-protocol/marmot-ts |
| WhiteNoise | https://github.com/marmot-protocol/whitenoise-rs |
| wn-tui | https://github.com/marmot-protocol/wn-tui |
| marmots-web-chat | https://github.com/marmot-protocol/marmots-web-chat |
| TS docs site | https://marmot-protocol.github.io/marmot-ts/ |

**For each repository, capture:**
- Current version numbers (Cargo.toml, package.json)
- README changes
- New or modified API surface (public types, methods, traits)
- Breaking changes or deprecation notices
- New MIP specifications or status changes

### 2. Search for Recent Developments

Use WebSearch for:
- "marmot protocol" site:github.com — new repos or major PRs
- "marmot-ts" OR "mdk" recent changes
- "whitenoise chat" OR "whitenoise nostr" — app updates
- "NIP-EE" OR "nostr MLS" — ecosystem developments

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Current version numbers of all key packages
- Repository map (any URL changes, new repos)
- Summary of what changed since last fetch

**Topic files** — update or create as needed:

| File | What to record |
|---|---|
| `api-patterns.md` | New or changed API patterns across MDK and marmot-ts |
| `gotchas.md` | New pitfalls discovered, resolved issues |
| `changelog.md` | Version changes, breaking changes, deprecations |
| `corrections.md` | Anything that differs from the supporting documents shipped with the plugin — these corrections take precedence when answering |

### 4. Report

Output a concise summary of what was found:
- Key changes since last refresh
- New version numbers
- Any corrections to the shipped supporting documents
- Issues encountered (404s, missing data, etc.)
