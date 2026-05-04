# Advisory Skill Template

Path: `plugins/<plugin>/skills/<skill>/SKILL.md`

## Frontmatter

```yaml
---
name: <skill-name>
description: |-
  <Follow the TRIGGER/SKIP shape from description-pattern.md. One-sentence
  positioning, then TRIGGER when: ... ; SKIP when: ... . Include agent
  self-detected uncertainty as a trigger and at least one SKIP clause
  pointing at the sibling skill that handles adjacent work.>
argument-hint: "[question about <topic>]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: <agent-name>
---
```

Key fields:

- `context: fork` — runs in a sub-context so the parent conversation is
  not polluted with the agent's research and memory loads.
- `agent: <agent-name>` — binds this skill to its sibling agent so the
  agent's MEMORY.md and supporting docs are reachable via
  `${CLAUDE_SKILL_DIR}` and the agent-memory directory.

## Body

```markdown
## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Follow the
refresh procedure described in your agent system prompt (fetch <primary
sources>, write findings to agent memory only — never modify plugin files).

If memory is fresh, proceed directly to answering.

## User Question

$ARGUMENTS

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [<filename>](<filename>) | <description> |
| ... | ... |

Read the relevant documents to answer the user's question. Consult your
agent memory for additional context and prior findings.

## Response Format

- <domain-specific response guidelines, 5-8 bullets>
- If you need to fetch live documentation to verify details, do so.
```

## Worked example

For a complete, real advisory skill built from this template, see
`plugins/aws-skills/skills/cloudfront/SKILL.md`.
