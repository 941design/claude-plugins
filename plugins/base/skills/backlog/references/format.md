# `BACKLOG.md` — canonical format

This file is the single source of truth for `BACKLOG.md`'s structure, bullet
grammar, and lifecycle. Every skill, agent, or command that reads or writes
`BACKLOG.md` (`/base:orient`, `base:project-curator`, `/base:feature`,
`/base:bug`, the `base:backlog` skill itself) cites this file rather than
restating the rules.

The on-disk `BACKLOG.md` is intentionally minimal — three section headings
and bullet entries. None of the policy below appears inline in the file.

---

## The four artifacts of project meta-state

| Artifact | Captures | Lifecycle |
|---|---|---|
| `specs/epic-*/` | What we built (behavior) | Living; amended on resolved findings |
| `docs/adr/` | Why we chose this shape | Immutable once Accepted; superseded |
| `BACKLOG.md ## Findings` | What's open and undecided | Working set, soft cap ~15 |
| `BACKLOG.md ## Archive` | What we considered and rejected | Append-only, never expires |

Git history is the long-term audit trail underneath all four.

---

## Required structure

`BACKLOG.md` MUST contain exactly three top-level sections in this order:

1. `## Epics`
2. `## Findings`
3. `## Archive`

Section headers are validated by `/base:orient` Rule 0. Duplicate or missing
section headers are surfaced as malformations.

---

## `## Epics` — bullet grammar

One bullet per `specs/epic-*/` directory.

```
- specs/epic-<slug>/ — <STATUS> — <next action>
```

`<STATUS>` is one of `PLANNED`, `IN_PROGRESS`, `DONE`, `ESCALATED`. The
canonical mapping from `epic-state.json#status` is:

| `epic-state.json#status` | Bullet `<STATUS>` |
|---|---|
| `planning` | `IN_PROGRESS` |
| `in_progress` | `IN_PROGRESS` |
| `done` | `DONE` |
| `escalated` | `ESCALATED` |

`<next action>` is a short hint for a returning human or agent
("resume on story 3", "awaiting decider verdict", "ready to ship", etc.).

Empty placeholder when no epics exist: `- _no epics yet_`.

---

## `## Findings` — bullet grammar

The working set of open items that don't (yet) justify their own epic. Soft
cap **~15 entries** — beyond that, `/base:orient` Rule 5 nags to prune,
resolve, or promote.

```
- <anchor> — <text> (YYYY-MM-DD)
```

- `<anchor>` is `path[:line]` when applicable, or `-` only when no specific
  file location exists. A finding without an anchor and without a defensible
  reason for omitting one is half a thought — resolve it or delete it.
- `<text>` is one line, present-tense, specific. No trailing period required.
  The prose must be self-explanatory enough that a reader can tell whether
  this is a bug, a chore, an observation, or an open question without a tag.
  `/base:next` reads the prose to route — write it accordingly.
- `YYYY-MM-DD` is the date the finding was added.

There is no `[type]` prefix. Earlier versions of this format required one
(`bug | chore | question | observation`); writers and readers MUST treat any
residual leading `[label]` token on a bullet as part of the prose — ignored
for routing, not a malformation. The reasoning: forcing a controlled
vocabulary added friction for hand-edited todos and pushed the burden of
classification onto the writer rather than letting prose speak. Routing is
now prose-based; classification falls out of comprehension.

### `[INSUFFICIENT: <gap>]` text prefix (deferred state)

`<text>` MAY be preceded by `[INSUFFICIENT: <gap>]`, written by
`/base:next auto` when the dispatched target returned
`ABORT:UNDERSPECIFIED`. Full shape:

```
- <anchor> — [INSUFFICIENT: <gap>] <original text> (YYYY-MM-DD)
```

- `<gap>` is the abort reason copied from the target's
  `ABORT:UNDERSPECIFIED:<reason>` output, truncated to ≤80 characters
  with a trailing `…` when longer. The one-line tonality rule still
  applies; truncation is non-optional.
- The stamp marks the bullet as **deferred** until the user un-stamps it
  (manually or via `/base:next <hint>` re-dispatch) or resolves it. It
  is not a rejection — rejections live in `## Archive`.
