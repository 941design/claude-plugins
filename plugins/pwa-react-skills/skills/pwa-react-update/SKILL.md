---
name: pwa-react-update
description: >-
  Maintenance skill that refreshes the PWA and React knowledge base by fetching
  the latest research, framework updates, browser compatibility changes, and
  best practice developments. Updates agent memory with new findings and
  timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific topic to update, e.g. 'react-compiler' or 'workbox']"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: pwa-react-expert
---

## Knowledge Refresh Task

You are running a knowledge refresh for the PWA and React knowledge base.
This is a maintenance task — do NOT answer user questions, only update your
agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Fetch documentation and release notes from each source. Use WebFetch for
raw content and WebSearch for recent developments.

**Sources to check:**

| Source | URL to fetch |
|---|---|
| React blog | https://react.dev/blog |
| Workbox releases | https://github.com/GoogleChrome/workbox/releases |
| Next.js releases | https://github.com/vercel/next.js/releases |
| web.dev PWA | https://web.dev/explore/progressive-web-apps |
| Can I Use | https://caniuse.com |

**For each source, capture:**
- Current version numbers
- New or modified APIs and features
- Breaking changes or deprecation notices
- Best practice changes

### 2. Search for Recent Developments

Use WebSearch for:

**PWA Topics:**
- "service worker API changes" — spec updates
- "Workbox release" — tooling updates
- "Web App Manifest spec changes" — manifest updates
- "Core Web Vitals changes" — metric updates
- "iOS PWA support" — Safari/WebKit changes
- "PWA best practices 2025 2026" — new patterns

**React Topics:**
- "React releases" — latest features
- "React Compiler" — performance developments
- "Zustand Jotai TanStack Query release" — state management updates
- "Vitest Playwright release" — testing tool updates
- "Next.js release" — framework updates
- "Vite release" — build tooling updates

**UX Topics:**
- "View Transitions API" — UX capabilities
- "CSS features 2025 2026" — new CSS patterns
- "Radix UI shadcn release" — component library updates

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Summary of what changed since last fetch
- Current version numbers for key packages
- New frameworks, APIs, or patterns discovered

**Topic files** — update or create as needed:

| File | What to record |
|---|---|
| `pwa-patterns.md` | New or changed service worker patterns, caching strategies, manifest updates |
| `react-updates.md` | React releases, compiler changes, new hooks and APIs |
| `tooling.md` | Framework versions, build tool updates, library releases |
| `gotchas.md` | New pitfalls discovered, resolved issues |
| `changelog.md` | Version changes, breaking changes, deprecations |
| `corrections.md` | Anything that differs from the shipped supporting documents — these corrections take precedence when answering |

### 4. Report

Output a concise summary of what was found:
- Key changes since last refresh
- New version numbers
- New features or deprecations
- Any corrections to the shipped supporting documents
- Issues encountered (404s, missing data, etc.)
