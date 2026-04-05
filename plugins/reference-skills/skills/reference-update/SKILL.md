---
name: reference-update
description: >-
  Maintenance skill that refreshes reference project knowledge by fetching
  latest data from tracked GitHub repos. Updates per-project knowledge files
  in .claude/reference-knowledge/ and agent memory with methodological
  learnings. Optionally discovers and suggests new reference repos.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: repo alias to update, or 'discover' to find new repos]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: reference-researcher
---

## Knowledge Refresh Task

You are running a knowledge refresh for the reference project knowledge base.
This is a maintenance task — do NOT answer user questions, only update
knowledge files.

**Critical write rules:**
- Write all repo-specific findings to `.claude/reference-knowledge/` (project-local)
- Write methodological learnings ONLY to your agent memory
- Never modify files in the plugin/skill directory

If arguments were provided, handle them:
- A **repo alias** → refresh only that repo
- **"discover"** → scan the consumer project and suggest new reference repos
- No arguments → full refresh of all tracked repos

$ARGUMENTS

## Read Configuration

Read `.claude/references.yaml`. If it does not exist, output:
"No reference projects configured. Run `/reference-skills:reference-init` first."
Then stop.

Identify repos to refresh:
- If a specific alias was given, find that repo in the config
- Otherwise, refresh all repos in the config
- Also check for repos in the config that have NO knowledge directory yet
  (newly added) — these need a full initial fetch

## Refresh Procedure

### 1. Per-Repo Refresh

For each repo to refresh, follow the research methodology in
`${CLAUDE_SKILL_DIR}/research-methodology.md` and use the fetching patterns
from `${CLAUDE_SKILL_DIR}/github-fetching-patterns.md`.

**For each repo, fetch and process:**

| Source | What to capture |
|--------|----------------|
| Repository metadata (API) | Description, language, topics, stars, last push |
| README | Purpose, getting started, architecture overview |
| Repository tree (API) | Project structure, module boundaries |
| Latest release (API) | Version, release date, release notes |
| CHANGELOG | Breaking changes, deprecations, notable additions |
| Key source files | Public API surface, type definitions, exports |

**Write findings to** `.claude/reference-knowledge/{alias}/` using the
templates from `${CLAUDE_SKILL_DIR}/knowledge-schema.md`:

| File | What to record |
|------|----------------|
| `architecture.md` | Project layout, key abstractions, design decisions |
| `api-surface.md` | Public exports, types, configuration, usage patterns |
| `patterns.md` | Implementation idioms, testing approach, extension points |
| `changelog.md` | Version timeline, breaking changes, deprecations |
| `_meta.yaml` | `last_fetch_date`, `latest_version`, files fetched |

Only create files for categories listed in the repo's `focus` config. If no
`focus` is specified, create all four.

### 2. Cross-Project Analysis

After updating individual repos (if more than one was refreshed), review
the cross-project analysis guidance in
`${CLAUDE_SKILL_DIR}/cross-project-analysis.md`.

Update `.claude/reference-knowledge/_cross-project/`:
- `shared-patterns.md` — patterns observed in 2+ repos
- `comparison.md` — side-by-side analysis of how repos handle similar concerns

### 3. Discovery (if requested)

If the user passed "discover" as an argument:

1. Scan the consumer project for clues:
   - `package.json` dependencies and devDependencies
   - `go.mod`, `Cargo.toml`, `pyproject.toml` dependencies
   - Import statements in source files
   - README mentions of related projects
2. WebSearch for comparable projects:
   - Search for alternatives and similar projects
   - Search for projects in the same domain/ecosystem
3. Filter out repos already in `.claude/references.yaml`
4. Present suggestions with:
   - Repo slug and description
   - Why it might be relevant
   - Suggested alias and relevance note
5. Do NOT auto-add repos. Present suggestions and let the user decide.

### 4. Update Global Metadata

Update `.claude/reference-knowledge/_meta.yaml` with:
- `last_global_refresh: <unix-timestamp>`
- `config_hash` — hash of current `references.yaml` to detect future changes

### 5. Update Agent Memory

Write any NEW methodological learnings to
`~/.claude/agent-memory/reference-researcher/`:
- Research techniques that worked well or poorly
- GitHub fetching strategies discovered
- Rate limit encounters and workarounds
- Update `last_fetch_date` in MEMORY.md

**Do NOT write repo-specific knowledge to agent memory.**

## Report

Output a concise summary:
- Repos refreshed and their latest versions
- Key changes since last refresh per repo
- New patterns or breaking changes discovered
- Cross-project insights updated
- Discovery suggestions (if requested)
- Issues encountered (404s, rate limits, missing data)
