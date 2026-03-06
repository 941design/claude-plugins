---
name: marmot-update
description: >-
  Maintenance skill that updates the Marmot Protocol supporting documents by
  fetching the latest from all primary repositories and documentation sites.
  Updates agent memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific repo or topic to update]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: marmot-researcher
---

## Documentation Update Task

You are running a documentation update cycle for the Marmot Protocol knowledge
base. This is a maintenance task — do NOT answer user questions, only update
documents.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full update of all documents.

## Update Procedure

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

### 3. Update Supporting Documents

Update each file in `${CLAUDE_SKILL_DIR}/../marmot/`:

| File | What to update |
|---|---|
| `protocol-overview.md` | Version info, security properties, new event kinds |
| `mip-specifications.md` | MIP status changes, new MIPs, spec amendments |
| `mdk-reference.md` | New/changed API methods, structs, traits, version |
| `marmot-ts-reference.md` | New/changed API classes, interfaces, version |
| `architecture.md` | Architectural changes, new patterns |
| `ecosystem.md` | New apps, bindings, community developments |

**Rules for updates:**
- Preserve the existing structure and headings
- Only modify content that has actually changed
- Add new sections at appropriate locations
- Update version numbers when observed
- Do NOT remove content unless it is confirmed deprecated/removed

### 4. Write Timestamp

Write the current Unix timestamp to `${CLAUDE_SKILL_DIR}/../marmot/last-updated.txt`:

```bash
date +%s > ${CLAUDE_SKILL_DIR}/../marmot/last-updated.txt
```

### 5. Update Agent Memory

Update your MEMORY.md with:
- `last_fetch_date: <unix-timestamp>`
- Summary of what changed since last fetch
- Any new version numbers observed
- Notable deprecations or breaking changes

If significant new patterns or findings were discovered, write them to the
appropriate topic files in your memory directory.

### 6. Report

Output a concise summary of what was updated:
- Which documents were modified
- Key changes found
- Any issues encountered (404s, missing data, etc.)
- Current version numbers of key packages
