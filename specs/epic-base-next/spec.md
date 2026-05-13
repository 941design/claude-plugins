# /base:next — Backlog Auto-Dispatch

## Problem

The `base` plugin gives the user three primitives for working from
`BACKLOG.md`:

- `/base:orient` — read-only triage. Reads `## Findings`, ranks moves,
  prints a menu. Never acts.
- `/base:feature backlog:<marker>` — promotes a finding to an epic and
  runs the feature flow.
- `/base:bug <description>` — fixes a bug from free-text input. **Does
  not read `BACKLOG.md`.**

The gap is the connective tissue between "I see what's next" and "do it":
the user must read the orient output, copy the finding marker, decide
which command to invoke based on the finding's `[type]` prefix, and run
it manually. The decision is mechanical — `[bug]` belongs in `/base:bug`,
`[chore]` and `[observation]` belong in `/base:feature` — but the user
performs it every time.

A secondary asymmetry: `/base:feature` has a `backlog:<marker>` mode that
promotes a finding atomically (scaffold spec, capture pending removal,
remove the source bullet only after `epic-state.json` succeeds; see
`plugins/base/commands/feature.md:54-76, 248-260`). `/base:bug` has no
counterpart, so a `[bug]` finding cannot be handed off without lossy
manual re-description.

`/base:implement-full` does not close the gap — it loops over spec files
and in-progress epics, not over `## Findings` entries.

## Solution

Two changes, shipped together:

1. **New command `/base:next`** — a thin dispatcher that picks the top
   actionable `## Findings` entry and routes it to the right workflow
   based on its `[type]`. One item per invocation. No looping (the user
   re-invokes, or uses `/base:implement-full` for spec-driven bulk work).

2. **New mode `/base:bug backlog:<marker>`** — symmetric with
   `/base:feature backlog:<marker>`. Reads `BACKLOG.md`, locates the
   named `[bug]` finding, scaffolds a `bug-reports/{slug}-report.md` from
   the finding's text and anchor, captures a `pending_finding_removal`
   marker, and falls through to the normal bug flow. The source bullet
   is removed only after `bug-reports/{slug}-result.json` has been
   successfully written, mirroring `/base:feature`'s atomicity rule.

`/base:orient` is unchanged. It remains the read-only entry point.

## Scope

### In Scope

- New file `plugins/base/commands/next.md` implementing the dispatcher
  (frontmatter, input handling, selection logic, dispatch table).
- Modifications to `plugins/base/commands/bug.md` to add a
  `backlog:<marker>` argument mode that mirrors the existing
  `BACKLOG_PROMOTE` mode in `feature.md`, including the deferred-removal
  atomicity rule.
- New marketplace entry for `/base:next` in the plugin's manifest /
  marketplace file (whichever this plugin uses to advertise commands; the
  implementer reads the plugin's existing `plugin.json` or marketplace
  file and follows the same pattern used for `/base:feature` and
  `/base:bug`).
- Cross-references from `/base:orient`'s next-move suggestions so that a
  user reading orient output sees `/base:next` as the natural follow-up
  ("ranked moves above; run `/base:next` to take the top one").

### Out of Scope

- **Looping.** `/base:next` handles exactly one finding per invocation.
  Bulk execution remains the job of `/base:implement-full` (specs/epics)
  or repeated `/base:next` calls (findings).
- **Reordering or filtering `## Findings`.** Selection rules are
  deterministic (see Design Decisions); the user reorders by editing
  `BACKLOG.md` directly or by resolving items via `/base:backlog
  resolve`.
- **Auto-resolving `[question]` findings.** Questions require human
  input; `/base:next` surfaces them and halts.
- **Editing finding text or anchor.** The dispatcher passes the marker
  through; spec/report pre-fill happens inside the target command, which
  already has that logic.
- **Changes to `/base:orient`'s detection rules.** Only the recommendation
  text is touched.

## Design Decisions

1. **Separate command, not a flag on `/base:orient`.** Adding execution
   to a read-only entry point is the textbook way to lose the
   predictability that makes `/base:orient` safe to invoke on session
   start, idle resume, or any "where am I?" moment. The three-layer
   model — `orient` (survey), `next` (pick-and-execute one), `implement-
   full` (bulk-finish specs) — keeps each command's contract singular.

2. **Dispatcher, not implementer.** `/base:next` does not duplicate the
   spec-scaffold or bug-report-scaffold logic. It identifies the target
   finding, validates the marker is unique, and invokes the appropriate
   command via the Skill tool with `backlog:<marker>` as the argument.
   The target command owns scaffolding, pre-fill, and atomic removal.

