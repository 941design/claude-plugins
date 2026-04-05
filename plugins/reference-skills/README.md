# reference-skills

Reference project tracking and knowledge accumulation for Claude Code. Track
GitHub repos relevant to your project, progressively build knowledge about
their architecture, APIs, patterns, and evolution, and get answers grounded
in accumulated reference knowledge.

- Architecture analysis and design pattern extraction
- API surface mapping (types, interfaces, exports, configuration)
- Implementation recipe cataloging (idioms, testing, extension points)
- Changelog tracking (releases, breaking changes, deprecations)
- Cross-project pattern identification and comparison
- Semi-automatic discovery of related projects

## Installation

```bash
claude install-plugin 941design --name reference-skills
```

## Skills

### `/reference-skills:reference [question]`

Ask questions about tracked reference projects. Draws on accumulated knowledge
and fetches live data when needed.

```
/reference-skills:reference how does applesauce handle event filtering?
/reference-skills:reference compare error handling across all reference repos
/reference-skills:reference what's the public API surface of nostr-tools?
```

### `/reference-skills:reference-update [alias | discover]`

Refresh knowledge about tracked repos. Run periodically or when you need
the latest data.

```
/reference-skills:reference-update              # refresh all repos
/reference-skills:reference-update applesauce   # refresh one repo
/reference-skills:reference-update discover     # suggest new repos to track
```

### `/reference-skills:reference-init [org/repo ...]`

Set up reference project tracking for the current project. Run once to create
the configuration and bootstrap initial knowledge.

```
/reference-skills:reference-init hzrd149/applesauce nbd-wtf/nostr-tools
/reference-skills:reference-init                # guided setup with discovery
```

## Agent

### reference-researcher

Custom agent with **dual persistent storage**:

- **Project-local** (`.claude/reference-knowledge/`) — per-project knowledge
  about tracked repos. Architecture notes, API surfaces, implementation
  patterns, changelogs, and cross-project analysis.
- **Agent memory** (`~/.claude/agent-memory/reference-researcher/`) — global
  methodological learnings that improve research quality across all projects.

### First Run

Unlike other plugins that auto-initialize, reference-skills requires explicit
setup because reference repos are project-specific:

1. Run `/reference-skills:reference-init` with repo slugs or use guided setup
2. The init skill creates `.claude/references.yaml` and bootstraps knowledge
3. Run `/reference-skills:reference-update` for a comprehensive first refresh
4. Query with `/reference-skills:reference [question]`

The advisory skill auto-refreshes stale repos (older than 7 days) before
answering.

## Supporting Documents

| File | Content |
|------|---------|
| `research-methodology.md` | Tiered approach to studying repos: README, tree, API surface, deep dive |
| `knowledge-schema.md` | Templates for architecture, API, patterns, changelog knowledge files |
| `github-fetching-patterns.md` | GitHub raw URLs, API endpoints, WebSearch patterns, rate limiting |
| `cross-project-analysis.md` | Identifying shared patterns, comparison dimensions, decision support |
| `config-and-setup.md` | references.yaml schema, directory structure, .gitignore guidance |

## Configuration

### `.claude/references.yaml`

Defines which GitHub repos to track. Created by the init skill.

```yaml
version: 1
references:
  - repo: hzrd149/applesauce
    alias: applesauce
    relevance: "Modular reactive Nostr SDK — alternative to NDK"
    branch: master
  - repo: nbd-wtf/nostr-tools
    alias: nostr-tools
    relevance: "Primary JavaScript Nostr library"
    focus: [api-surface, changelog]
discovery:
  enabled: true
  auto_add: false
```

### `.claude/reference-knowledge/`

Project-local directory where accumulated knowledge lives. Created and
maintained by the agent. Consider adding to `.gitignore` (regenerable) or
committing (shared team knowledge).

## Development

Test locally:

```bash
claude --plugin-dir ./plugins/reference-skills
```
