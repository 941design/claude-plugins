# Negotiation protocol

Companion reference for `library-spec-negotiation`. The skill body cites
sections here for: round file structure, escalation envelopes, the
canonical `spec.md` / `acceptance-criteria.md` format, the
refactoring-plan template, and concrete examples.

## On-disk artifacts

```
specs/library-{slug}/
├── spec.md                       # the negotiated spec (final artifact)
├── acceptance-criteria.md        # observable acceptance criteria
├── acknowledgments.json          # JSON array — one entry per rep
├── refactoring-plans/
│   └── {rep_id}.md               # one per rep, authored by that rep
└── negotiation/
    ├── inputs.json               # CLI inputs (paths, user non-negotiables, slug)
    ├── reps.json                 # rep metadata (paths, project non-negotiables)
    ├── topics.json               # ordered topic list with status + round
    ├── state.json                # phase, current round, convergence flags
    ├── escalations.json          # log of escalations (open + closed)
    ├── guardian-findings.json    # guardian replies keyed by topic + round
    ├── discovery/
    │   └── {rep_id}.md           # Phase 1 dump per rep
    └── rounds/
        └── R{N}-{topic-slug}.md  # transcript per topic per round
```

## Message envelope schemas

All messages between the lead, reps, and guardian are JSON objects sent
via `SendMessage`. Use these envelopes verbatim — the lead parses them.

### Phase / task assignment (lead → rep, lead → guardian)

```json
{
  "type": "assignment",
  "phase": "discovery | negotiation | spec-review | acknowledgment | refactoring-plan",
  "topic": "<topic-slug or null>",
  "round": 0,
  "instructions": "<freeform text — the lead substitutes the templates from SKILL.md>"
}
```

### Completion ping (rep → lead, guardian → lead)

```json
{
  "type": "complete",
  "phase": "<same as assignment>",
  "topic": "<topic-slug or null>",
  "round": 0,
  "summary": "<one or two sentences>",
  "wrote": ["<relative path>", ...]
}
```

### Position (rep → file; not a SendMessage)

Positions are written to
`negotiation/rounds/R{N}-{topic-slug}.md`, not sent as messages. The
file structure is below under "Round file format".

### Peer discussion (rep ↔ rep)

```json
{
  "type": "peer",
  "topic": "<topic-slug>",
  "round": 0,
  "to_rep": "<other rep_id>",
  "ask": "<what you want from the peer>"
}
```

The peer replies with the same envelope and `ask` replaced by `reply`.
After a peer thread resolves, both reps update their position in the
round file. The lead reads the file; messages are not preserved
elsewhere.

### Escalation (rep → lead, guardian → lead)

```json
{
  "type": "escalation",
  "topic": "<topic-slug>",
  "involved": ["<rep_id>", ...],
  "issue": "<one paragraph>",
  "non_negotiable": "<which constraint blocks this, or null>",
  "tried": ["<round numbers / approaches that failed>"]
}
```

The lead either resolves it (by mediating) or surfaces it to the user
via `AskUserQuestion`. Every escalation, open or closed, is logged in
`escalations.json`.

### Guardian review (lead → guardian)

```json
{
  "type": "guardian-review",
  "scope": "topic | full-spec",
  "topic": "<topic-slug or null>",
  "round": 0,
  "spec_path": "specs/library-{slug}/spec.md",
  "round_file_path": "negotiation/rounds/R{N}-{topic-slug}.md or null"
}
```

### Guardian reply (guardian → lead)

```json
{
  "type": "guardian-reply",
  "scope": "topic | full-spec",
  "topic": "<topic-slug or null>",
  "round": 0,
  "verdict": "accept | nit | block",
  "findings": [
    {
      "severity": 1,
      "category": "non-negotiable | clarity | completeness | consistency | testability | scope",
      "where": "<spec section or round file pointer>",
      "issue": "<one paragraph>",
      "suggestion": "<optional>"
    }
  ]
}
```

`severity` is 1–10. `>= 7` is blocking; the guardian may also use
`verdict: "block"` directly when the issue is structural. The guardian
appends the same JSON object (plus a timestamp) to
`guardian-findings.json`.

