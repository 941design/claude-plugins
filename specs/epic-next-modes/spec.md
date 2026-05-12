# /base:next — Detail and Auto Modes

## Problem

`/base:next` is the dispatcher that promotes the top actionable
`BACKLOG.md ## Findings` entry into a `/base:feature` or `/base:bug`
run. Step 4 of `plugins/base/commands/next.md` (the Confirmation Gate)
asks the user to pick from the top-3 actionable findings whenever more
than one exists — but it surfaces each candidate as just its **raw
bullet text plus a classification tag** (`bug` / `feature-work`). When
the three candidates touch the same area of the codebase, share
overlapping vocabulary, or were logged on the same day during a single
`/base:feature` run, the user cannot meaningfully triage between them
from the gate output alone. The practical workaround is to abort,
re-read `BACKLOG.md` in another buffer, possibly cross-reference the
anchor files, then re-invoke — friction the dispatcher is supposed to
remove.

The asymmetry compounds: the 1-actionable-finding case dispatches
silently with no prompt at all (Step 4 AC-NEXT-9), while the
≥2 case prompts with thin context. So the dispatcher *is* opinionated
enough to act unattended in some cases, but never offers the user that
trust in the higher-volume case. A user who is happy with document
order has no way to opt out of the gate; a user who is unhappy with the
gate's brevity has no way to get more.

Source: BACKLOG.md finding promoted 2026-05-12,
`plugins/base/commands/next.md:93-115`.

## Solution

Introduce two named modes selected by a single positional argument:

- **`detail`** (default for bare `/base:next`). Renders each of the
  top-3 actionable candidates as a one-paragraph what/where/goal
  summary, built deterministically from the bullet text plus ±10 lines
  of the cited anchor file. Then asks via `AskUserQuestion` whether to
  dispatch #1, pick a different one from the list, or abort. Detail
  mode is consistent across counts — it renders a paragraph and
  confirms even when there is only one actionable finding.

- **`auto`** (`/base:next auto`). Silently dispatches the top
  actionable candidate. No paragraph synthesis, no prompt — straight
  to `/base:feature` or `/base:bug`. Question-halt behavior (the rule
  that a leading `question` finding stops the dispatcher with a
  resolution-paths nudge) is unchanged across both modes.

Mode is parsed in a new Step 0 ahead of the existing pipeline. Steps 1
(read), 2 (parse findings), 3 (classify), 5 (derive marker), 6
(dispatch), and 7 (return) are untouched. Step 4 (Confirmation Gate)
is the only existing step that changes — its rendering branches on
mode.

## Scope

### In Scope

- New Step 0 in `plugins/base/commands/next.md` parsing
  `$ARGUMENTS` into `mode ∈ {detail, auto}`; unknown tokens exit with
  a usage hint listing the two valid modes.
- Reworked Step 4 with two branches: `detail` (paragraph + prompt) and
  `auto` (skip prompt, dispatch).
- A new Step 4a documenting the paragraph synthesis routine: read
  anchor file ±10 lines, compose 3–5 sentences answering
  what / where / goal. Bounded to 3 reads per invocation (top-3).
- Updated frontmatter on `plugins/base/commands/next.md`:
  `argument-hint` reflects the new grammar; `description` mentions the
  two modes.
- Amendments to `specs/epic-base-next/`:
  - `acceptance-criteria.md` — tighten AC-NEXT-2 (mode grammar), revise
    AC-NEXT-9 (per-mode prompt contract), split AC-NEXT-10 into
    AC-NEXT-10a (detail rendering) and AC-NEXT-10b (auto dispatch).
  - `spec.md ## Amendments` — append a dated entry citing this epic
    and the source finding.
- Cross-reference from `/base:orient`'s Rule 8 "ranked menu" suggestion
  to mention the new mode if it usefully shortens the next-move
  description — small touch, optional.

### Out of Scope

- Re-ranking the candidate order. Auto-prioritization in `auto` mode
  means "the system picks #1 in document order" — not a new heuristic.
- Following citations inside finding bullets (e.g. recursing into a
  cited spec, ADR, or epic retro to enrich the paragraph). The
  paragraph reads only the anchor file ±10 lines.
