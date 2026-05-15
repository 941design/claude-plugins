---
name: orient
description: >-
  Read-only project orientation. Reads `BACKLOG.json`, every `specs/epic-*/epic-state.json`,
  `docs/adr/`, recent git activity, and proposes a 3-line "you are here" plus ranked
  next moves. Detects oscillation (live findings that match archived rejections),
  stale epics, missing reconciliation cache, and ADR-promotion candidates. Reads
  only (the single exception is auto-invoking `/base:backlog migrate-v3` when
  a legacy v2 `BACKLOG.md` is detected at startup — see Rule 0). Use on a fresh
  session, when resuming a repo after idle time, when `/base:feature` is invoked
  with no arguments, or when the user asks "what should I work on?" /
  "where are we?" / "what's the state of this repo?".
user-invocable: true
argument-hint: "(no arguments)"
allowed-tools: Read, Grep, Glob, Bash, Skill
---

## Purpose

The read-side counterpart to `base:project-curator`. The curator writes
project meta-state at the end of `/base:feature` and `/base:bug` runs;
`/base:orient` reads that state and proposes what to do next. **Never
writes; only suggests.**

The user retains every decision. This skill produces a tight situational
brief and a ranked menu of moves; the user picks.

---

## Inputs (all read-only)

- **`BACKLOG.json`** at repo root. If missing (and no legacy `BACKLOG.md`
  either), the first proposed move is "run `/base:backlog init` to bootstrap
  project state." Continue with whatever else is detectable.

  Use `plugins/base/skills/backlog/scripts/render.sh --format orient` for
  the human-facing view, or `scripts/query.sh '<jq-expr>'` to extract
  specific subsets. The schema is at
  `plugins/base/schemas/backlog.schema.json`; the semantic policy
  (resolution paths, scope axis, deferred reasons, tonality) is at
  `plugins/base/skills/backlog/references/format.md`.
- **Every `specs/epic-*/epic-state.json`.** Cross-checked against
  `BACKLOG.json#epics` — drift either way is surfaced.
- **`docs/adr/`** — list ADRs by number and title. Used for two checks:
  (a) constraint set when surfacing findings whose topic an ADR governs;
  (b) candidate-cluster detection in the rejection archive.
- **Git activity:**
    - `git status --short` — uncommitted work signals "in-progress, do not
      switch tasks lightly."
    - `git log --oneline -20` — recent direction.
    - `git log --since="60 days ago" --name-only -- 'specs/epic-*/'` —
      epic dirs untouched longer than 60 days are flagged as stale.

The skill does not read individual spec content unless one of the
detection rules below explicitly requires it (kept cheap by default).

---

## Detection rules

Run all rules; collect findings; rank next moves. Order matters — earlier
rules emit higher-priority moves.

### Rule 0 — BACKLOG format integrity

The canonical v3 grammar is JSON validated by
`plugins/base/schemas/backlog.schema.json`. The schema is the authority
for shape (required fields, enums, structural constraints); the policy
(resolution paths, scope axis, deferred reasons, tonality) is at
`plugins/base/skills/backlog/references/format.md`.

**Auto-migration on detection.** If a legacy `BACKLOG.md` exists at the
repo root and `BACKLOG.json` does NOT, print exactly one notice line:

> Detected legacy v2 `BACKLOG.md`; invoking `/base:backlog migrate-v3` before continuing.

Then invoke `Skill("base:backlog", args: "migrate-v3")` and read the
resulting `BACKLOG.json`. If migration fails, surface a high-priority
warning in "Worth your attention" and continue the remaining rules with
best-effort parsing of the legacy file.

**Schema malformations** (best-effort, no auto-fix): the JSON does not
parse; required top-level fields (`version`, `epics`, `findings`,
`archive`) are missing; `findings[]` has duplicate slugs;
`findings[i].deferred.reason` is outside the closed enum; an `epic.path`
does not match `^specs/epic-<slug>/$`. Run
`scripts/lib/common.sh` validation by reading the file via any backlog
script — if the script aborts with a validation error, surface that
verbatim. Emit a single surfacing in "Worth your attention" with the
specific malformations and a one-line fix suggestion.

