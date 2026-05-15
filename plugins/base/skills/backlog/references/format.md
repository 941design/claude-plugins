# `BACKLOG.json` — policy and lifecycle

The **shape** of `BACKLOG.json` is defined by the JSON Schema at
`plugins/base/schemas/backlog.schema.json`. Read the schema for required
fields, types, enums, and structural constraints.

This file documents the **policy** that does not fit in a JSON Schema:
resolution paths, scope axis semantics, scale axis routing, deferred-reason
meanings, tonality rules, and the relationship between BACKLOG entries
and the surrounding workflow. Every skill, agent, or command that reads
or writes BACKLOG.json (`/base:orient`, `/base:next`, `base:project-curator`,
`/base:feature`, `/base:bug`, the `base:backlog` skill itself) cites this
file rather than restating the rules.

---

## The four artifacts of project meta-state

| Artifact | Captures | Lifecycle |
|---|---|---|
| `specs/epic-*/` | What we built (behavior) | Living; amended on resolved findings |
| `docs/adr/` | Why we chose this shape | Immutable once Accepted; superseded |
| `BACKLOG.json#findings` | What's open and undecided | Working set, soft cap ~15 |
| `BACKLOG.json#archive` | What we considered and rejected | Append-only, never expires |

Git history is the long-term audit trail underneath all four.

---

## Findings — policy

The working set of open items that don't (yet) justify their own epic.
Soft cap **~15 entries** — beyond that, `/base:orient` Rule 5 nags to
prune, resolve, or promote.

### Slug

Every finding has a `slug` (kebab-case identifier) coined at write time
by `scripts/derive-slug.sh`:

1. Tokenise the finding's `text` on whitespace and punctuation; lowercase;
   drop stopwords (`the / a / an / is / are / and / or / to / of / in /
   on / for / this / that / it / be / do`).
2. Take the first **4–6 meaningful words**. Join with hyphens. Lowercase
   ASCII only; strip any non-ASCII.
3. Base slug max length **50 characters**. Truncate at a word boundary if
   needed.
4. **Uniqueness**: at write time, the script checks `findings[]` for the
   candidate slug. On collision, append `-2`. If `-2` exists, append
   `-3`. Etc. The collision suffix may extend the total slug length by
   up to 3 chars (e.g. `-99`), so the full on-disk maximum is **53
   characters** — the schema (`backlog.schema.json`) enforces this.
5. The slug is **stable** for the finding's lifetime. Resolution events
   remove the finding from `findings[]`; the slug is not reused for a
   new finding. Mutating a slug after creation breaks every consumer
   that recorded it.

If `text` is too short or too generic to yield 4 meaningful words, the
writer MUST refuse to create the finding and ask for a rephrase. There
is no fallback ID scheme — the slug-as-identity invariant is load-bearing
for every downstream consumer (`/base:next` dispatch, worker stamp,
curator decisions, retro proposals).

### Anchor

The `anchor` field points at the place in the codebase where the finding
applies. Three shapes:

- `{path: "..."}` — file-level
- `{path: "...", line: N}` — single line
- `{path: "...", range: [N, M]}` — line range
- `null` — cross-cutting findings with no specific file location

A finding without an anchor and without a defensible reason for omitting
one is half a thought — resolve it or delete it.

---

## Deferred state (`findings[i].deferred`)

A finding `MAY` carry a `deferred` object when an auto-dispatched worker
(`/base:bug` or `/base:feature`) decided not to proceed and emitted a
matching `ABORT:DEFERRED:<reason>:<detail>` signal on stdout. The
structured field marks the finding as **deferred** in `/base:next`
Step 3's classification: skipped by the document-order walk, surfaced
only via the hint escape hatch, never counted against backlog pressure.

### `reason` — closed enum

| Value | Semantics | Path to resolution |
|---|---|---|
| `spec-gap` | Worker cannot proceed without human spec input (missing clarification, unresolved decision). | Edit the referenced anchor (spec, ADR, decision capture). Re-dispatch via `/base:next <slug>` to un-stamp, or close via `/base:backlog resolve <slug> --as done --target <path>` if an existing spec change closed the gap. |
| `already-resolved` | The `BACKLOG_PROMOTE` working-tree probe found uncommitted hunks overlapping the anchored location. The fix may already be present. | Review `git diff -- <anchor-path>`. If it addresses the finding, commit and close via `/base:backlog resolve <slug> --as done-mechanical` (or `--as done --target <path>` if a spec change accompanied). If unrelated, re-dispatch via `/base:next <slug>` to un-stamp. |
| `escalated` | The Decider escalated; the run cannot proceed without human adjudication. | Resolve the escalation (typically by amending the spec or recording an ADR). Re-dispatch via `/base:next <slug>`. |
| `arch-debate-required` | The spec has `arch_debate: true`, which requires human deliberation and is not auto-dispatchable. | Run `/base:arch-debate <spec-path>` interactively. Re-dispatch via `/base:next <slug>` after the debate lands an ADR. |
| `legacy-orphan` | A pre-v3 finding whose original abort signal is unrecoverable. | Close via `/base:backlog resolve <slug> --as rejected --reason "legacy-orphan: <evidence>"` — the original framing cannot be re-dispatched safely. |

