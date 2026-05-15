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

## `## Findings` — bullet grammar (v2)

The working set of open items that don't (yet) justify their own epic. Soft
cap **~15 entries** — beyond that, `/base:orient` Rule 5 nags to prune,
resolve, or promote.

```
- <slug> [scope:<X>] — `<anchor>` — [DEFERRED:<reason>:<detail>] <text> (YYYY-MM-DD)
```

Three ` — ` separators, four positions:

- **Position 1**: `<slug>` followed by `[scope:<X>]`. Identity + scope.
- **Position 2**: `` `<anchor>` `` (backticked path with optional `:line`
  or `:N-M`), or the literal `-` for cross-cutting findings.
- **Position 3**: optional `[DEFERRED:<reason>:<detail>]` prefix, then
  `<text>`, then the trailing ` (YYYY-MM-DD)`.

### Field reference

- `<slug>` — **required**. Kebab-case identifier coined at write time. The
  canonical dispatch marker (`backlog:<slug>` in Skill args), the
  resolution marker (`/base:backlog resolve <slug>`), and the stable
  identity across stamps, retros, and project-curator decisions. See
  `### Slug derivation` below.
- `[scope:<X>]` — **required** (default `any`). Declares which project the
  finding belongs to. See `## Scope axis`.
- `` `<anchor>` `` — **required**. File path with optional `:line` or
  `:N-M` line-range; always backticked. Use the bare `-` (no backticks)
  only when no specific file location applies. A finding without an
  anchor and without a defensible reason for omitting one is half a
  thought — resolve it or delete it.
- `[DEFERRED:<reason>:<detail>]` — **optional**. Present iff the finding
  is deferred. See `### Deferred-state stamp` below.
- `<text>` — **required**. One line, present-tense, specific. No trailing
  period required. The prose must be self-explanatory enough that a
  reader can tell whether this is a bug, a chore, an observation, or an
  open question without a tag. `/base:next` reads the prose to route —
  write it accordingly.
- `(YYYY-MM-DD)` — **required**. The date the finding was added.

There is no `[type]` prefix. Earlier versions of this format required one
(`bug | chore | question | observation`); writers and readers MUST treat any
residual leading `[label]` token on a bullet as part of the prose — ignored
for routing, not a malformation.

### Slug derivation

Coined at write time:

1. Tokenise the finding's `<text>` on whitespace and punctuation; lowercase;
   drop stopwords (`the / a / an / is / are / and / or / to / of / in / on /
   for / this / that / it / be / do`).
2. Take the first **4–6 meaningful words**. Join with hyphens. Lowercase
   ASCII only; strip any non-ASCII.
3. Max length **50 characters**. Truncate at a word boundary if needed.
4. **Uniqueness**: grep `## Findings` for the candidate slug at position
   1. On collision, append `-2`. If `-2` exists, append `-3`. Etc.
5. The slug is **stable** for the finding's lifetime. Resolution events
   remove the finding from `## Findings`; the slug is not reused for a
   new finding. Mutating a slug after creation breaks every consumer that
   recorded it.

If `<text>` is too short or too generic to yield 4 meaningful words, the
writer MUST refuse to create the finding and ask for a rephrase. There is
no fallback ID scheme — the slug-as-identity invariant is load-bearing
for every downstream consumer (`/base:next` dispatch, worker stamp,
curator decisions, retro proposals).

### Deferred-state stamp (`[DEFERRED:<reason>:<detail>]`)

A finding's `<text>` MAY be preceded by exactly one
`[DEFERRED:<reason>:<detail>]` prefix when an auto-dispatched worker
(`/base:bug` or `/base:feature`) decided not to proceed and emitted a
matching `ABORT:DEFERRED:<reason>:<detail>` signal on stdout. The stamp
marks the bullet as **deferred** in `/base:next` Step 3's classification:
skipped by the document-order walk, surfaced only via the hint escape
hatch, never counted against backlog pressure.

Full shape:

```
- <slug> [scope:<X>] — `<anchor>` — [DEFERRED:<reason>:<detail>] <original text> (YYYY-MM-DD)
```

#### `<reason>` — closed enum

| Value | Semantics | Path to resolution |
|---|---|---|
| `spec-gap` | Worker cannot proceed without human spec input (missing clarification, unresolved decision). | Edit the referenced anchor (spec, ADR, decision capture). Re-dispatch via `/base:next <slug>` to un-stamp, or close via `/base:backlog resolve <slug> done→spec:<path>` if an existing spec change closed the gap. |
| `already-resolved` | The `BACKLOG_PROMOTE` working-tree probe found uncommitted hunks overlapping the anchored location. The fix may already be present. | Review `git diff -- <anchor-path>`. If it addresses the finding, commit and close via `/base:backlog resolve <slug> done-mechanical` (or `done→spec:<path>` if a spec change accompanied). If unrelated, re-dispatch via `/base:next <slug>` to un-stamp. |
| `escalated` | The Decider escalated; the run cannot proceed without human adjudication. | Resolve the escalation (typically by amending the spec or recording an ADR). Re-dispatch via `/base:next <slug>`. |
| `arch-debate-required` | The spec has `arch_debate: true`, which requires human deliberation and is not auto-dispatchable. | Run `/base:arch-debate <spec-path>` interactively. Re-dispatch via `/base:next <slug>` after the debate lands an ADR. |
| `legacy-orphan` | A pre-v2 bullet whose original abort signal is unrecoverable from the bullet text alone (migrated from the pre-2026-05-13 `Auto-dispatch aborted:` orphan shape, or from text that lacks fresh signal). | Close via `/base:backlog resolve <slug> rejected:legacy-orphan` — the original framing cannot be re-dispatched safely. |

Any other `<reason>` value is a **malformation**. `/base:orient` Rule 0
flags it.

#### `<detail>`

A short, truncated description of why the stamp landed. For `spec-gap`,
the worker's abort-reason text. For `already-resolved`, the line-precise
hunk evidence (suggested form: `lines <H_start>-<H_end> in <path>: <first
chars of the hunk's first context/added/removed line>`) or the first line
of `git status --porcelain -- <anchor-path>` for path-only anchors. For
`escalated` and `arch-debate-required`, the gate/escalation reason. For
`legacy-orphan`, the original bullet text (truncated).

Truncate the entire stamp framing (`[DEFERRED:<reason>:<detail>]`) to
≤80 characters with a trailing `…` when longer. The one-line-per-bullet
tonality rule is non-optional.

#### `already-resolved` probe (line-precise)

When the anchor carries a `:line` or `:N-M` line suffix, the worker's
BACKLOG_PROMOTE probe parses `git diff HEAD -- <anchor-path>` and only
aborts when at least one hunk's HEAD-side range overlaps the anchored
line range. Hunks outside the range — including unrelated edits
elsewhere in the same file — do NOT trigger an abort. When the anchor
has no line suffix (path-only or `-` form), the probe falls back to
file-level detection via `git status --porcelain -- <anchor-path>`.

The probe is gated to `BACKLOG_PROMOTE` mode + `non_interactive = true`.
Interactive runs do not probe (the user can see the working tree
themselves).

#### Stamp invariants

- **Sole signal — worker writes.** When `non_interactive = true` AND
  the worker was invoked with `backlog:<slug>`, the worker performs the
  stamp `Edit` on `BACKLOG.md` *before* emitting the matching
  `ABORT:DEFERRED:<reason>:<detail>` signal on stdout. Co-locating the
  write with the actor that holds the slug and the relevant context
  makes the bookkeeping survive prompt-context locality.
- **No dispatcher fallback.** `/base:next` does NOT fallback-write the
  stamp. If the worker skipped the write (no slug in scope, `Edit`
  failure, direct invocation without a `backlog:<slug>` argument), the
  dispatcher surfaces a single WARNING line and exits. The user
  resolves manually via `/base:backlog resolve`. This is a deliberate
  simplification from the v1 dual-writer model — the prior
  `stamp_status ∈ {worker, fallback, failed}` tri-state is retired.