### Rule 1 — Bootstrap

If `BACKLOG.json` is missing (AND no legacy `BACKLOG.md` to auto-migrate
from) → propose `/base:backlog init` as move #1 with the rationale
"N existing epic dirs, M ADRs, no project-state file yet —
`/base:backlog init` will scaffold BACKLOG.json AND seed `epics[]` from
the N existing dirs in one shot, then you'll be ready to triage."
**Continue with the remaining rules**; the ones that strictly require
BACKLOG.json (Rules 5–8) skip silently and the others (2, 3, 4, 9)
still produce useful signal.

### Rule 2 — Epic-vs-state drift

For each `specs/epic-*/`:
- **`BACKLOG.json` exists**:
    - Compute the entry's *expected* status from `epic-state.json#status`
      via the canonical mapping: `planning` → `IN_PROGRESS`,
      `in_progress` → `IN_PROGRESS`, `done` → `DONE`,
      `escalated` → `ESCALATED`. If the actual `epics[i].status` differs
      from the expected status (in *either direction*) → propose
      updating via `/base:backlog add-epic --path <p> --status <s>`.
      The general drift detector covers every combination, including
      those that `/base:feature` Step 6.1 *should* have written but
      didn't (e.g. crashed mid-write, `BACKLOG.json` was missing at
      Step 6.1 but exists now after a separate `/base:backlog init` run).
    - If the spec dir exists on disk but is missing from `epics[]`
      entirely → propose appending via `/base:backlog add-epic`.
    - If `epics[]` lists a spec dir that does not exist on disk →
      propose curator follow-up to remove via `update_epics_section`.
- **`BACKLOG.json` missing**: report the count of existing epic dirs and
  their statuses (from each `epic-state.json`) as a single bullet under
  "Worth your attention", paired with the Rule-1 bootstrap move.

### Rule 3 — Stale epics

Epic dirs whose newest tracked file is older than 60 days AND
`epic-state.json#status` is not `done` → flag as stale. Suggest either
resume or archive.

### Rule 4 — Reconcile cache miss

For each `IN_PROGRESS` epic, check whether
`specs/epic-<slug>/reconciliation.json` exists and matches the current
`(spec-sha, git-sha)` pair. Missing or stale → "RESUME on this epic will
trigger a RECONCILE phase; budget for it."

### Rule 5 — Backlog cap pressure

Use `scripts/query.sh '.findings | map(select(.deferred == null)) | length'`
to count live findings (excluding deferred). If the live count > 15 →
emit a "prune or promote" move listing the oldest 5 (also live, not
deferred) via
`scripts/list.sh --status open --format compact | head -5`. Stale
findings (date > 90 days old) lead the list.

### Rule 6 — Oscillation

For each entry in `findings[]` where `.deferred == null` (deferred
findings are deferred work, not active concerns; comparing them to the
archive double-counts against the live oscillation signal), compare
against `archive[]`:
- **Hard match**: identical `anchor.path` (with same `line`/`range` if
  present) appears in an archive entry → surface verbatim, "previously
  rejected YYYY-MM-DD because <reason>."
- **Soft match**: anchor path matches AND the prose is semantically
  close (judge yourself; archive is small, reading it is cheap) →
  surface as "possible re-decision."

### Rule 7 — ADR-worthy archive cluster

Scan `archive[]`. If three or more entries share a common rationale
(same substantive reason, not just the same topic) → propose
`/base:adr <cluster-title>` as a move. Quote the cluster verbatim in the
proposal so the user can verify the pattern.

### Rule 8 — Findings ready to promote

A finding that has been on the list ≥ 30 days without resolution is a
candidate for promotion to an epic (`/base:feature backlog:<slug>`) or
for a `/base:bug` run — read its prose to decide which workflow
applies, or just let `/base:next` classify and dispatch. Findings that
have been resolved in the user's head but never closed in BACKLOG.json
should get `/base:backlog resolve <slug> --as ...` as the suggested
next move.