Adding a new `reason` value is a **schema change**, not a prose edit —
update `plugins/base/schemas/backlog.schema.json` and this table in the
same PR.

### `detail`

A short, truncated description of why the stamp landed. For `spec-gap`,
the worker's abort-reason text. For `already-resolved`, the line-precise
hunk evidence. For `escalated` and `arch-debate-required`, the
gate/escalation reason. For `legacy-orphan`, the original framing
(truncated).

The one-line-per-finding tonality rule applies: keep `detail` ≤80
characters with a trailing `…` when longer.

### `already-resolved` probe (line-precise)

When the anchor carries a `line` or `range`, the worker's
`BACKLOG_PROMOTE` probe parses `git diff HEAD -- <anchor.path>` and only
defers when at least one hunk's HEAD-side range overlaps the anchored
line range. Hunks outside the range — including unrelated edits
elsewhere in the same file — do NOT trigger a defer. When the anchor
has no line (path-only or `null`), the probe falls back to file-level
detection via `git status --porcelain -- <anchor.path>`.

The probe is gated to `BACKLOG_PROMOTE` mode + `non_interactive = true`.
Interactive runs do not probe (the user can see the working tree
themselves).

### Stamp invariants

- **Sole signal — worker writes.** When `non_interactive = true` AND the
  worker was invoked with `backlog:<slug>`, the worker calls
  `scripts/defer-stamp.sh <slug> --reason <r> --detail <d>` *before*
  emitting the matching `ABORT:DEFERRED:<reason>:<detail>` signal on
  stdout. Co-locating the write with the actor that holds the slug and
  the relevant context makes the bookkeeping survive prompt-context
  locality.
- **No dispatcher fallback.** `/base:next` does NOT fallback-stamp. If
  the worker skipped the stamp (no slug in scope, script failure, direct
  invocation without a `backlog:<slug>` argument), the dispatcher
  surfaces a single WARNING line and exits. The user resolves manually
  via `/base:backlog resolve` or `/base:backlog defer-stamp`.
- **Dispatch classification.** `/base:next` Step 3 classifies findings
  whose `deferred` is set into the `deferred` bucket: not a candidate in
  the document-order walk, not surfaced in detail-mode top-3, not
  subject to question-halt. The hint short-circuit's first pass excludes
  them; only the explicit "escape hatch" second pass can reach a stamped
  finding, and that path calls `defer-stamp <slug> --clear` before
  dispatching.
- **Workload-signal exclusion.** Scanners that surface findings as
  workload-pressure or activity signal MUST exclude stamped findings (any
  reason). The specific exclusion points (other scanner sites continue
  to see stamped findings normally):
    - `/base:orient` Rule 5 (cap pressure count + oldest-5 listing),
      Rule 6 (oscillation vs `archive[]`), Rule 8 (ready-to-promote
      age clock).
    - `base:project-curator`'s `append_finding` dedup check (a stamped
      finding must not suppress a fresh actionable finding on the same
      topic) and the Recurrence rule's matching pass.
- **Manual un-stamping.** A user may un-stamp a finding via
  `/base:backlog defer-stamp <slug> --clear` once the gap/evidence has
  been addressed and the original is actionable again.
- **Automatic un-stamping on hint re-dispatch.** `/base:next <slug>`
  automatically calls `defer-stamp --clear` when the hint uniquely
  targets a stamped finding (the escape-hatch path). The stamp is
  cleared *before* dispatch so downstream consumers
  (`/base:feature backlog:<slug>` and `/base:bug backlog:<slug>`)
  read the original prose unencumbered. If the downstream skill aborts
  again with `ABORT:DEFERRED:<reason>:<detail>`, the finding gets
  re-stamped with the new reason/detail.

---

## Scope axis

Every finding declares a `scope` token. The token is recorded at write
time and consumed by `/base:next` as a cwd-driven filter.