- **Sole signal.** The stamp is the canonical and only bookkeeping
  artifact for an auto-abort. Earlier versions of this contract had the
  auto-aborting target (`/base:feature`, `/base:bug`) ALSO append a
  separate question finding capturing the gap; that produced duplicate
  writes (the stamp said "skip in walk" while the question said "halt
  the pipeline") and the question would later orphan when the original
  was resolved. The append was retired 2026-05-13. Existing pre-retire
  orphans (question findings whose `<text>` contains the literal
  substring `Auto-dispatch aborted:`) are folded into the same
  `insufficient` bucket by `/base:next` Step 3 — they no longer block
  the pipeline; they're awaiting manual resolve.
- **Validity.** Stamped bullets are NOT a malformation. `/base:orient`
  Rule 0 (format-integrity check) treats the `[INSUFFICIENT: <gap>]`
  prefix as valid grammar — this reference is the authority Rule 0
  cites. The anchor and `(YYYY-MM-DD)` trailer are unchanged from the
  un-stamped form, so substring-marker lookups (curator
  `finding_marker`, `/base:next` Step 5 derivation) continue to work.
  Operations that intentionally target a stamped bullet — resolve,
  reject, hand-edit, or `/base:next <hint>` re-dispatch — remain
  fully functional and MUST NOT be filtered out.
- **Dispatch classification.** `/base:next` Step 3 classifies stamped
  bullets as a separate `insufficient` bucket: not a candidate in the
  document-order walk, not surfaced in the detail-mode top-3 render,
  and not subject to question-halt. The hint short-circuit's first
  pass also excludes them; only the explicit "escape hatch" second
  pass can reach a stamped bullet, and that path un-stamps before
  dispatching (see below).
- **Workload-signal exclusion.** Scanners that surface `## Findings`
  as workload-pressure or activity signal MUST exclude stamped
  bullets — they're deferred work, not active pressure, and counting
  them against the cap or oldest-N lists creates phantom load. The
  specific exclusion points (other scanner sites NOT listed here
  continue to see stamped bullets normally):
    - `/base:orient` Rule 5 (cap pressure count + oldest-5 listing),
      Rule 6 (oscillation vs `## Archive`), Rule 8 (ready-to-promote
      age clock).
    - `base:project-curator` `append_finding` dedup check (a stamped
      bullet must not suppress a fresh actionable finding on the same
      topic) and the Recurrence rule's matching pass (a fresh
      recurrence must not be absorbed into a stamped bullet that
      `/base:next` will never pick).
- **Manual un-stamping.** A user may un-stamp a finding by hand
  (delete the `[INSUFFICIENT: …] ` prefix) once the gap referenced
  in the stamp text has been addressed and the original is actionable
  again. `/base:backlog resolve` does not currently provide an
  automated un-stamp op.
- **Automatic un-stamping on hint re-dispatch.** `/base:next <hint>`
  automatically un-stamps a finding when its hint uniquely targets a
  stamped bullet (the escape-hatch path). The bullet is rewritten in
  place to drop the prefix *before* dispatch so downstream consumers
  (`/base:feature backlog:<marker>` slug + spec stub derivation,
  `/base:bug backlog:<marker>` slug + report-text derivation) read
  the original prose and not the defer-marker. If the downstream
  skill aborts again with `ABORT:UNDERSPECIFIED`, the bullet gets
  re-stamped with the new gap reason.

Empty placeholder when no findings exist: `- _no findings yet_`.

---

## `## Archive` — bullet grammar

**Rejected items only.** Append-only. Never pruned.

```
- YYYY-MM-DD — <text> — <reason>
- YYYY-MM-DD — <text> — <reason> [→ ADR-NNN]
```

There is no `[rejected]` prefix — the section header conveys rejection. The
optional `[→ ADR-NNN]` tail appears after the rejection cluster has been
promoted via `base:project-curator`'s `promote_rejections_to_adr` action;
the archive entries are not deleted when promoted.

Empty placeholder when no rejections exist: `- _no rejections yet_`.

The archive is the project's durable record of paths not taken — the answer
to "did we ever consider X?" High-value oscillation signal lives here:
`/base:orient` Rule 6 surfaces live findings that match archived rejections
so the re-decision is conscious, not accidental.

---

## Resolution paths (where a finding goes when it leaves `## Findings`)

A finding MUST leave via **exactly one** of these paths:

### `done→spec:<spec-path>`

Behavior change. The named spec was amended (see its `## Amendments`
section) or a new spec was created. The spec is the durable record;
**no archive entry is written**.

### `done-mechanical`

Typo, dependency bump, formatting, or pure refactor with no
externally-observable behavior change. Just commit; **no archive entry,
no spec amendment**. Git is the record.

The **two-word test** decides eligibility: *could a future reader of any
spec notice the change is missing?* If yes, it is not mechanical —
resolve via `done→spec` instead.

### `rejected`

We considered, said no. Append an entry to `## Archive` with a verbatim
reason. **Never expires.**

### `promoted→<spec-path>`

Finding became a full epic. The new `specs/epic-*/` directory appears
under `## Epics`; **no archive entry is written**. Use
`/base:feature backlog:<finding-marker>` to promote — that flow scaffolds
the spec and removes the finding atomically.

If a finding cannot honestly be tagged with one of the four paths, it stays
in `## Findings` and ages visibly.

---

## Tonality (for skills that append)

- One line per bullet. No multi-sentence prose.
- Present tense, specific. "Login fails when email contains `+`" not
  "Sometimes login is broken."
- Anchor to a path when one applies. The reader should know where to look.
- No first-person ("I noticed", "we should"). The bullet describes the
  state of the world, not the writer's reaction to it.
- No filler ("just", "really", "actually").
- Reasons in `## Archive` cite evidence — a test, a decider verdict, a
  file. Bare opinion ("not worth it") is too thin to age well.