- **Validity.** `[DEFERRED:<reason>:<detail>]`-stamped bullets are NOT
  malformations. `/base:orient` Rule 0 treats them as valid grammar.
  The slug, scope token, anchor, and `(YYYY-MM-DD)` trailer are
  unchanged from the un-stamped form, so slug-based lookups continue
  to work.
- **Dispatch classification.** `/base:next` Step 3 classifies bullets
  with the `[DEFERRED:…]` prefix into the `deferred` bucket: not a
  candidate in the document-order walk, not surfaced in detail-mode
  top-3, not subject to question-halt. The hint short-circuit's first
  pass excludes them; only the explicit "escape hatch" second pass can
  reach a stamped bullet, and that path un-stamps before dispatching.
- **Workload-signal exclusion.** Scanners that surface `## Findings`
  as workload-pressure or activity signal MUST exclude bullets stamped
  `[DEFERRED:…]` (any reason). The specific exclusion points (other
  scanner sites continue to see stamped bullets normally):
    - `/base:orient` Rule 5 (cap pressure count + oldest-5 listing),
      Rule 6 (oscillation vs `## Archive`), Rule 8 (ready-to-promote
      age clock).
    - `base:project-curator` `append_finding` dedup check (a stamped
      bullet must not suppress a fresh actionable finding on the same
      topic) and the Recurrence rule's matching pass (a fresh
      recurrence must not be absorbed into a stamped bullet that
      `/base:next` will never pick).
- **Manual un-stamping.** A user may un-stamp a finding by hand
  (delete the `[DEFERRED:…] ` prefix from position 3) once the
  gap/evidence has been addressed and the original is actionable
  again. `/base:backlog resolve` does not provide an automated
  un-stamp op.
- **Automatic un-stamping on hint re-dispatch.** `/base:next <slug>`
  automatically un-stamps a finding when the hint uniquely targets a
  stamped bullet (the escape-hatch path). The bullet is rewritten in
  place to drop the prefix *before* dispatch so downstream consumers
  (`/base:feature backlog:<slug>` and `/base:bug backlog:<slug>`)
  read the original prose and not the defer-marker. If the downstream
  skill aborts again with `ABORT:DEFERRED:<reason>:<detail>`, the
  bullet gets re-stamped with the new reason/detail.

### Empty placeholder

`- _no findings yet_` when the section is empty.

### Migration from v1 grammar

Pre-v2 bullets (no slug at position 1; anchor in position 1; old
`[INSUFFICIENT:]`/`[ALREADY-RESOLVED:]`/`Auto-dispatch aborted:` shapes)
are NOT supported by v2 readers. The migration coins slugs, moves
anchors into backticks, infers scopes, and unifies the deferred-state
prefixes into `[DEFERRED:<reason>:<detail>]`.

**Auto-migration on detection.** `/base:next` and `/base:orient` detect
v1 bullets at startup and auto-invoke `/base:backlog migrate-v2` before
proceeding — the user sees one notice line, and the migrated
`BACKLOG.md` lands as a single unstaged change for review on the next
`git diff`. Direct worker invocations (`/base:bug backlog:<slug>`,
`/base:feature backlog:<slug>` typed by hand without a dispatcher)
do NOT auto-migrate; they refuse and surface the recommended command
so the user is aware.

The migration is **idempotent** — re-running on already-v2 bullets is
a no-op. Detection key: any bullet whose position 1 (the token before
the first ` — `) starts with a backtick, the literal `-`, or contains
the legacy `[INSUFFICIENT:`/`[ALREADY-RESOLVED:` token in position 3
is v1; bullets whose position 1 is a bare kebab-case word are v2.

---

## Scope axis