### Scope values

- `base-plugin` — work targeting `plugins/base/...`.
- `<plugin-name>` — work targeting `plugins/<name>/...` (e.g.
  `nostr-skills`, `agent-skills`, `pwa-react-skills`).
- `<consumer-project>` — set by the writer in a consumer cwd, named
  after the consumer's project root.
- `any` — cross-cutting work that applies regardless of cwd. Default
  when no other scope applies.

### Inference at write time

`scripts/add-finding.sh` infers scope from the anchor when `--scope` is
omitted:

- `anchor.path` starts with `plugins/base/` → `base-plugin`
- `anchor.path` starts with `plugins/<name>/` → `<name>`
- `anchor` is `null`, or path doesn't match the above → `any`

### `/base:next` cwd matching

`/base:next` resolves the **active scope** at startup:

- If the cwd's git root contains `plugins/base/commands/retros-derive.md`
  (the canary file for the claude-plugins source repo), active scope is
  `plugin-source`: findings with `scope:base-plugin`,
  `scope:<plugin-name>`, or `scope:any` are visible.
- Otherwise, active scope is `consumer`: findings with
  `scope:<this-consumer>` or `scope:any` are visible. The
  `<this-consumer>` value is the basename of the git root.
- Findings whose scope does not match are silently filtered out — not
  classified, not counted, not surfaced. They remain in BACKLOG.json
  but are inert to `/base:next` from this cwd.

The scope filter runs FIRST in `/base:next` Step 3, before kind
classification.

---

## `/base:next` Step 3 — scale axis

`/base:next` Step 3 classifies every non-`deferred`, non-`question`
finding on **two orthogonal axes**:

- `kind ∈ {bug, feature-work, question}` — defect vs. work vs. open
  decision. See `plugins/base/commands/next.md` Step 3 for the prose
  rules.
- `scale ∈ {full, amendment, mechanical}` — work shape and weight.

Each finding produces exactly one `(kind, scale)` pair. Findings whose
`kind ∈ {question, deferred}` skip the scale classification entirely.

### Scale values

| Value | When to assign | Routing implication |
|---|---|---|
| `full` | Default. Code work, behavior change, or anything where module-boundary design adds value. | Full `/base:feature` or `/base:bug` pipeline. |
| `amendment` | Spec / convention edit; `feature-work` only. Fully resolved by patching an AC or a documented rule. | `/base:backlog resolve <m> --as done --target <inferred-path>` for `feature-work`; `/base:bug backlog:<m>` unchanged for `bug` (behavior is broken — bug workflow still applies). |
| `mechanical` | Typo, rename, formatting, lint, dependency-bump-shaped config change. No behavior change. | `/base:backlog resolve <m> --as done-mechanical` for both `bug` and `feature-work`. |

### Heuristics (authoritative)

The dispatcher evaluates `mechanical` first, then `amendment`. If
neither matches, scale is `full`. Keyword and substring matching is
case-insensitive; keyword matches use word-boundary semantics;
behavior-verb matches use substring semantics; extension matching is
on the anchor file's extension. When `anchor == null` or has no file
path, both extension and path-prefix checks are false (no path → no
match).

#### `mechanical` predicate

```
scale = "mechanical" IF
  (text contains any of
     {"typo", "rename", "dead code", "formatting",
      "lint", "whitespace"})
  OR
  (anchor.path extension ∈
     {".json", ".yaml", ".yml", ".toml", ".lock", ".gitignore"}
   AND text contains NONE of
     {"fails", "crashes", "returns wrong",
      "leaks", "drops", "blocks"})
```

The behavior-verb exclusion guards against false positives: a `.json`
schema file whose finding says "the schema *fails* to load when X" is
a real bug — the extension alone does not make it mechanical.

#### `amendment` predicate (evaluated only when `mechanical` did not match)

```
scale = "amendment" IF
  (text contains any of
     {"AC ", "AC-", "spec", "amendment",
      "amends", "AC ID", "rule", "convention"})
  AND
  (anchor.path starts with one of
     {"specs/", "plugins/base/skills/"})
```

#### Precedence rule

`mechanical` is evaluated FIRST; if it matches, evaluation stops and
`scale = mechanical`. Only when `mechanical` does NOT match is
`amendment` evaluated. Rationale: a "rename typo in
specs/epic-foo/spec.md" finding matches both predicates, but the work
**shape** is mechanical, not amendment.

### Routing matrix

