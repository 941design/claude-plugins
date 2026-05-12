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
