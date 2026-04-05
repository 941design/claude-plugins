---
name: reference
description: >-
  Reference project knowledge advisor. Answers questions about tracked GitHub
  repos — their architecture, API surfaces, implementation patterns, and
  evolution. Draws on accumulated per-project knowledge and cross-project
  insights. Invoke for questions about reference projects, pattern comparisons,
  or API lookups across tracked repos.
argument-hint: "[question about reference projects, e.g. 'how does applesauce handle event filtering?']"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: reference-researcher
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read `.claude/references.yaml` to identify tracked repos. If this file does
not exist, tell the user to run `/reference-skills:reference-init` and stop.

Read `.claude/reference-knowledge/_meta.yaml` (global) and each relevant
repo's `_meta.yaml`. If any `last_fetch_date` does not exist, or if the
current timestamp minus `last_fetch_date` exceeds **604800** (7 days), you
MUST run a knowledge refresh for those stale repos before answering. Follow
the research methodology in the supporting documents and write all findings
to the project-local `.claude/reference-knowledge/` directory — never modify
plugin files.

If all relevant knowledge is fresh, proceed directly to answering.

## User Question

$ARGUMENTS

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [research-methodology.md](research-methodology.md) | Tiered approach to studying repos: README → tree → API surface → deep dive. Stopping criteria. Monorepo handling. |
| [knowledge-schema.md](knowledge-schema.md) | Templates for architecture.md, api-surface.md, patterns.md, changelog.md. _meta.yaml schemas. |
| [github-fetching-patterns.md](github-fetching-patterns.md) | Raw content URLs, GitHub API endpoints for trees/releases/metadata, WebSearch patterns, rate limiting. |
| [cross-project-analysis.md](cross-project-analysis.md) | Identifying shared patterns, comparison dimensions, connecting insights to the consumer project. |
| [config-and-setup.md](config-and-setup.md) | Full references.yaml schema, directory structure, adding/removing repos, .gitignore guidance. |

Read the relevant documents to inform your research approach. Consult your
agent memory for methodological insights from prior sessions.

## Response Format

- **Cite which reference repo** the answer comes from. Include repo alias and
  source file paths when known.
- Provide **concrete code examples** from reference repos when they illustrate
  a point — actual types, signatures, and patterns.
- When comparing repos, present **trade-offs** rather than rankings. Frame
  comparisons around the consumer project's specific context.
- **Flag knowledge age** — if findings are older than 14 days, note this.
- Connect findings to the **consumer project** — explain relevance, not just
  facts.
- If you need to fetch live documentation to verify details, do so.