| kind | scale=full | scale=amendment | scale=mechanical |
|---|---|---|---|
| `bug` | `Skill("base:bug", args: "backlog:<m>")` | `Skill("base:bug", args: "backlog:<m>")` | `Skill("base:backlog", args: "resolve <m> --as done-mechanical")` |
| `feature-work` | `Skill("base:feature", args: "backlog:<m>")` | `Skill("base:backlog", args: "resolve <m> --as done --target <inferred-path>")` | `Skill("base:backlog", args: "resolve <m> --as done-mechanical")` |

In auto mode, `base:bug` and `base:feature` args are extended with a
trailing ` auto` token (`backlog:<m> auto`) to signal non-interactive
mode to the worker.

### Inferred spec path rule (for `--target <inferred-path>`)

For the `(feature-work, amendment)` cell, the dispatcher infers the
spec file that should receive the AC patch:

1. Starting from `anchor.path`, walk **upward** through the directory
   chain.
2. If a directory matching `specs/epic-*/` is found in the walk, the
   inferred path is `specs/epic-<slug>/spec.md` for that epic.
3. ELSE, if the anchor is under `plugins/base/skills/<name>/`, the
   inferred path is the anchored file itself.
4. ELSE the walk reaches the repo root with no match — inference
   **fails**.

**Fallback on inference failure.** Reclassify the finding to
`scale = full` and route to
`Skill("base:feature", args: "backlog:<slug>")`. The full pipeline can
always handle the work when no clean spec target exists.

### Notice line grammar

Every `/base:next` dispatch emits exactly **one** line to stdout, in
both auto and detail mode:

```
Dispatching as <kind>/<scale>: <truncated-text> → <Skill invocation>
```

The notice line is the single greppable audit token. `grep -E "^Dispatching as [a-z-]+/[a-z]+:"` matches every dispatch decision.

---

## Archive — policy

**Rejected findings only.** `archive[]` is append-only and never pruned.
Entries are written by `scripts/resolve.sh --as rejected`, which removes
the finding from `findings[]` and appends an entry to `archive[]`
atomically.

When a rejection cluster is promoted to an ADR via
`base:project-curator`'s `promote_rejections_to_adr` action, each
matched entry gets an `adr` field (`"ADR-007"`) — the archive entries
are not deleted when promoted.

The archive is the project's durable record of paths not taken — the
answer to "did we ever consider X?" High-value oscillation signal lives
here: `/base:orient` Rule 6 surfaces live findings that match archived
rejections so the re-decision is conscious, not accidental.

---

## Resolution paths

A finding MUST leave `findings[]` via **exactly one** of these paths:

### `done` (`resolve --as done --target <spec-path>`)

Behavior change. The named spec was amended (see its `## Amendments`
section) or a new spec was created. The spec is the durable record;
**no archive entry is written**. The script removes the finding; the
caller is responsible for the spec edit.

### `done-mechanical` (`resolve --as done-mechanical`)

Typo, dependency bump, formatting, or pure refactor with no
externally-observable behavior change. Just commit; **no archive entry,
no spec amendment**. Git is the record.

The **two-word test** decides eligibility: *could a future reader of any
spec notice the change is missing?* If yes, it is not mechanical —
resolve via `done` instead.

### `rejected` (`resolve --as rejected --reason "..."`)

We considered, said no. The script removes the finding and appends an
entry to `archive[]` with the verbatim text and reason. **Never expires.**

### `promoted` (`resolve --as promoted --target <spec-path>`)

Finding became a full epic. The script removes the finding; the caller
(typically `/base:feature backlog:<slug>`) is responsible for creating
the `specs/epic-*/` directory and registering it via
`scripts/add-epic.sh`. **No archive entry is written.**

If a finding cannot honestly be tagged with one of the four paths, it
stays in `findings[]` and ages visibly.

---

## Tonality (for skills that append findings)

- One line per finding's `text`. No multi-sentence prose unless every
  sentence genuinely earns its keep.
- Present tense, specific. "Login fails when email contains `+`" not
  "Sometimes login is broken."
- Anchor to a path when one applies. The reader should know where to look.
- Coin a slug that names the finding's *substance*, not its anchor. A
  reader who sees `bug-login-rejects-plus-in-email` immediately knows
  what the finding is about; `bug-login-md-42` is illegible and becomes
  stale when line numbers shift.
- No first-person ("I noticed", "we should"). The text describes the
  state of the world, not the writer's reaction to it.
- No filler ("just", "really", "actually").
- Reasons in `archive[]` cite evidence — a test, a decider verdict, a
  file. Bare opinion ("not worth it") is too thin to age well.
