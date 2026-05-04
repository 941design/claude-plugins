# Description Field Pattern (TRIGGER / SKIP)

This pattern applies to **both the agent file and the advisory skill** in a
knowledge-skill pair. The `description` field in the frontmatter is what
determines when the skill or agent fires — get it wrong and the skill is
silently skipped exactly when it would have helped.

## Why capability prose fails

A description like:

> Provides advice on Kubernetes deployments. Use this agent for any questions
> about cluster configuration, Helm charts, or kubectl.

reads naturally to a human but pattern-matches to "the user must explicitly
ask about Kubernetes." It misses the most common failure mode in
agent-driven workflows: an agent that is *itself* uncertain about an
in-domain API and would benefit from consulting the specialist. The agent
shrugs and guesses instead of firing the skill.

## The required shape

```yaml
description: |-
  <One-sentence positioning — what this is the authoritative source for.>

  TRIGGER when: <semicolon-separated concrete conditions — e.g. "about to
  reference X APIs in code, comments, specs, proposals, PR descriptions,
  or documentation; about to claim a method exists or has a given
  signature; uncertain or guessing about an X API shape; user mentions
  Y, Z, or W; about to write or modify a file that imports `x-core`">.
  Fire even if the user did not explicitly ask — agent self-detected
  uncertainty about an in-domain API alone is a sufficient trigger.

  SKIP when: <concrete conditions where the skill does NOT apply,
  semicolon-separated; reference the sibling skill/agent that should
  handle each case>.
```

## Rules

- Use the `|-` literal block scalar (not `>-` folded) so blank lines and
  paragraph structure render exactly as written.
- Stay under ~150 words. Descriptions are truncated to 1,536 characters in
  the skill index.
- **Always** include "agent self-detected uncertainty about <domain> APIs"
  as a TRIGGER condition. Without it the skill misses the most common
  failure mode: an agent guessing rather than asking.
- **Always** include "writing specs, proposals, or documentation that
  references <domain> APIs" — not just code. Specs are where guessed APIs
  do the most harm.
- **Always** include at least one SKIP clause that points at the correct
  fallback (a sibling skill or agent) so the trigger does not over-fire on
  adjacent domains.

## Provenance

This pattern is empirically used by Anthropic-shipped skills (e.g.
`claude-api`) and outperforms capability prose at firing in agent-driven
workflows. It is not documented in the official Claude Code skill docs but
is a 941design plugin convention for this reason.

## Worked examples

See:

- `plugins/nostr-skills/skills/marmot/SKILL.md` — TRIGGER/SKIP on the
  advisory skill side.
- `plugins/nostr-skills/agents/marmot-researcher.md` — TRIGGER/SKIP on the
  agent side.

Both follow the literal shape above.