3. **`/base:bug` gains `backlog:<marker>` so dispatch isn't lossy.** A
   `[bug]` finding has structured text, an anchor (path[:line]), and a
   date. Reconstructing a free-text bug description from that loses the
   anchor's precision and the audit trail. Symmetric mode parity also
   means a user can invoke `/base:bug backlog:<marker>` directly without
   going through the dispatcher — the marker is the universal handle.

4. **Selection rule: highest-priority actionable finding wins.**
   "Actionable" means `[type] ∈ {bug, chore, observation}`. Within the
   actionable set, the rule is **first matching bullet in document
   order**. `BACKLOG.md` is hand-curated and ordered intentionally
   (`plugins/base/skills/backlog/references/format.md`); honoring that
   order matches user intent. No type-based priority weighting — that
   would override the user's curation.

5. **`[question]` findings halt the dispatcher.** If every actionable
   finding is exhausted or the document-order-top entry is a question,
   `/base:next` prints the question verbatim, suggests resolution paths
   (discuss now, or `/base:backlog resolve <marker> done-mechanical` /
   `rejected` / `done→spec:<path>`), and exits. It does not auto-skip
   questions to find the next non-question, because a question
   appearing first in document order is itself a signal that the user
   wanted to address it before downstream work.

6. **Multi-actionable confirmation gate.** If `## Findings` has more
   than one actionable entry, `/base:next` shows the top three and asks
   the user via `AskUserQuestion` whether to proceed with #1, pick a
   different one, or abort. Single-finding invocations skip the prompt
   and dispatch directly. Rationale: the dispatcher is opinionated about
   ordering, and a confirmation step is cheap insurance against
   dispatching the wrong item when the user's mental model of "next"
   diverges from document order.

7. **Atomicity inherited from target commands.** `/base:next` does not
   itself mutate `BACKLOG.md`. Removal of the source bullet happens
   inside `/base:feature` (existing) or `/base:bug` (new) only after the
   epic-state or bug-report-result file is written. If the target
   command aborts mid-flow, the finding remains in `## Findings` and a
   half-scaffolded artifact is left for `/base:orient` Rule 2 (drift
   detection) to surface on the next session.

8. **No new bug-report directory layout.** `/base:bug
   backlog:<marker>` writes `bug-reports/{slug}-report.md` exactly where
   the existing free-text path writes it. Slug derivation matches
   `/base:feature`'s rule: kebab-case from the finding's text, ≤40
   chars, confirmed via `AskUserQuestion` if ambiguous.

## Technical Approach

### `plugins/base/commands/next.md`

Frontmatter:

```yaml
---
name: next
description: Pick the next actionable finding from BACKLOG.md and dispatch it to the right workflow (/base:bug or /base:feature).
argument-hint: (no arguments)
allowed-tools: Read, Edit, Bash, AskUserQuestion, Skill
model: sonnet
---
```

Step outline:

1. **Read `BACKLOG.md`.** If missing, exit with the same hint
   `/base:orient` Rule 1 emits: "no `BACKLOG.md` — run `/base:backlog
   init` first."

2. **Parse `## Findings`.** Use the canonical bullet grammar from
   `plugins/base/skills/backlog/references/format.md`:
   `- [<type>] <anchor> — <text> (YYYY-MM-DD)`. If the section is empty
   (`- _no findings yet_`) or absent, exit with: "no findings to
   dispatch. Run `/base:orient` for a project-wide view, or
   `/base:backlog add-finding` to log one."

3. **Filter and pick.** Walk findings in document order. If the first
   actionable entry (`bug | chore | observation`) is preceded by any
   `[question]`, surface the question and halt (see Design Decision 5).
   Otherwise, the first actionable entry is the candidate.