## Round file format

`negotiation/rounds/R{N}-{topic-slug}.md`:

```markdown
# Round {N} — {Topic title}

## Positions

### Position: {rep_id_a}

- **What we currently do:** …
- **What we can accept:** …
- **What we cannot accept and why:** …
- **Non-negotiables at stake:** … (or "none")
- **Refactor we'd accept:** …

### Position: {rep_id_b}

…

## Peer threads

(optional; reps may briefly summarise a peer-to-peer outcome here)

### {rep_id_a} ↔ {rep_id_b} on {sub-question}

Outcome: …

## Proposed resolution

(written by the lead after positions are in)

…

## Guardian review

(populated after the lead asks the guardian; mirrors the verdict +
findings recorded in `guardian-findings.json`)
```

## Canonical `spec.md` structure

The spec is workflow-neutral. Use these top-level sections, in this
order:

```markdown
# {Library Title}

## Problem

What gap motivates the shared library? Why isn't the status quo
acceptable?

## Solution

The high-level shape of the library. Public surface in plain English.

## Scope

### In scope

…

### Out of scope

…

## Cross-cutting invariants

Non-negotiables that span topics (e.g. "all errors derive from
`LibError`", "no implicit thread spawning"). Anchor each to a project
non-negotiable in `reps.json` so reviewers can trace the requirement.

## Topics

One subsection per topic resolved in Phase 3, in the order of
`topics.json`. Each subsection states the agreed contract, not the
debate that produced it. Format:

### {Topic title}

- **Contract:** …
- **Rationale:** … (one or two sentences)
- **Provenance:** R{N}-{topic-slug}.md

## Public API sketch

Type signatures, function shapes, error types — language-neutral
pseudocode is fine. The acceptance-criteria file pins the observable
behaviour; this section sketches the surface.

## Non-goals

Things explicitly *not* part of the library. Each entry should reference
which project's non-negotiable would be violated by including it.
```

## Canonical `acceptance-criteria.md` structure

```markdown
# {Library Title} — Acceptance criteria

## Terminology

Short glossary if the topics introduced any non-obvious terms.

## {Topic 1}

**AC-{TAG}-{N}** — <observable assertion in MUST / MUST NOT form>

  - Source: R{N}-{topic-slug}.md → "Proposed resolution"
  - Verifiable by: <test sketch — what a reviewer would check>

## {Topic 2}

…

## Cross-cutting invariants

**AC-INV-{N}** — <invariant that must hold across topics>

## Per-project compatibility

For each rep, list the ACs that exercise that project's non-negotiables.
This is what the rep will check when signing acknowledgment.
```

### AC ID scheme

- Form: `AC-<TAG>-<N>` where `<TAG>` is uppercase (`ERR`, `CONC`,
  `TYPE`, `EXT`, `INV`, …) and `<N>` is a 1-based integer **unique
  within the file** (not per tag).
- Stable: if an AC is removed during iteration, leave a placeholder
  line `**AC-TAG-N** — *removed in round X*` so external references
  don't break.
- Regex: `^AC-[A-Z]+-[0-9]+$`.

### AC precision rules

1. **State-change language only.** Ban "so that", "in order to",
   "enabling", "ensures that". An AC asserts an observable change of
   state, not an intent.
2. **Named artifacts.** Reference a specific function / type / field by
   name. Ban generic "the data", "the result".
3. **End-to-end coverage.** If a behaviour spans multiple steps, write
   one AC per observable hop, not one omnibus AC for all of them.
4. **Verifiable.** A reader must be able to imagine the test that would
   prove or disprove it without further clarification.

## Examples — good vs. bad rep positions

### Bad

> "We need flexibility in the error model."

Useless: untestable, not a state, doesn't name a non-negotiable, gives
the lead nothing to draft.

### Good