Every `## Findings` bullet declares a `[scope:<X>]` token at position 1.
The token is recorded at write time and consumed by `/base:next` as a
cwd-driven filter (replacing the legacy plugin-bound classifier).

### Scope values

- `base-plugin` — work targeting `plugins/base/...`.
- `<plugin-name>` — work targeting `plugins/<name>/...` (e.g.
  `nostr-skills`, `agent-skills`, `pwa-react-skills`).
- `<consumer-project>` — set by the writer in a consumer cwd, named
  after the consumer's project root.
- `any` — cross-cutting work that applies regardless of cwd. Default
  when no other scope applies.

### Inference at write/migrate time

- Anchor starts with `plugins/base/` → `base-plugin`
- Anchor starts with `plugins/<name>/` → `<name>`
- Anchor is `-`, or path doesn't match the above → `any`

### `/base:next` cwd matching

`/base:next` resolves the **active scope** at startup:

- If the cwd's git root contains `plugins/base/commands/retros-derive.md`
  (the canary file for the claude-plugins source repo), active scope is
  `plugin-source`: bullets with `scope:base-plugin`,
  `scope:<plugin-name>`, or `scope:any` are visible.
- Otherwise, active scope is `consumer`: bullets with
  `scope:<this-consumer>` or `scope:any` are visible. The
  `<this-consumer>` value is the basename of the git root.
- Bullets whose scope does not match are silently filtered out — not
  classified, not counted, not surfaced. They remain in `BACKLOG.md`
  but are inert to `/base:next` from this cwd.

The scope filter runs FIRST in `/base:next` Step 3, before kind
classification. This consolidates today's plugin-bound classifier, cwd
detection, tally line, all-plugin-bound exit, and hint-mode plugin-bound
short-circuit into a single filter step.

### Why a scope axis

The pre-v2 design used a plugin-bound classifier with cwd detection
to distinguish work targeting plugin source from consumer work. The
anchor-prefix heuristic and per-invocation cwd detection produced edge
cases (false positives, escape hatches, dedicated audit branches).
Per-bullet scope declarations replace the heuristic with an explicit
field; the cwd check becomes a single filter step at classifier entry,
not a multi-bucket axis.

This section is the authority. Consumers MUST cite this section rather
than restating the rules.

---

## `/base:next` Step 3 — scale axis

`/base:next` Step 3 classifies every non-`deferred`, non-`question`
finding bullet on **two orthogonal axes**:

- `kind ∈ {bug, feature-work, question}` — defect vs. work vs. open
  decision. Existing axis; see `plugins/base/commands/next.md` Step 3
  "Per-bullet classification" for the prose rules.
- `scale ∈ {full, amendment, mechanical}` — work shape and weight. New
  axis added in epic-fast-track-routing. This section is the
  authoritative description; the dispatcher and any other skill or
  doc that references the scale axis cites this section rather than
  restating the rules.

Each finding produces exactly one `(kind, scale)` pair. Bullets whose
`kind ∈ {question, deferred}` skip the scale classification entirely
(they are not dispatched; scale is not meaningful for them).

### Scale values

| Value | When to assign | Routing implication |
|---|---|---|
| `full` | Default. Code work, behavior change, or anything where module-boundary design adds value. | Full `/base:feature` or `/base:bug` pipeline. |
| `amendment` | Spec / convention edit; `feature-work` only. Fully resolved by patching an AC or a documented rule. | `/base:backlog resolve <m> done→spec:<inferred-path>` for `feature-work`; `/base:bug backlog:<m>` unchanged for `bug` (behavior is broken — bug workflow still applies). |
| `mechanical` | Typo, rename, formatting, lint, dependency-bump-shaped config change. No behavior change. | `/base:backlog resolve <m> done-mechanical` for both `bug` and `feature-work`. |

### Heuristics (verbatim — authoritative)