- A `--verbose` or `--why` trace explaining the routing decision.
- Multi-anchor findings (`anchor1, anchor2`). Format is one anchor per
  bullet; not changing that here.
- Replacing `/base:orient` or merging its survey output into `/base:next`.

## Design Decisions

1. **`detail` is the default; `auto` is opt-in.** Reasoning: changing
   bare-invocation behavior to silent dispatch would surprise users who
   relied on the existing gate prompt. Opt-in for fire-and-forget is
   the safer migration path. The detail experience also subsumes the
   current ≥2 case (which already prompted) — strict improvement.

2. **Mode is a positional arg, not a flag.** `/base:next auto` matches
   the precedent set by `/base:feature backlog:<marker>` and
   `/base:bug backlog:<marker>` — short, discoverable, no `--` ceremony.
   Refs: `plugins/base/commands/feature.md`, `plugins/base/commands/bug.md`.

3. **Paragraph synthesis reads only the anchor file ±10 lines.** No
   recursion into cited specs, ADRs, or epic retros. Reasoning:
   bounded cost (3 small `Read` calls per invocation), good-enough
   context for triage, and citation-following would introduce
   ambiguity about which citation matters most. Cited-content readers
   already exist in the form of `/base:orient` and direct file reads
   — the user can always open the cited spec themselves after the
   gate surfaces it.

4. **Candidate ordering remains document order.** This epic does not
   introduce a new prioritization heuristic. The base-next spec
   (Design Decision 4) explicitly preserves user curation by reading
   `BACKLOG.md` in document order; that contract holds. "Auto-prioritization"
   in `auto` mode is shorthand for "the system selects #1 from the
   existing ordering" — not for re-sorting.

5. **Detail mode renders + confirms even with one actionable finding.**
   The current 1-finding silent dispatch is replaced *inside detail
   mode* by paragraph-render + confirm. Reasoning: detail mode's
   contract is "always give me context before dispatch"; behaving
   silently for one finding contradicts that. Users who want
   1-finding silence use `auto`.

6. **Auto mode question-halt behavior is unchanged.** A `question`
   finding appearing first in document order still halts the
   dispatcher with the resolution-paths nudge — auto mode does NOT
   auto-skip questions. Skipping would contradict epic-base-next
   Design Decision 5 (a leading question is itself a signal the user
   wanted to address it first).

7. **Paragraph composition is inline lead synthesis, not a subagent.**
   The lead (the session running the command) reads the anchor file
   and writes 3–5 sentences directly. Reasoning: spawning subagents
   to write three paragraphs is overkill for a dispatcher; the
   round-trip cost is the dominant friction we are trying to remove.

8. **No new tag scheme, no new analytics.** `/base:next` remains a
   thin dispatcher. The paragraph is rendered, then thrown away —
   it does not persist to `BACKLOG.md`, to a cache, or to the epic
   metadata. Each invocation regenerates from current state.

## Constrained by ADRs

<!--
None. The /base:next dispatcher is governed by epic-base-next's spec
rather than by any ADR. If a future ADR formalises argument grammar
across `/base:*` commands, this epic should be re-checked against it.
-->

- _no ADRs apply_

## Technical Approach

### `plugins/base/commands/next.md`

**Frontmatter changes**

```yaml
---
name: next
description: Pick the next actionable finding from BACKLOG.md and dispatch it. Default `detail` mode renders a paragraph per candidate and confirms; `auto` mode silently dispatches the top finding.
argument-hint: "(no args = detail) | auto"
allowed-tools: Read, Grep, Edit, Bash, AskUserQuestion, Skill
model: sonnet
---
```

`Grep` is added so paragraph synthesis can locate function or section
boundaries near the anchor line.

**New Step 0: Parse mode argument**

Inserted before the existing Step 1 (Read `BACKLOG.md`).

```
Read $ARGUMENTS, trimmed.

IF empty OR whitespace-only:
    mode = detail
ELSE IF token equals "auto" (case-sensitive):
    mode = auto
ELSE:
    Exit with usage:
        Unknown argument: <token>.
        Usage:
          /base:next         — detail mode (render + confirm top-3)
          /base:next auto    — auto mode (silent dispatch of top)
```

Steps 1, 2, 3, 5, 6, 7 are unchanged. Step 4 is reworked.