4. **Confirmation gate.** If ≥2 actionable findings exist, show the
   top three via `AskUserQuestion` ("dispatch #1, pick another, or
   abort?"). Single-candidate: skip the prompt.

5. **Derive marker.** The marker passed to the target command must
   uniquely identify the finding inside `## Findings`. Use the anchor
   path component when present; otherwise the first 4–6 words of the
   text. The dispatcher itself does the uniqueness check (greps
   `## Findings` for the chosen substring; if >1 match, lengthen).

6. **Dispatch via Skill.**
   - `[bug]` → `Skill("base:bug", args: "backlog:<marker>")`
   - `[chore] | [observation]` →
     `Skill("base:feature", args: "backlog:<marker>")`

7. **Return.** The dispatcher exits as soon as the target Skill call
   returns. Its job is one dispatch, not workflow oversight.

### `plugins/base/commands/bug.md` modifications

Add a `BACKLOG_PROMOTE` branch in Step 1's input-mode detection,
modeled on `feature.md:54-76`:

```
IF argument starts with "backlog:":
    mode = BACKLOG_PROMOTE
```

`BACKLOG_PROMOTE` for `/base:bug`:

1. Read `BACKLOG.md`. Abort if missing (same message as feature.md).
2. Locate the matching `[bug]` finding under `## Findings`. If zero or
   >1 matches, abort with the candidates listed. **If the matched
   finding's type is not `[bug]`, abort with: "marker matched a non-bug
   finding; use `/base:feature backlog:<marker>` instead."** The
   dispatcher already routes correctly, but a direct user invocation
   could mis-type — fail loudly.
3. Derive a kebab-case slug from the finding's text (≤40 chars),
   confirm via `AskUserQuestion` if ambiguous.
4. Write `bug-reports/{slug}-report.md` with the finding's text in the
   description section and the anchor in the reproduction-steps section
   as a starting reference. Append a `Source: BACKLOG.md finding
   promoted YYYY-MM-DD` line.
5. Capture in-session `pending_finding_removal = <marker>`. **Do not
   remove the bullet yet.**
6. Fall through to the normal Step 1 flow (the bug report path is now
   set; Step 1's `IF argument is a .md file path` branch handles the
   rest naturally).

Bug.md's Step 4 (the closing step that writes
`bug-reports/{slug}-result.json`) gains a single addition: if
`pending_finding_removal` is set, perform a single read-modify-write on
`BACKLOG.md` to remove the source bullet from `## Findings`, mirroring
`feature.md:248-260`.

### `/base:orient` cross-reference

In the "Next moves" rendering, when at least one actionable finding
exists, append a suggestion line: `→ run \`/base:next\` to dispatch the
top finding automatically.` No detection-rule changes.

### Marketplace / plugin manifest

Add `/base:next` to whichever file advertises the plugin's commands.
The implementer reads the existing manifest, identifies the pattern
used for `/base:feature` and `/base:bug`, and replicates it.

## Risks

1. **Recursive Skill invocation depth.** `/base:next` calls
   `/base:feature` or `/base:bug` via the Skill tool. Both targets are
   substantial workflows. Confirm in implementation that nested Skill
   invocation does not hit any built-in depth cap and that the
   dispatcher's frontmatter (`allowed-tools: Skill`) is sufficient.

2. **`BACKLOG.md` parse drift.** If a user edits `BACKLOG.md` between
   `/base:orient`'s render and `/base:next`'s dispatch, the candidate
   ordering may shift. Mitigation: the confirmation gate (Design
   Decision 6) shows the user the current top three before dispatch.

3. **Slug collisions with existing bug reports.** If `bug-reports/`
   already contains a report with the derived slug, the BACKLOG_PROMOTE
   branch must not silently overwrite. Reuse `feature.md`'s pattern:
   confirm via `AskUserQuestion` with a numbered suffix suggestion.

4. **Type-prefix typos in `BACKLOG.md`.** A hand-edited finding with
   `[chor]` or `[Bug]` will fail the dispatch table. The dispatcher
   should validate `[<type>]` against the canonical set and surface a
   typo hint rather than silently routing.

## Amendments

**2026-05-12 — AC-ORIENT-1 conditionality tightened.** The original AC
said the `/base:next` suggestion line MUST appear when Rule 8 fires.
The as-built `orient/SKILL.md` placed the suggestion as unconditional
prose at the end of Rule 8's description block, leaving room for a
returning implementer to emit the suggestion on every orient run. The
AC now also says the suggestion MUST NOT appear when no qualifying
stale finding exists. Surfaced by `base:project-curator`; acknowledged
by user 2026-05-12.

**2026-05-12 — Added AC-BUG-9 (state.json marker persistence).**
`pending_finding_removal` was specified as in-session volatile state
only. The state.json schema in `bug.md` had no field for the marker,
so a crash between Step 1 (scaffold) and Step 4 (result.json write)
would silently orphan the `BACKLOG.md` source bullet on resume. New AC
requires persisting `backlog_marker` to `bug-reports/{slug}-state.json`
and a Crash Recovery instruction to restore `pending_finding_removal`
from it. Surfaced by `base:project-curator`; acknowledged by user
2026-05-12.