The dispatcher evaluates `mechanical` first, then `amendment`. If
neither matches, scale is `full`. Keyword and substring matching is
case-insensitive; keyword matches use word-boundary semantics;
behavior-verb matches use substring semantics; extension matching is
on the anchor file's extension. When the anchor is `-` or has no file
path, both extension and path-prefix checks are false (no path → no
match).

#### `mechanical` predicate

```
scale = "mechanical" IF
  (bullet_text contains any of
     {"typo", "rename", "dead code", "formatting",
      "lint", "whitespace"})
  OR
  (anchor file extension ∈
     {".json", ".yaml", ".yml", ".toml", ".lock", ".gitignore"}
   AND bullet_text contains NONE of
     {"fails", "crashes", "returns wrong",
      "leaks", "drops", "blocks"})
```

The behavior-verb exclusion guards against false positives: a
`.json` schema file whose finding says "the schema *fails* to load
when X" is a real bug — the extension alone does not make it
mechanical.

#### `amendment` predicate (evaluated only when `mechanical` did not match)

```
scale = "amendment" IF
  (bullet_text contains any of
     {"AC ", "AC-", "spec", "amendment",
      "amends", "AC ID", "rule", "convention"})
  AND
  (anchor path starts with one of
     {"specs/", "plugins/base/skills/"})
```

The path-prefix gate ensures the bullet really is targeting a spec
file or a skill prompt (skill prompts are specs in the meta sense —
they document agent behavior).

#### Precedence rule

`mechanical` is evaluated FIRST; if it matches, evaluation stops and
`scale = mechanical`. Only when `mechanical` does NOT match is
`amendment` evaluated. Rationale: a "rename typo in
specs/epic-foo/spec.md" bullet matches both predicates, but the work
**shape** is mechanical, not amendment — the right disposition is
`done-mechanical`, not a spec-amendment AC patch.

### Routing matrix

| kind | scale=full | scale=amendment | scale=mechanical |
|---|---|---|---|
| `bug` | `Skill("base:bug", args: "backlog:<m>")` | `Skill("base:bug", args: "backlog:<m>")` | `Skill("base:backlog", args: "resolve <m> done-mechanical")` |
| `feature-work` | `Skill("base:feature", args: "backlog:<m>")` | `Skill("base:backlog", args: "resolve <m> done→spec:<inferred-path>")` | `Skill("base:backlog", args: "resolve <m> done-mechanical")` |

Every cell dispatches via a Skill call. In auto mode, `base:bug` and
`base:feature` args are extended with a trailing ` auto` token
(`backlog:<m> auto`) to signal non-interactive mode to the worker;
`base:backlog resolve` dispatches do not take an `auto` suffix (the
op parses its action token from args and skips the top-level
resolution-path prompt — see
`plugins/base/skills/backlog/SKILL.md` `## Operation: resolve`).

The `(bug, amendment)` cell intentionally routes to `/base:bug`
unchanged: when behavior is broken, the bug workflow's reproduction
+ minimal-fix discipline applies even if the framing references an
AC or a spec rule. The `amendment` scale value is recorded and
surfaced in the notice line but does not redirect.

### Inferred spec path rule (for `done→spec:<inferred-path>`)

For the `(feature-work, amendment)` cell, the dispatcher infers the
spec file that should receive the AC patch:

1. Starting from the anchor's path component (the part before any
   `:line` suffix), walk **upward** through the directory chain.
2. If a directory matching `specs/epic-*/` is found in the walk, the
   inferred path is `specs/epic-<slug>/spec.md` for that epic.
3. ELSE, if the anchor is under `plugins/base/skills/<name>/`, the
   inferred path is the anchored file itself (these skill prompts
   ARE specs in the meta sense).
4. ELSE (the walk reaches the repo root with no match, the anchor is
   `-`, or the anchor points at an arbitrary file with no spec
   association), inference **fails**.

**Fallback on inference failure.** Reclassify the bullet to
`scale = full` and route to `Skill("base:feature", args:
"backlog:<slug>")` as the `(feature-work, full)` cell. This is the
conservative path — the full pipeline can always handle the work
when no clean spec target exists.

