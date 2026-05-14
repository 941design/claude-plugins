---
name: spec-template
description: >-
  Canonical format reference for `specs/epic-<slug>/` directories consumed by
  `base:feature`, `base:bug`, and `base:implement-full`. Documents the required
  structure of `spec.md` and `acceptance-criteria.md`, the AC ID scheme, the
  story stub conventions, and the on-disk file layout. Provides fillable
  templates and an optional scaffolding mode. Use when authoring a new
  specification, when an existing spec fails validation, or when consuming
  skills cite this skill on a malformed input.
user-invocable: true
argument-hint: "[epic-slug — when provided, scaffolds specs/epic-<slug>/ from the templates; empty for the format reference]"
allowed-tools: Read, Write, Bash
---

## Purpose

This skill is the authoritative reference for the format that `base:feature`,
`base:bug`, and `base:implement-full` consume. The format is load-bearing:
section names, AC ID schemes, and the `spec.md` ↔ `acceptance-criteria.md`
split are all relied on by downstream tooling. This skill documents the
conventions inline so that authors do not have to reverse-engineer them from
existing specs.

The skill is **opt-in by reference**, not auto-loaded. `base:feature`,
`base:bug`, and the `spec-validator` / `story-planner` agents cite it on
demand (e.g. "spec rejected: missing `## Non-Goals` — see `base:spec-template`").

## Mode of operation

```
IF $ARGUMENTS is empty:
    Present the format reference below. Offer to scaffold if the user
    confirms an epic slug.
ELSE:
    Treat $ARGUMENTS as a kebab-case epic slug.
    Scaffold specs/epic-<slug>/spec.md and acceptance-criteria.md from
    the templates at:
      - ${CLAUDE_SKILL_DIR}/spec-template.md
      - ${CLAUDE_SKILL_DIR}/acceptance-criteria-template.md
    Refuse if specs/epic-<slug>/ already exists. Do not generate any
    project-specific content — only fill in the title from the slug.
```

The skill is documentation + optional scaffolding, not a code generator.

---

## Directory layout

Every epic lives in its own directory under `specs/`:

```
specs/epic-<kebab-slug>/
├── spec.md                  # REQUIRED — feature specification
├── acceptance-criteria.md   # REQUIRED — testable assertions
├── stories.json             # OPTIONAL — story definitions (see schema)
├── epic-state.json          # OPTIONAL — state machine (managed by base:feature)
├── exploration.json         # OPTIONAL — codebase exploration findings
├── mocks-registry.json      # OPTIONAL — temporary mock tracking
└── <NN>-<story-name>/       # OPTIONAL — per-story directories, NN = "01", "02", …
    ├── baseline.json
    ├── verification.json
    └── result.json
```

The slug is kebab-case, lowercase, alphanumeric + hyphens only. Story
directories use the two-digit story id from `stories.json` (`01`, `02`, …)
plus a kebab-case name.

`stories.json` follows the schema at `plugins/base/schemas/stories.schema.json`.

---

## `spec.md` — required sections, in order

```markdown
# <Title>

## Problem

Narrative. What is broken, missing, or unspecified. State the user-visible
or operational consequence — not just "the code does X". One or two
paragraphs is usually enough.

## Solution

Narrative. What we are going to do, at the level of intent. Not
implementation detail — that lives in `## Technical Approach` below.

## Scope

### In Scope

- Bullet list of work items this epic will deliver.

### Out of Scope

- Bullet list of items deliberately deferred to other epics. Distinct from
  `## Non-Goals` (see below).

## Design Decisions

Numbered list. Each item states the decision and its rationale, often with
`file:line` refs to anchor the decision to existing code. When a decision
is constrained by an ADR, cite it inline.

1. **<Decision>** — <rationale>. Refs: `path/to/file.py:42`.
2. **<Decision>** — <rationale>. Per ADR-007.
3. …

## Constrained by ADRs

(Optional.) ADRs that constrain the work in this epic. Distinct from
`## Design Decisions` above — this is a pure pointer list, not the place
to restate the decision. Use when an ADR is load-bearing for the spec
(usually `Affects:` of that ADR includes this epic).

