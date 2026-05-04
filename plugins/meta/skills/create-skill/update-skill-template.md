# Update Skill Template

Path: `plugins/<plugin>/skills/<skill>-update/SKILL.md`

## Frontmatter

```yaml
---
name: <skill-name>-update
description: >-
  Maintenance skill that refreshes the <topic> knowledge base by fetching the
  latest <primary sources> and <domain> updates. Updates agent memory with
  new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific topic to update]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: <agent-name>
---
```

Key fields:

- `disable-model-invocation: true` — the agent never auto-invokes a refresh
  during normal Q&A; only the user runs it.
- `user-invocable: true` — surfaces it as `/<plugin>:<skill>-update`.

## Body

```markdown
## Knowledge Refresh Task

You are running a knowledge refresh for the <topic> knowledge base. This is
a maintenance task — do NOT answer user questions, only update your agent
memory.

**Important:** Write all findings to your agent memory directory ONLY.
Never modify files in the plugin/skill directory — those are read-only
artifacts managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Fetch documentation and release notes from each source. Use WebFetch for
raw content and WebSearch for recent developments.

**Sources to check:**

| Source | URL to fetch |
|---|---|
| <source 1> | <url> |
| ... | ... |

**For each source, capture:**
- Current version numbers
- New or modified API surfaces / features
- Breaking changes or deprecation notices
- Best practice changes

### 2. Search for Recent Developments

Use WebSearch for:
- "<topic> latest changes" — new features, breaking changes
- "<topic> best practices <year>" — updated guidance
- <3-5 domain-specific search queries>

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin
files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Current version numbers
- Key feature changes
- Summary of what changed since last fetch

**Topic files** — update or create as needed:

| File | What to record |
|---|---|
| `<topic>.md` | New or changed patterns and configurations |
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
```

## Worked example

For a complete, real update skill built from this template, see
`plugins/aws-skills/skills/cloudfront-update/SKILL.md`.