**2026-05-12 — Added detail / auto modes (epic-next-modes).** AC-NEXT-2 was tightened to accept either no argument (interpreted as `detail` mode) or the literal token `auto` (interpreted as `auto` mode), with the `argument-hint` frontmatter updated to reflect this grammar. AC-NEXT-9 was made mode-conditional: the 1-finding silent-dispatch path now only applies in `auto` mode; `detail` mode always renders the synthesised paragraph and confirms via `AskUserQuestion`. AC-NEXT-10 was split into AC-NEXT-10a (detail-mode rendering contract: top-3 paragraphs + classification labels + four-choice AskUserQuestion with conditional Dispatch #2/#3 inclusion) and AC-NEXT-10b (auto-mode dispatch contract: skip prompt entirely, print one-line `Dispatching as …` notice). Source: BACKLOG.md finding promoted 2026-05-12 on `plugins/base/commands/next.md:93-115`. Implementation lives in `plugins/base/commands/next.md` (Step 0, reworked Step 4, new Step 4a).

**2026-05-13 — Stamp/un-stamp lifecycle: scanner propagation and re-dispatch un-stamp.** Follow-up to the same-day amendment below, addressing three review findings. (1) AC-NEXT-22 was tightened: the hint-mode escape hatch now MUST rewrite the matched bullet in `BACKLOG.md` to strip the `[INSUFFICIENT: …]` prefix BEFORE dispatching, so downstream `/base:feature backlog:<marker>` and `/base:bug backlog:<marker>` slug and spec/report-stub derivation read clean text. If the un-stamp Edit fails the dispatcher aborts to avoid poisoned downstream artefacts. (2) New ACs AC-INSUFF-1/2/3 require `/base:orient` Rules 5 (cap pressure), 6 (oscillation), and 8 (ready-to-promote) to exclude stamped bullets — they are deferred and would otherwise be double-counted against the paired question finding that already represents the active concern. `plugins/base/skills/orient/SKILL.md` updated with the exclusion in each rule. (3) New AC AC-INSUFF-4 requires `base:project-curator` to exclude stamped bullets from its `append_finding` dedup check (so a stamped bullet does not suppress a fresh actionable finding on the same topic) and from the Recurrence rule's matching pass (so recurrences are not absorbed into a bullet `/base:next` will never pick). `plugins/base/agents/project-curator.md` updated at both sites. Format spec at `plugins/base/skills/backlog/references/format.md` now enumerates these exclusion points so future scanners pick them up by reference.

**2026-05-13 — Stamp `[INSUFFICIENT]` on auto-abort and accept content hints.** Two coupled changes addressing the BACKLOG finding "items rejected as insufficient are not marked in BACKLOG.md" and the just-discovered strict-argument-parse defect. (1) New ACs AC-NEXT-17/18/19: when `/base:next auto` catches `ABORT:UNDERSPECIFIED:<gap>` from the target skill, Step 6a now stamps the dispatched finding in `## Findings` by injecting `[INSUFFICIENT: <gap-truncated-to-80>] ` after the ` — ` separator (single `Edit` read-modify-write, with a graceful WARNING fallback when the Edit fails); Step 3 classifies stamped bullets as a new `insufficient` bucket that is skipped entirely. The stamp is durable across sessions, breaking the auto-mode re-rejection loop. (2) New ACs AC-NEXT-20/21/22/23: Step 0 no longer exits with a usage hint on non-empty non-`auto` arguments; instead the argument is treated as a content **hint**, with optional trailing ` auto` selecting auto-mode for the matched finding. Step 3 short-circuits the document-order walk in hint mode, picking the bullet with strongest content overlap (≥2 meaningful tokens matched, ≥1 token margin over second-best). An escape hatch re-runs the match including `insufficient` bullets when the first pass is empty, allowing the user to force re-dispatch of a stamped finding by naming it explicitly. Step 4 gains hint-aware branches: detail-mode renders a single `## Hint-matched finding` block with a two-option `Dispatch | Abort` prompt; auto-mode prints `Dispatching as <classification> (hint-matched): <truncated>` and falls through. Format spec extended at `plugins/base/skills/backlog/references/format.md` to document the new optional `[INSUFFICIENT: <gap>]` text prefix in `## Findings` bullets and to require scanners (`/base:next`, `/base:orient` Rule 0, `base:project-curator`) to skip stamped bullets. Source: BACKLOG.md finding on `plugins/base/commands/next.md` (2026-05-13). Implementation lives in `plugins/base/commands/next.md` (frontmatter, Step 0, Step 3, Step 4, Step 6a) and `plugins/base/skills/backlog/references/format.md`.
