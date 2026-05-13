---
name: orient
description: >-
  Read-only project orientation. Reads `BACKLOG.md`, every `specs/epic-*/epic-state.json`,
  `docs/adr/`, recent git activity, and proposes a 3-line "you are here" plus ranked
  next moves. Detects oscillation (live findings that match archived rejections),
  stale epics, missing reconciliation cache, and ADR-promotion candidates. Never
  writes. Use on a fresh session, when resuming a repo after idle time, when
  `/base:feature` is invoked with no arguments, or when the user asks "what should
  I work on?" / "where are we?" / "what's the state of this repo?".
user-invocable: true
argument-hint: "(no arguments)"
allowed-tools: Read, Grep, Glob, Bash
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

- **`BACKLOG.md`** at repo root. If missing, the first proposed move is
  "run `/base:backlog init` to bootstrap project state." Continue with
  whatever else is detectable.
- **Every `specs/epic-*/epic-state.json`.** Cross-checked against
  `BACKLOG.md ## Epics` — drift either way is surfaced.
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

### Rule 0 — BACKLOG.md format integrity

If `BACKLOG.md` exists but is malformed (missing one of the three required
top-level sections `## Epics`, `## Findings`, `## Archive`; or contains
duplicate section headers; or has a `## Findings` entry without the
documented `<anchor> — <text> (date)` shape; or has a `## Archive`
entry not in `YYYY-MM-DD — text — reason` shape) → emit a single
high-priority surfacing in "Worth your attention" with the specific
malformations and a one-line fix suggestion. **Do not stop**; downstream
rules continue with best-effort parsing. The format is documented in
`plugins/base/skills/backlog/references/format.md`; cite it in the
surfacing.

A leading `[label]` token on a `## Findings` entry is legacy and explicitly
NOT a malformation — earlier format versions required `[bug | chore |
question | observation]`; ignore residuals as prose.

### Rule 1 — Bootstrap

If `BACKLOG.md` is missing → propose `/base:backlog init` as move #1
with the rationale "N existing epic dirs, M ADRs, no project-state file
yet — `/base:backlog init` will scaffold BACKLOG.md AND seed `## Epics`
from the N existing dirs in one shot, then you'll be ready to triage."
**Continue with the remaining rules**; the ones that strictly require
`BACKLOG.md` (Rules 5–8) skip silently and the others (2, 3, 4, 9)
still produce useful signal. This matches the Inputs-section contract
above ("if missing, continue with whatever else is detectable") — the
seeding write is performed by the `backlog` skill's `init` op, not by
this skill (orient remains strictly read-only).

### Rule 2 — Epic-vs-state drift

For each `specs/epic-*/`:
- **`BACKLOG.md` exists**:
    - Compute the bullet's *expected* status from `epic-state.json#status`
      via the canonical mapping: `planning` → `IN_PROGRESS`,
      `in_progress` → `IN_PROGRESS`, `done` → `DONE`,
      `escalated` → `ESCALATED`. If the actual bullet status differs from
      the expected status (in *either direction* — `IN_PROGRESS`-bullet
      with `done`-state, `IN_PROGRESS`-bullet with `escalated`-state,
      `DONE`-bullet with `escalated`-state, etc.) → propose updating the
      bullet to the expected status. The general drift detector covers
      every combination, including those that `/base:feature` Step 6.1
      *should* have written but didn't (e.g. crashed mid-write,
      `BACKLOG.md` was missing at Step 6.1 but exists now after a
      separate `/base:backlog init` run).
    - If the spec dir exists on disk but is missing from `## Epics`
      entirely → propose appending a bullet.
    - If `## Epics` lists a spec dir that does not exist on disk → propose
      removing the bullet.
- **`BACKLOG.md` missing**: report the count of existing epic dirs and
  their statuses (from each `epic-state.json`) as a single bullet under
  "Worth your attention", paired with the Rule-1 bootstrap move. This is
  exactly the seed material `/base:backlog init` will write into the
  scaffolded `## Epics` on its first run; surfacing it explains *why*
  the bootstrap proposal is non-trivial.

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

Count entries in `## Findings`, **excluding bullets whose `<text>` begins
with the literal `[INSUFFICIENT:` or `[ALREADY-RESOLVED:` token** — those
are deferred (see the stamp grammar in
`plugins/base/skills/backlog/references/format.md`) and do not contribute
to working-set pressure. If the live count > 15 → emit a "prune or
promote" move listing the oldest 5 (also live, not stamped). Stale
findings (no date, or date > 90 days old) lead the list.

### Rule 6 — Oscillation

For each entry in `## Findings` **excluding bullets stamped
`[INSUFFICIENT:` or `[ALREADY-RESOLVED:`** (stamped bullets are deferred
work, not active concerns; comparing them to the archive double-counts
against the live oscillation signal), compare against `## Archive`:
- **Hard match**: identical anchor (path or path:line) appears in archive →
  surface verbatim, "previously rejected YYYY-MM-DD because <reason>."
- **Soft match**: anchor's path component matches AND the prose is
  semantically close (judge yourself; archive is small, reading it is
  cheap) → surface as "possible re-decision."

### Rule 7 — ADR-worthy archive cluster

Scan `## Archive`. If three or more entries share a common rationale (same
substantive reason, not just the same topic) → propose
`/base:adr <cluster-title>` as a move. Quote the cluster verbatim in the
proposal so the user can verify the pattern.

### Rule 8 — Findings ready to promote

A finding that has been on the list ≥ 30 days without resolution is a
candidate for promotion to an epic (`/base:feature backlog:<slug>`) or for a
`/base:bug` run — read its prose to decide which workflow applies, or just
let `/base:next` classify and dispatch. Findings that have been resolved in
the user's head but never closed in BACKLOG should get
`/base:backlog resolve <marker>` as the suggested next move.

**Skip bullets stamped `[INSUFFICIENT:` or `[ALREADY-RESOLVED:`** in
this rule. They are deferred until the user un-stamps or resolves them,
and their age clock applies to the *un-stamped* lifetime — surfacing
them as "ready to promote" would re-invite the same auto-abort loop
(for `[INSUFFICIENT:]`, against the same spec gap; for
`[ALREADY-RESOLVED:]`, against the same uncommitted diff).

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

- **No writes.** Not to `BACKLOG.md`, not to spec dirs, not to `CLAUDE.md`,
  not anywhere. If a move requires a write (most do), the move's `Run:`
  line is the user's explicit invocation.
- **No autonomous follow-through.** Surfacing a finding is not the same as
  acting on it. The user picks from the ranked menu.
- **No spec content reading by default.** Spec files are large; reading
  them all on every orient run would be expensive. Read the minimum each
  detection rule requires (mostly `epic-state.json` and `BACKLOG.md`
  itself).
- **No memory writes.** Orientation is per-session; persistence belongs to
  the curator.

---

## Calibration

Bias **toward surfacing the negative-space items** the user would
otherwise miss:

- An archive entry that looks like the topic of a current finding.
- An epic dir that has rotted out of `## Epics`.
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
            ├─→ project-curator (proposes mutations, lead applies)
   /bug     ┘                                  │
                                               ▼
                              BACKLOG.md / specs / docs/adr/
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