**Reworked Step 4: Confirmation Gate (mode-aware)**

```
Count actionable findings.

IF mode == auto:
    Dispatch the single selected candidate (the first actionable in
    document order, per Step 3). No prompt. Print a one-line
    "Dispatching as <bug|feature-work>: <truncated bullet>" notice
    so the user can see what was dispatched, then fall through to
    Step 5.

IF mode == detail:
    Take up to 3 actionable findings in document order.
    For each: synthesise a paragraph via Step 4a.
    Render to the user as:

        ## Top 3 actionable findings

        **1.** <anchor> → <classification>
              <paragraph>

        **2.** <anchor> → <classification>
              <paragraph>

        **3.** <anchor> → <classification>
              <paragraph>

    Then AskUserQuestion with options:
        - Dispatch #1
        - Dispatch #2 (only when #2 exists)
        - Dispatch #3 (only when #3 exists)
        - Abort

    On selection, continue to Step 5 with the chosen candidate.
    On abort, exit without dispatching.
```

**New Step 4a: Paragraph synthesis**

Invoked once per candidate by Step 4 in `detail` mode.

```
Inputs: a finding bullet (anchor + text + date) and the bullet's
classification (bug / feature-work).

1. Parse anchor:
     - "path:line" form  → path + line
     - "path" form       → path + (no line)
     - "-"               → no path; paragraph composed from bullet
                           text alone (skip steps 2-3)

2. Read the anchor file:
     - With line: Read file at line ± 10 (i.e. start = max(1, line-10),
                  limit = 21).
     - Without line: Read first 30 lines of the file.

   Any read failure (file not found, directory not found, permission
   denied, anchor path containing glob characters, anchor path
   ambiguous) is treated identically: fall back to bullet-only
   composition and append the literal string `(anchor file missing)`
   to the paragraph. The fallback note text is fixed — downstream ACs
   will assert on it verbatim.

3. (Optional, cheap) Grep the anchor file for the nearest preceding
   heading or function declaration to give the paragraph a name to
   anchor on. Skip if not obviously available — the paragraph still
   stands on bullet + line context.

4. Compose a paragraph (3–5 sentences) covering:
     - What the issue / opportunity is (from bullet prose, sharpened
       by anchor context).
     - Where the relevant code lives (named file, section, function).
     - Goal — what resolving it accomplishes for the user or system.

   The paragraph must be self-contained: a reader who has not seen
   the bullet should still understand what dispatching this finding
   would do.

5. Return the paragraph as a single string (no trailing whitespace).
```

Total reads per `/base:next` invocation in detail mode: 1 (`BACKLOG.md`)
+ up to 3 (anchor files). All anchor reads MAY run in parallel — they
are independent.

### `specs/epic-base-next/acceptance-criteria.md`

Three existing ACs need amendment. Exact patch text is owned by
this epic's `acceptance-criteria.md` (AC-AMEND-*), but the shape is:

- **AC-NEXT-2** — drop the "MUST NOT accept a positional argument"
  clause. Replace with: "MUST accept either no argument (interpreted
  as `detail` mode) or the literal token `auto` (interpreted as
  `auto` mode). MUST exit with a usage hint on any other argument.
  The `argument-hint` frontmatter field MUST be updated to reflect
  this two-mode grammar."
- **AC-NEXT-9** — was: "If `## Findings` contains exactly one
  actionable finding, the dispatcher MUST proceed to dispatch
  without prompting." Becomes mode-conditional: in `auto` mode the
  silent-dispatch rule still holds for any count; in `detail` mode
  the dispatcher MUST render a paragraph and confirm regardless of
  count.
- **AC-NEXT-10** — split into AC-NEXT-10a (detail-mode rendering
  contract: top-3 paragraphs, classification labels, three choice
  options) and AC-NEXT-10b (auto-mode dispatch contract: skip
  prompt entirely, fall through to Step 5 with the document-order
  top candidate).

### `specs/epic-base-next/spec.md`

Append a `## Amendments` entry:

```
**2026-05-12 — Added detail / auto modes (epic-next-modes).** AC-NEXT-2,
AC-NEXT-9, and AC-NEXT-10 were tightened to support a new positional
argument that selects between paragraph-rendering detail mode (default)
and silent-dispatch auto mode. Source: BACKLOG.md finding 2026-05-12
on `plugins/base/commands/next.md:93-115`. Rationale: the original
gate's bullet-only rendering was insufficient to triage between
similar-looking candidates.
```

