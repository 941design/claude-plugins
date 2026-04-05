---
name: reference-init
description: >-
  Initialize reference project tracking for the current project. Creates
  .claude/references.yaml config, sets up .claude/reference-knowledge/
  directory, and bootstraps knowledge by fetching initial data from specified
  GitHub repos. Run once per project to start tracking reference repos.
disable-model-invocation: true
user-invocable: true
argument-hint: "[github-org/repo ...] or empty for guided setup"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash, AskUserQuestion
context: fork
agent: reference-researcher
---

## Setup Task

You are initializing reference project tracking for this project. This is a
setup task — create the configuration and bootstrap initial knowledge.

$ARGUMENTS

## Procedure

### 1. Check Existing Configuration

Read `.claude/references.yaml`. If it exists:
- Show the current configuration (list of tracked repos)
- If `$ARGUMENTS` contains repo slugs, offer to ADD them to the existing config
- If `$ARGUMENTS` is empty, show the current config and ask what the user
  wants to change
- Do NOT overwrite existing config without confirmation

If it does not exist, proceed to step 2.

### 2. Identify Reference Repos

**If `$ARGUMENTS` contains repo slugs** (format: `org/repo`):
- Use those directly
- Validate each slug by fetching repo metadata from
  `https://api.github.com/repos/{org}/{repo}`
- Report any invalid slugs

**If `$ARGUMENTS` is empty** (guided setup):
- Scan the consumer project for clues:
  - Read `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, or similar
    for dependencies
  - Check README for mentions of related projects
  - Look at import statements in source files for external packages
- WebSearch for comparable projects in the same domain
- Present findings to the user via AskUserQuestion:
  - List discovered repos with descriptions
  - Ask which ones to track
  - Allow the user to add repos not in the list

### 3. Gather Metadata

For each selected repo, determine:
- **Alias** — derive from repo name (e.g., `applesauce` from `hzrd149/applesauce`).
  If there's ambiguity, ask the user.
- **Relevance** — if the user provided context, use it. Otherwise, generate a
  one-line relevance note from the repo description and ask the user to confirm
  or edit.
- **Focus** — default to all four categories (`architecture`, `api-surface`,
  `patterns`, `changelog`). Only ask about focus if the user specifies they
  want a subset.
- **Branch** — use the repo's default branch (from API metadata).

### 4. Write Configuration

Create `.claude/references.yaml` following the schema in
`${CLAUDE_SKILL_DIR}/config-and-setup.md`:

```yaml
version: 1
references:
  - repo: {org/repo}
    alias: {alias}
    relevance: "{relevance note}"
    branch: {branch}
  # ... one entry per repo

discovery:
  enabled: true
  auto_add: false
```

If appending to an existing config, preserve all existing entries and add
new ones at the end.

### 5. Bootstrap Knowledge

For each configured repo, perform an abbreviated initial fetch:
- Fetch README via raw.githubusercontent.com
- Fetch repository tree via GitHub API
- Fetch latest release via GitHub API
- Create the knowledge directory `.claude/reference-knowledge/{alias}/`
- Write initial `_meta.yaml` with fetch timestamp and version
- Write initial `architecture.md` with project overview from README and
  tree structure analysis
- Write initial `api-surface.md` if public exports are identifiable from
  the tree

Do NOT perform a deep dive at this stage — the init fetch should be quick.
A full refresh via `/reference-skills:reference-update` will fill in details.

Create `.claude/reference-knowledge/_meta.yaml`:
```yaml
schema_version: 1
last_global_refresh: {unix-timestamp}
```

### 6. Report

Output a summary:
- Configuration file created/updated at `.claude/references.yaml`
- Repos configured with their aliases
- Knowledge bootstrapped for each repo (what files were created)
- Suggest next steps:
  - "Run `/reference-skills:reference-update` for a full knowledge refresh"
  - "Run `/reference-skills:reference [question]` to query reference knowledge"
  - "Consider adding `.claude/reference-knowledge/` to `.gitignore`"
