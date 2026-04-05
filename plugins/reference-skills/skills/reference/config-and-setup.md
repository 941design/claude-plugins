# Configuration and Setup

Reference for the `.claude/references.yaml` configuration file and the
`.claude/reference-knowledge/` directory structure.

## `.claude/references.yaml` Schema

```yaml
# Version of the config schema (currently 1)
version: 1

# List of GitHub repos to track
references:
  - repo: org/repo-name             # Required: GitHub org/repo slug
    alias: short-name                # Required: short name for queries
    relevance: "Why this matters"    # Required: context for the agent
    focus:                           # Optional: which knowledge categories
      - architecture                 #   to track. Default: all four
      - api-surface
      - patterns
      - changelog
    branch: main                     # Optional: branch to fetch from
                                     #   Default: repo's default branch

# Optional: group references by category
categories:
  core-libraries:
    - alias1
    - alias2
  infrastructure:
    - alias3

# Optional: discovery settings
discovery:
  enabled: true                      # Suggest new repos during updates
  auto_add: false                    # Always ask before adding (recommended)
```

### Required Fields

| Field | Description |
|-------|-------------|
| `version` | Schema version. Always `1` for now. |
| `references[].repo` | GitHub slug in `org/repo` format. |
| `references[].alias` | Short name used in queries and file paths. Lowercase, hyphens allowed. |
| `references[].relevance` | One sentence explaining why this repo is tracked. Helps the agent prioritize and contextualize findings. |

### Optional Fields

| Field | Default | Description |
|-------|---------|-------------|
| `focus` | All four categories | Subset of `[architecture, api-surface, patterns, changelog]` to track. |
| `branch` | Repo default | Branch to fetch from. |
| `categories` | None | Grouping for organization. Does not affect behavior. |
| `discovery.enabled` | `true` | Whether the agent suggests new repos during updates. |
| `discovery.auto_add` | `false` | Whether suggestions are added without confirmation. |

## Directory Structure

```
.claude/reference-knowledge/
├── _meta.yaml                       # Global metadata
├── {alias}/                         # One directory per tracked repo
│   ├── _meta.yaml                   # Per-repo metadata
│   ├── architecture.md              # If focus includes architecture
│   ├── api-surface.md               # If focus includes api-surface
│   ├── patterns.md                  # If focus includes patterns
│   └── changelog.md                 # If focus includes changelog
└── _cross-project/                  # Cross-repo analysis
    ├── shared-patterns.md
    └── comparison.md
```

Files are only created for categories included in the repo's `focus` list.
The `_cross-project/` directory is created once two or more repos have
been analyzed.

## Adding Repos After Setup

Two ways to add a new reference project:

### 1. Edit config and update
Add the entry to `.claude/references.yaml` manually, then run
`/reference-skills:reference-update`. The update skill detects new repos
in the config that have no knowledge directory and bootstraps them.

### 2. Re-run init
Run `/reference-skills:reference-init org/new-repo`. The init skill
detects the existing config and appends to it.

## Removing Repos

1. Remove the entry from `.claude/references.yaml`
2. Optionally delete the corresponding directory in
   `.claude/reference-knowledge/{alias}/`
3. The update skill will ignore repos not in config. Orphaned directories
   do not cause errors.

## `.gitignore` Guidance

The knowledge directory contains generated content that can be regenerated
by running the update skill. You have two options:

### Option A: Ignore (recommended for most projects)
```gitignore
# .gitignore
.claude/reference-knowledge/
```

Pros: keeps repo clean, avoids merge conflicts on generated content.
Cons: each team member must run their own initial fetch.

### Option B: Commit
Commit the knowledge files so the team shares accumulated knowledge.

Pros: team shares knowledge without re-fetching.
Cons: generated content in git, potential merge conflicts.

The `.claude/references.yaml` config file should **always be committed** —
it defines what the team tracks.

## Troubleshooting

### "Run reference-init first"
The advisory and update skills require `.claude/references.yaml` to exist.
Run `/reference-skills:reference-init` to create it.

### Stale knowledge
If knowledge feels outdated, run `/reference-skills:reference-update`.
Check per-repo `_meta.yaml` for `last_fetch_date` to see when each repo
was last refreshed.

### Rate limiting
If GitHub API returns 403, the agent will note this in `_meta.yaml` and
skip to the next repo. Wait an hour or authenticate (future enhancement).

### Missing knowledge files
If a repo directory exists but is missing expected files, the focus
categories may be restricted. Check `references.yaml` for that repo's
`focus` list, or run the update skill to regenerate.
