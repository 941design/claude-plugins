---
name: nostr-update
description: >-
  Maintenance skill that refreshes the nak CLI knowledge base by fetching the
  latest README, release notes, and command documentation from the nak
  repository. Updates agent memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific command or topic to update]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: nostr-operator
---

## Knowledge Refresh Task

You are running a knowledge refresh for the nak CLI knowledge base.
This is a maintenance task — do NOT answer user questions, only update your
agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Fetch README, release notes, and key source files. Use WebFetch for raw
GitHub content and WebSearch for recent developments.

**Sources to check:**

| Source | URL to fetch |
|---|---|
| nak README | https://github.com/fiatjaf/nak/blob/master/README.md |
| nak releases | https://github.com/fiatjaf/nak/releases |
| nak main.go | https://github.com/fiatjaf/nak/blob/master/main.go |
| NIP index | https://github.com/nostr-protocol/nips |

**For each source, capture:**
- Current nak version number
- New or changed commands and flags
- New subcommands or removed commands
- Breaking changes or deprecation notices
- New NIP support added

### 2. Check Installed Version

Run `nak --version` to check the locally installed version. Note if it
differs from the latest release.

### 3. Search for Recent Developments

Use WebSearch for:
- "nak nostr" site:github.com — new issues, PRs, or discussions
- "fiatjaf nak" recent updates
- "nostr army knife" new features
- New NIPs that nak might support

### 4. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Current nak version (latest release and locally installed)
- Command inventory (any additions or removals)
- Summary of what changed since last fetch

**Topic files** — update or create as needed:

| File | What to record |
|---|---|
| `usage-patterns.md` | New or changed command patterns, flag combinations |
| `gotchas.md` | New pitfalls discovered, resolved issues |
| `changelog.md` | Version changes, new commands, breaking changes |
| `relay-list.md` | Discovered relay URLs categorized by purpose (general, search, media, profiles) |
| `corrections.md` | Anything that differs from the supporting documents shipped with the plugin — these corrections take precedence when answering |

### 5. Report

Output a concise summary of what was found:
- Key changes since last refresh
- New nak version number
- New commands or flags
- Any corrections to the shipped supporting documents
- Issues encountered (404s, missing data, etc.)