> **What we currently do:** every recoverable error is an instance of
> `MyApp.Errors.RecoverableError` with a `code: str` field. Unrecoverable
> errors propagate as plain Python exceptions and crash the worker.
>
> **What we can accept:** a shared `LibError` base class so the field
> shape becomes `code: str, message: str, context: dict | None`.
>
> **What we cannot accept and why:** a Result-wrapper / Either-style
> return type. Our codebase has 200+ call sites assuming exception
> propagation. Migrating those is out of scope for this quarter.
>
> **Non-negotiables at stake:** `NN: errors propagate as exceptions, not
> as values`.
>
> **Refactor we'd accept:** rename our `RecoverableError` to
> `LibError.Recoverable`, drop the `code` field in favour of subclass
> identity, keep exception-based control flow.

Notice: every clause is concrete and falsifiable.

## Examples — valid vs. invalid non-negotiable softening

A non-negotiable is **softened invalidly** when:

- The spec drops the constraint silently and the user is not asked.
- The spec replaces "MUST" with "SHOULD" or "MAY" in the text that
  encodes the constraint.
- The spec moves the constraint to "Non-goals" without an escalation.
- The constraint is preserved in `cross-cutting invariants` but a topic
  resolution contradicts it elsewhere in the document.

A non-negotiable is **validly preserved** when:

- It appears verbatim or as a strictly stronger statement in the spec
  (cross-cutting invariants or a topic contract), traceable back to the
  rep that declared it.
- An AC pins the observable behaviour the constraint demands.
- The rep that owns it lists it under `non_negotiables_satisfied` in
  their `acknowledgments.json` entry, naming the spec section.

The guardian's job is to catch silent softening. If it spots one, it
returns `block` with `category: "non-negotiable"`.

## Refactoring plan template

Each rep authors `refactoring-plans/{rep_id}.md` in this shape:

```markdown
# Refactoring plan — {project name / rep_id}

Spec: `specs/library-{slug}/spec.md` (sha256 `{checksum}`)
Authored by: {rep_id}
Date: {ISO-8601}

## Summary

One paragraph: what the project's API/internals look like today, what
they look like after the refactor, and why the change is worth it for
this project specifically (not for the library; this rep speaks for the
project).

## Affected files

- `path/to/file.ext` — {what changes}
- …

## Downstream impact

Consumers of this project that would observe a breaking change, and
how the plan handles each:

- `{consumer name or path}` — {breaking change} — {handling: deprecation
  shim, compat module, version bump, etc.}

## Migration chunks

Ordered, independently-shippable. Each chunk has:

### Chunk 1 — {title}

- **Changes:** {bullet list of edits}
- **Proves it works:** {tests that would pass}
- **Rollback:** {how to revert if this chunk turns out wrong, without
  losing work in subsequent chunks}

### Chunk 2 — …

…

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| {one row per substantive risk} | low/med/high | low/med/high | … |

## Conditions on viability

If the rep signed `acknowledgments.json` with `viable: true` only under
specific conditions, list them here so the human reading the plan
months later understands what must hold.

## Open questions

Anything the plan cannot resolve without further input from the
project's stakeholders. The plan is allowed to leave these open — but
they must be visible.
```

## Escalation procedure

1. The escalator (rep or guardian) sends an `escalation` envelope to
   the lead.
2. The lead appends the envelope (with a timestamp and `status:
   "open"`) to `escalations.json`.
3. The lead attempts mediation (one extra round, or proposes a tradeoff
   that respects every non-negotiable).
4. If mediation fails, the lead surfaces the escalation via
   `AskUserQuestion`. The user's reply becomes the resolution.
5. The lead updates the escalation in `escalations.json`:
   `status: "resolved"`, `resolution: "<text>"`, `resolved_at:
   <ISO-8601>`.
6. The lead messages the involved reps with the resolution and proceeds.

## Convergence contract

The negotiation is **done** when, simultaneously:

- Every topic in `topics.json` has `status: "accepted"`.
- The full-spec guardian review returned `accept`.
- `acknowledgments.json` has one entry per rep, all `viable: true`,
  every `spec_checksum` matching the locked spec.
- `refactoring-plans/{rep_id}.md` exists for every rep.

If any of these does not hold, the negotiation is not done — regardless
of how many rounds have passed. Hard limits (5 rounds per topic, 3
full-spec review rounds) do not relax the convergence contract; they
trigger escalation to the user, who decides whether to keep iterating
or descope.
