# Knowledge Schema

Templates and schemas for knowledge files stored in
`.claude/reference-knowledge/`.

## Per-Repo `_meta.yaml`

```yaml
repo: org/repo-name
alias: short-name
url: https://github.com/org/repo-name
branch: main
last_fetch_date: 1743542400          # Unix timestamp
latest_version: "2.1.0"             # Latest release tag, if any
primary_language: TypeScript
package_manager: npm                 # npm, cargo, go, pip, etc.
is_monorepo: false
relevant_packages: []                # For monorepos: which packages we track
files_fetched:                       # What we actually read last refresh
  - README.md
  - src/index.ts
  - src/types.ts
```

## Global `_meta.yaml`

```yaml
schema_version: 1
last_global_refresh: 1743542400      # Unix timestamp of last full refresh
config_hash: "abc123"                # Hash of references.yaml to detect changes
```

## Architecture Template (`architecture.md`)

```markdown
# {repo-alias} — Architecture

> Last updated: {date}  |  Version: {version}  |  Repo: {url}

## Overview
One paragraph: what this project is, its core abstraction, design philosophy.

## Project Layout
- Top-level directory structure with brief descriptions
- For monorepos: package map with dependency arrows

## Key Abstractions
- The 3-5 most important types/classes/modules and what they represent
- How they relate to each other (data flow, ownership, lifecycle)

## Design Decisions
- Notable architectural choices and their trade-offs
- What this project does differently from alternatives

## Dependencies
- Key external dependencies and why they're used
- Runtime vs build dependencies distinction
```

## API Surface Template (`api-surface.md`)

```markdown
# {repo-alias} — API Surface

> Last updated: {date}  |  Version: {version}

## Public Exports
List of primary exports with brief descriptions.

## Key Types / Interfaces
Type definitions that consumers interact with. Include actual signatures.

## Configuration
Options, settings, environment variables. Show the schema or type.

## Common Usage Patterns
2-3 code snippets showing typical consumption patterns.

## Gotchas
Non-obvious behavior, common mistakes, undocumented constraints.
```

## Patterns Template (`patterns.md`)

```markdown
# {repo-alias} — Implementation Patterns

> Last updated: {date}  |  Version: {version}

## Idioms
Recurring code patterns in this repo. How they structure modules,
handle errors, manage state.

## Testing Approach
How the project tests itself: unit, integration, e2e. Frameworks used.
Patterns worth adopting.

## Extension Points
How the project is designed to be extended: plugins, middleware,
hooks, event systems.

## Error Handling
How errors are represented, propagated, and reported.
```

## Changelog Template (`changelog.md`)

```markdown
# {repo-alias} — Changelog

> Last updated: {date}

## Version Timeline
| Version | Date | Highlights |
|---------|------|------------|
| x.y.z   | YYYY-MM-DD | Brief description |

## Breaking Changes
Changes that require consumer code modifications. Include migration steps.

## Deprecations
Features marked for removal. Timeline if known.

## Notable Additions
New capabilities relevant to the consumer project.
```

## Cross-Project Templates

### `_cross-project/shared-patterns.md`

```markdown
# Shared Patterns

Patterns observed across multiple reference repos.

## {Pattern Name}
- **Seen in:** repo-a, repo-b
- **Description:** What the pattern is
- **Variations:** How each repo implements it differently
- **Relevance:** Why this matters for the consumer project
```

### `_cross-project/comparison.md`

```markdown
# Reference Project Comparison

## Overview
| Aspect | repo-a | repo-b | repo-c |
|--------|--------|--------|--------|
| Language | ... | ... | ... |
| Approach to X | ... | ... | ... |

## Detailed Comparisons
### {Topic}
Side-by-side analysis of how repos handle a specific concern.
```