**Skip findings where `.deferred != null`** in this rule. They are
deferred until the user un-stamps or resolves them, and their age clock
applies to the *un-deferred* lifetime — surfacing them as "ready to
promote" would re-invite the same auto-abort loop.

### Rule 9 — ADRs awaiting acceptance

For each `docs/adr/ADR-*.md`, read only the `**Status**:` line (cheap).
ADRs with `Status: Proposed` (not yet `Accepted`) are surfaced in
"Worth your attention" so they don't rot. List them by number + title;
suggest the user either accept (edit the Status line) or supersede
(`/base:adr <new-title> supersedes:ADR-NNN`). Do not propose acceptance
as a top-3 move — this is awareness, not action.

---

## Output shape

The output is human-facing prose. No JSON. Structure:

```markdown
## You are here

- Branch: <branch> (<N> uncommitted files)
- Recent direction: <one line summarizing last 20 commits>
- Open epics: <N> (<list of slugs>)
- Open findings: <N> (cap is 15)
- Rejections on file: <N>

## Next moves

1. **<verb-led title>** — <one-line rationale>. Run: `<exact command>`.
2. **<verb-led title>** — <one-line rationale>. Run: `<exact command>`.
3. **<verb-led title>** — <one-line rationale>. Run: `<exact command>`.

## Worth your attention

- <oscillation flag, stale epic, cluster candidate, or any other rule output>
- <one bullet per detection finding worth surfacing but not as a top-3 move>
```

Cap at **3 next moves**. Anything else goes in "Worth your attention" so
the prompt stays scannable.

If nothing is worth a move ("repo is in a clean steady state, no findings,
no stale epics") say so plainly in two sentences and stop.

---

## What this skill never does

- **No writes.** Not to `BACKLOG.json`, not to spec dirs, not to
  `CLAUDE.md`, not anywhere. The single exception is the Rule 0
  auto-invocation of `Skill("base:backlog", args: "migrate-v3")` when a
  legacy v2 BACKLOG.md is detected — the write itself happens inside the
  `backlog` skill, gated to the user-visible notice line. If a move
  requires a write (most do), the move's `Run:` line is the user's
  explicit invocation.
- **No autonomous follow-through.** Surfacing a finding is not the same as
  acting on it. The user picks from the ranked menu.
- **No spec content reading by default.** Spec files are large; reading
  them all on every orient run would be expensive. Read the minimum each
  detection rule requires (mostly `epic-state.json` and the relevant
  fields of `BACKLOG.json`).
- **No memory writes.** Orientation is per-session; persistence belongs to
  the curator.

---

## Calibration

Bias **toward surfacing the negative-space items** the user would
otherwise miss:

- An archive entry that looks like the topic of a current finding.
- An epic dir that has rotted out of `epics[]`.
- A stale finding the user almost certainly forgot.
- A cluster of related rejections that's earned an ADR.

Bias **away from surfacing things the user can already see**:

- Don't recap what the most recent commit did.
- Don't list every epic — surface counts and the in-progress one.
- Don't repeat ADR titles without a reason.

Mental model: if a returning Claude (or human) in three months would
naturally rebuild the same understanding by reading the code, don't
surface it. If they'd waste a day relitigating it, surface it.

---

## Relationship to `base:project-curator`

The curator and this skill share the same view of project state and the
same detection vocabulary. The curator is the **write-side** maintenance
pass invoked at the end of `/feature` / `/bug`; orient is the
**read-side** suggestion pass invoked at the start of a session or on
demand. The two together form the maintenance loop:

```
   /feature ┐
            ├─→ project-curator (applies via scripts/* directly)
   /bug     ┘                                  │
                                               ▼
                              BACKLOG.json / specs / docs/adr/
                                               │
                                               ▼
                                         /base:orient (reads, suggests)
                                               │
                                               ▼
                                       user picks next move
                                               │
                                               ▼
                                   /feature, /bug, /adr, /backlog, …
```