### Notice line grammar

Every `/base:next` dispatch decision MUST emit exactly **one** line
to stdout, in both auto and detail mode, carrying the
`<kind>/<scale>` token AND the literal Skill invocation that ran (or,
in detail mode, that will run on confirmation). The grammar is:

```
Dispatching as <kind>/<scale>: <truncated-bullet> → <Skill invocation>
```

- `<kind>/<scale>` is the tuple from Step 3 (e.g. `bug/full`,
  `feature-work/mechanical`, `feature-work/amendment`).
- `<truncated-bullet>` is the selected finding's bullet text, trimmed
  to ~60 characters with a trailing `…` when longer.
- `<Skill invocation>` is the literal Skill call composed from the
  routing matrix, including its args. Examples:
    - `Skill("base:feature", args: "backlog:add-csv-export auto")`
    - `Skill("base:bug", args: "backlog:null-pointer-on-empty-input auto")`
    - `Skill("base:backlog", args: "resolve fix-typo-in-readme done-mechanical")`
    - `Skill("base:backlog", args: "resolve overhaul-auth-flow done→spec:specs/epic-foo/spec.md")`
- In hint-mode dispatches, the parenthetical `(hint-matched)` token
  is inserted between `<kind>/<scale>` and the colon
  (`Dispatching as <kind>/<scale> (hint-matched): …`).

The notice line is the single greppable audit token — `grep -E
"^Dispatching as [a-z-]+/[a-z]+:"` matches every dispatch decision
emitted by `/base:next`. There is no second notice verb; auto-mode
fast-track cells dispatch via Skill and emit one `Dispatching as` line
just like full-pipeline cells.

In detail mode, the same `<kind>/<scale>` tuple ALSO appears in the
per-candidate paragraph header (`**N.** <anchor> → <kind>/<scale>`)
so the user sees the proposed route before confirming via the
existing `Dispatch #N` `AskUserQuestion` prompt. When the user picks
a `(feature-work, amendment)` or `(*, mechanical)` candidate in
detail mode, the dispatcher invokes the resolve skill via Skill;
the resolve op parses the action token from args, skips its
top-level resolution-path prompt, and (for `done→spec`) still
prompts the user for AC ID / AC text / amendment rationale — that
is genuine user-authorship territory.

### Where this is consumed

- `plugins/base/commands/next.md` — Step 3 executes the heuristic;
  Step 4 emits the notice line; Step 6 dispatches per the matrix.
- `plugins/base/agents/story-planner.md` — Mode 2's `lighter_path`
  flag (epic-fast-track-routing S2) cites this section's
  markdown-class extension list and AC-completeness predicate as the
  inside-the-feature analog of the dispatcher's scale axis.
- `plugins/base/commands/feature.md` — Step 5's `lighter_path`
  branch (epic-fast-track-routing S3) cites this section for the
  shape of the work that `feature-work/amendment` represents.

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
`/base:feature backlog:<slug>` to promote — that flow scaffolds
the spec and removes the finding atomically.

If a finding cannot honestly be tagged with one of the four paths, it stays
in `## Findings` and ages visibly.

---

## Tonality (for skills that append)

- One line per bullet. No multi-sentence prose.
- Present tense, specific. "Login fails when email contains `+`" not
  "Sometimes login is broken."
- Anchor to a path when one applies. The reader should know where to look.
- Coin a slug that names the finding's *substance*, not its anchor. A
  reader who sees `bug-login-rejects-plus-in-email` immediately knows
  what the finding is about; `bug-login-md-42` is illegible and
  becomes stale when line numbers shift.
- No first-person ("I noticed", "we should"). The bullet describes the
  state of the world, not the writer's reaction to it.
- No filler ("just", "really", "actually").
- Reasons in `## Archive` cite evidence — a test, a decider verdict, a
  file. Bare opinion ("not worth it") is too thin to age well.