### `/base:orient` (optional touch)

In the Rule 8 next-moves suggestion that already mentions `/base:next`,
no change is required — the new modes are backwards-compatible at the
suggestion level (`/base:next` still works). If we want to nudge users
who have many actionable findings, append: "(or `/base:next auto` if
you trust the top pick)." Cheap, single-line edit.

## Stories

- **S1 — Mode argument parsing** — Add Step 0 to
  `plugins/base/commands/next.md`. Update frontmatter (`argument-hint`,
  `description`, `allowed-tools` adding `Grep`). Defines the `detail` /
  `auto` / error grammar. Covers AC-MODE-1 (`detail` default),
  AC-MODE-2 (`auto` token), AC-MODE-3 (unknown-token usage hint), and
  AC-STRUCT-1 (frontmatter fields match the new grammar).

- **S2 — Auto-mode silent dispatch** — Rework Step 4 to branch on
  `mode`. The `auto` branch is the lighter of the two: it reuses the
  existing dispatch path with no prompt, prints the one-line
  "Dispatching as …" notice, and preserves the question-halt
  invariant unchanged (a leading `question` finding still halts the
  dispatcher — see the cross-cutting AC-INV-1 below). Covers
  AC-AUTO-1 (no prompt), AC-AUTO-2 (notice line), AC-AUTO-3
  (document-order top candidate).

- **S3 — Detail-mode paragraph synthesis and rendering** — Implement
  Step 4a (paragraph synthesis from anchor file ±10 lines) and the
  detail branch of Step 4 (top-3 rendering + AskUserQuestion).
  Preserves the same question-halt invariant (AC-INV-1) — detail
  mode also halts on a leading question, before paragraph synthesis
  runs. Covers AC-DETAIL-1 (top-3 rendering format), AC-DETAIL-2
  (prompt options), AC-DETAIL-3 (1-finding still renders + confirms),
  AC-PARA-1 (anchor read), AC-PARA-2 (fallback note `(anchor file
  missing)`), AC-PARA-3 (3–5 sentence what/where/goal shape).

- **S4 — Amend epic-base-next** — Tighten AC-NEXT-2, revise AC-NEXT-9,
  split AC-NEXT-10. Append `## Amendments` entry to
  `specs/epic-base-next/spec.md`. Covers AC-AMEND-1 (AC patches
  applied verbatim), AC-AMEND-2 (`## Amendments` entry written).

**Cross-cutting**: AC-INV-1 (question-halt holds in both modes —
neither `detail` nor `auto` auto-skips a leading `question` finding;
the resolution-paths nudge is identical to today's Step 3 behavior).
Goes in `acceptance-criteria.md ## Cross-Cutting Invariants`.

## Acceptance Criteria

See [`acceptance-criteria.md`](./acceptance-criteria.md).

## Relationship to Other Epics

- **epic-base-next** — This epic extends the dispatcher whose contract
  epic-base-next defined. `plugins/base/commands/next.md` is owned by
  epic-base-next; this epic adds a Step 0 and reworks Step 4, then
  amends epic-base-next's `spec.md` and `acceptance-criteria.md` so
  the durable behavior record stays single-sourced.

- **epic-pipeline-autonomous-retros** — No direct relationship. This
  epic does not touch the retro pipeline.

- **epic-lean-lead-decider** — No direct relationship. The dispatcher
  is lead-only; no Decider escalation paths are introduced.

## Non-Goals

- Not a general re-architecture of `/base:next`. Steps 1–3 and 5–7 are
  untouched; only Step 0 (new), Step 4 (reworked), and Step 4a (new)
  change.
- Not a re-ranking system. Document order is the contract.
- Not a telemetry, metrics, or analytics surface. The dispatcher
  remains stateless and writes nothing about its own execution.
- Not a citation-following enrichment. Paragraphs read the anchor
  file only; cited specs / ADRs / retros are surfaced by other
  commands (`/base:orient`, direct reads), not by this one.
- Not a replacement for `/base:orient`. Survey and dispatch remain
  distinct entry points.
