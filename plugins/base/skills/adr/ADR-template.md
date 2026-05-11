# ADR-NNN: <Title>

**Status**: Accepted
**Date**: YYYY-MM-DD
**Type**: Lightweight
**Affects**: <comma-separated paths or `project-wide`>
**Supersedes**: <ADR-NNN | none>
**Superseded by**: <ADR-NNN | none>

## Context

What forces are at play. What constraints exist. What we know, what we
don't. Cite `path:line` for evidence of any claim about the codebase.

## Decision

What we decided. Specific enough to constrain future implementation —
"we use X" not "we prefer X-style approaches." If the decision codifies
a pattern of repeated rejections from `BACKLOG.md ## Archive`, list the
archive entries it absorbs.

## Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| <name> | <reason> |

For lightweight ADRs born from a single decision, one alternative may be
enough. For `Type: Debated` ADRs (born from `base:arch-debate`), this
table is populated from the debate rounds.

## Consequences

**Positive**: <what becomes easier, what is now possible>
**Negative**: <accepted costs, ergonomic regressions, complexity added>
**Accepted Risks**: <what we know we're not solving and why that's OK>

## Evolution Triggers

Conditions under which this ADR should be reopened:

- <named circumstance, e.g. "if library X reaches 1.0 with a stable API">
- <named circumstance, e.g. "if the rejected `gRPC` cluster reappears
  with a concrete cross-org driver">

## References

- Origin: <`base:arch-debate` | curator-promoted from N rejections | direct via `/base:adr`>
- Related ADRs: <ADR-NNN, ADR-NNN>
- Related specs: <specs/epic-foo, specs/epic-bar>
