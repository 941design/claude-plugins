---
name: playwright-update
description: >-
  Maintenance skill that refreshes the Playwright browser automation knowledge
  base by fetching the latest Playwright MCP documentation, changelog, and
  best practices. Updates agent memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific topic to update]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: playwright-browser
---

## Knowledge Refresh Task

You are running a knowledge refresh for the Playwright browser automation
knowledge base. This is a maintenance task — do NOT execute browser actions,
only update your agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Use WebFetch for documentation and WebSearch for recent developments.

**Sources to check:**

| Source | URL to fetch |
|---|---|
| Playwright MCP README | https://github.com/microsoft/playwright-mcp |
| Playwright MCP npm | https://www.npmjs.com/package/@playwright/mcp |
| Playwright docs | https://playwright.dev/docs/intro |
| Playwright releases | https://github.com/microsoft/playwright/releases |

**For each source, capture:**
- Current version numbers
- New or changed MCP tool capabilities
- Breaking changes or deprecation notices
- New selector strategies or best practices
- Known issues or workarounds

### 2. Search for Recent Developments

Use WebSearch for:
- "playwright mcp" recent changes or releases
- "@playwright/mcp" new features
- "playwright" selector best practices (recent)
- "playwright" common gotchas (recent)

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Current Playwright MCP version
- Current Playwright version
- Summary of what changed since last fetch

**Topic files** — update or create as needed:

| File | What to record |
|---|---|
| `selector-patterns.md` | Effective selector strategies per framework (React, Vue, Angular, etc.) |
| `gotchas.md` | Common pitfalls, browser quirks, and their solutions |
| `changelog.md` | Version changes, new tools, breaking changes, deprecations |
| `site-patterns.md` | Site-specific patterns (SPAs, auth flows, common layouts) |
| `corrections.md` | Anything that differs from baseline knowledge — these corrections take precedence when executing |

### 4. Report

Output a concise summary of what was found:
- Key changes since last refresh
- New version numbers
- New MCP tool capabilities
- Issues encountered (404s, missing data, etc.)