- **ADR-007** — Auth flow: bunker-only signing.
- **ADR-014** — No new gRPC services.

## Technical Approach

Subsections per affected file or component. Code sketches are illustrative,
not binding — implementation may diverge as long as the ACs still pass.

### `path/to/affected/file.py`

<What changes here, why, and a sketch if non-obvious.>

## Stories

Preview of the story breakdown. Stable IDs (`S1`, `S2`, …) that match
`stories.json` once it exists. AC tags here cross-reference
`acceptance-criteria.md` sections.

- **S1 — <name>** — <one-line description>. Covers AC-<TAG>-N, …
- **S2 — <name>** — …

## Acceptance Criteria

See [`acceptance-criteria.md`](./acceptance-criteria.md).

## Relationship to Other Epics

- **epic-<slug>** — <one sentence on how the two relate>.

## Non-Goals

- Bullet list of explicit exclusions at the *project direction* level.
  Distinct from `## Out of Scope`:
    - **Out of Scope** = "not this epic, may be a future epic".
    - **Non-Goals** = "not the project's direction at all".

## Amendments

(Optional, append-only.) Post-completion changes to this spec. The base
plugin treats specs as **living documents**: when a backlog finding
resolves with `[done→spec:specs/epic-<slug>/]`, the change is recorded
here so the spec stays the durable behavior record without losing the
historical decision trail.

Each amendment names the date, the AC IDs added or modified, the source
(finding, bug report, or PR), and a one-line rationale. The actual AC
text changes happen inline in `## Acceptance Criteria` (or, for the AC
file, in `acceptance-criteria.md`); this section is the audit trail.

- **2026-05-11** — Added `AC-ERR-7`. Source: BACKLOG finding `auth/login.ts:142`. Rationale: regression test surfaced missing handling for refresh+login race.
- **2026-05-20** — Tightened `AC-STRUCT-3`. Source: bug report `bug-reports/refresh-loop-report.md`. Rationale: original AC allowed unbounded retry; tightened to 3.

`epic-state.json` does NOT re-open when the spec is amended; it remains
the workflow's run record. Spec history is recorded here.
```

### Section rules

- **Required sections** (must appear, even if content is "None known" —
  write that explicitly): `## Problem`, `## Solution`, `## Scope` (with
  `### In Scope` and `### Out of Scope`), `## Design Decisions`,
  `## Technical Approach`, `## Stories`, `## Acceptance Criteria`,
  `## Relationship to Other Epics`, `## Non-Goals`.
- **Optional sections**: `## Constrained by ADRs` (omit when no ADRs
  apply) and `## Amendments` (omit until the first amendment is
  recorded; once present, append-only).
- **The spec describes intent.** It must not duplicate prose from
  `acceptance-criteria.md`. The AC file describes observable assertions;
  the spec describes what we are doing and why.
- **Story IDs (`S1`, `S2`, …) are stable references.** If a story is
  removed, do not renumber the rest — leave a one-line "S2 — *removed*"
  entry so existing references stay valid.
- **Amendments are append-only.** Never rewrite or reorder existing
  entries. If a prior amendment was wrong, add a new entry that
  supersedes it (with `Supersedes: 2026-05-11 entry`).

---

## `acceptance-criteria.md` — required sections

```markdown
# <Title> — Acceptance Criteria

## Terminology

Defines any symbols, abbreviations, or fixture names referenced by ACs in
this file. One bullet per term.

- **<term>** — <definition>.

## <Concern> (S<N>)

One section per story or cross-cutting concern. The header includes the
matching story id from `stories.json`. ACs in this section MUST cover the
work in that story.

**AC-<TAG>-N** — <observable assertion in MUST/MUST NOT form>.

**AC-<TAG>-M** — …

## Cross-Cutting Invariants

ACs that span multiple stories. Same `AC-<TAG>-N` form.

## Manual Validation

(Optional.) One-shot human checks that cannot be automated, e.g. visual
regressions or third-party UI flows.
```

### AC ID scheme

The form is `**AC-<TAG>-<N>**` where:

- `<TAG>` is a short uppercase token grouping ACs by category. Common tags:
    - `STRUCT` — structural assertions about files, schemas, types.
    - `DEP` — dependency or integration assertions.
    - `ERR` — error-handling assertions.
    - `PERF` — performance assertions.
    - `SEC` — security assertions.
    - `OBS` — observability/logging assertions.
    - `UX` — user-visible behavior assertions.
  Authors may introduce new tags as needed; keep the set small and
  self-documenting.
- `<N>` is a 1-based integer **unique within its tag** (not across the
  entire AC file). `AC-NEXT-1` and `AC-BUG-1` can coexist — the counter
  resets for each tag. This matches every existing AC file.
- IDs are **stable, not sequential numbering**. When an AC is removed,
  do not renumber the rest. Leave a `**AC-<TAG>-N** — *removed*` line so
  existing references in stories.json, verification questions, and PR
  descriptions remain valid.
- The schema at `plugins/base/schemas/stories.schema.json` enforces the
  form `^AC-[A-Z]+-[0-9]+$` for `acceptance_criteria` entries in
  `stories.json`.

### AC content rules

- **Observable.** Each AC MUST be checkable from a test run, a build, or a
  single CLI invocation. "The system feels responsive" is not an AC.
- **MUST / MUST NOT.** Use RFC 2119 normative language. Avoid "should",
  "may", "would" — those are not assertions.
- **Named artifacts.** Reference the specific function, field, file, or
  endpoint by name. Generic subjects ("the data", "the system") are
  banned (mirrors the `story-planner` agent's AC precision rules).
- **State-change language.** Subject + verb + observable resulting state.
  Ban intent phrases ("so that", "in order to", "enabling").
- **Cross-references.** ACs may reference invariant or contract IDs from
  `spec.md` by greppable token: `AC-RED-7 (A1)` references invariant
  A1 from spec.md.

---

## File-split conventions

| What | `spec.md` | `acceptance-criteria.md` |
|------|-----------|--------------------------|
| Intent / motivation | ✓ | ✗ |
| Design decisions and rationale | ✓ | ✗ |
| ADR pointers (when an ADR constrains the spec) | ✓ | ✗ |
| Code sketches | ✓ (illustrative) | ✗ |
| Story preview | ✓ | ✗ |
| Amendment audit trail | ✓ (`## Amendments`) | ✗ |
| Observable assertions | ✗ | ✓ |
| Test-checkable invariants | ✗ | ✓ |
| Terminology used by ACs | ✗ | ✓ |

A reader of `spec.md` alone should understand *what we are building and
why*. A reader of `acceptance-criteria.md` alone should know *what passes
or fails when implementation is done*. Each file stands on its own; prose
is not duplicated between them.

The actual AC text changes that an `## Amendments` entry refers to live
inline in `acceptance-criteria.md` (new ACs appended in the relevant
story section, tightened ACs edited in place). The `## Amendments`
section in `spec.md` is the audit trail; the AC file is the live
behavior contract.

---

## Templates

Fillable skeletons live alongside this skill:

- `${CLAUDE_SKILL_DIR}/spec-template.md`
- `${CLAUDE_SKILL_DIR}/acceptance-criteria-template.md`

When invoked with a slug argument, this skill copies them into
`specs/epic-<slug>/` with the title pre-filled from the slug. No other
content is generated — the templates are deliberately empty so the author
fills in project-specific material themselves.

---

## When consuming skills should cite this skill

- `base:feature` Step 2 (spec validation) on a missing required section,
  malformed AC ID, or duplicated prose between the two files.
- `spec-validator` agent on any structural finding.
- `story-planner` agent when emitting AC IDs into `stories.json`.
- Any human-authored PR review of a spec change.

The citation form is short and greppable, e.g.:

> spec rejected: `## Non-Goals` is missing — see `base:spec-template`.

---

## Amendments

- **2026-05-14** — Corrected AC ID scheme `<N>` uniqueness rule: per-tag resetting (counter resets per tag; IDs are unique within a tag, not globally across the file). Source: BACKLOG finding `plugins/base/skills/spec-template/SKILL.md:244`. Rationale: align spec with de facto convention — every existing AC file resets per tag; the spec was wrong, not the files.
