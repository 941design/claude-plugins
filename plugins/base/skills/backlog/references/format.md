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

### Deferred-state text prefixes (`[INSUFFICIENT:]` and `[ALREADY-RESOLVED:]`)

`<text>` MAY be preceded by one of two mutually-exclusive deferred-state
prefixes, written when an auto-dispatched worker (`/base:bug` or
`/base:feature`) decides not to proceed and emits a matching abort signal
on stdout. Both prefixes mark the bullet as **deferred** in `/base:next`
Step 3's classification (skipped by the document-order walk, surfaced
only via the hint escape hatch, never counted against backlog pressure).
The two prefixes differ in *why* the worker stopped and how the user
typically unblocks the finding.

#### `[INSUFFICIENT: <gap>]` — spec is incomplete

Written when an auto-dispatched worker cannot proceed without human
input and emits `ABORT:UNDERSPECIFIED`. Full shape:

```
- <anchor> — [INSUFFICIENT: <gap>] <original text> (YYYY-MM-DD)
```

- `<gap>` is the abort reason copied from the worker's
  `ABORT:UNDERSPECIFIED:<reason>` output, truncated to ≤80 characters
  with a trailing `…` when longer. The one-line tonality rule still
  applies; truncation is non-optional.
- The stamp means **the spec lacks information** — a missing clarification,
  an unresolved decision, an arch-debate gate, an escalated decider
  verdict. The path to resolution is: fill the gap in the referenced
  anchor (spec edit, ADR, decision capture), then either un-stamp via
  `/base:next <hint>` re-dispatch (Step 3 escape hatch) or resolve via
  `/base:backlog resolve <marker> done→spec:<path>` if the gap was
  closed by an existing spec change.

#### `[ALREADY-RESOLVED: <evidence>]` — fix appears already present

Written when the worker's BACKLOG_PROMOTE working-tree probe (defined
canonically in `plugins/base/commands/bug.md` ### BACKLOG_PROMOTE mode
Step 3a; `plugins/base/commands/feature.md` refers to that section)
detects uncommitted changes touching the finding's anchored location
before doing any other work, and emits `ABORT:ALREADY-RESOLVED`. Full
shape:

```
- <anchor> — [ALREADY-RESOLVED: <evidence>] <original text> (YYYY-MM-DD)
```

- **Detection is anchor-line precise.** When the anchor carries a
  `:line` or `:N-M` line suffix, the probe parses
  `git diff HEAD -- <anchor-path>` and only aborts when at least one
  hunk's HEAD-side range overlaps the anchored line range. Hunks
  outside the range — including unrelated edits elsewhere in the same
  file — do NOT trigger an abort. When the anchor has no line suffix
  (path-only or `-` form), the probe falls back to file-level
  detection via `git status --porcelain -- <anchor-path>`. Earlier
  versions of the heuristic aborted on any uncommitted change to the
  anchored file regardless of line component; on dirty branches that
  produced frequent false deferrals (a finding anchored at
  `file.md:42` stamped because unrelated edits sat at `file.md:200`).
- `<evidence>` is composed by the worker. For the file-level
  fallback it is the first line of `git status --porcelain --
  <anchor-path>` (the porcelain status code plus the path, e.g.
  `M plugins/base/commands/next.md`). For the line-precise branch it
  describes the overlapping hunk (suggested form: `lines <H_start>-
  <H_end> in <path>: <first chars of the hunk's first context/added/
  removed line>`). In both cases it is trimmed and truncated to ≤80
  characters total in the framed form
  (`[ALREADY-RESOLVED: ` + evidence + `]`) with a trailing `…` when
  longer. The truncation rule is the same as `[INSUFFICIENT:]`'s.
- The stamp means **the working tree may already address this finding**
  — a conservative heuristic, not proof. Uncommitted hunks overlapping
  the anchored line range (or, for path-only anchors, any uncommitted
  change to the anchored file) are suggestive but the user must judge
  whether the changes actually resolve the finding. The path to
  resolution is one of:
    - Review the diff at the anchored path; if it does address the
      finding, commit the change and either close the finding via
      `/base:backlog resolve <marker> done-mechanical` (no spec
      change) or `/base:backlog resolve <marker> done→spec:<path>`
      (spec change accompanied the fix).
    - If the changes turn out unrelated to the finding, un-stamp via
      `/base:next <hint>` re-dispatch (Step 3 escape hatch); the
      probe will re-check on the next auto-dispatch and may stamp
      again if the working tree still has uncommitted touches on
      the anchored path.
- The heuristic is **gated** to BACKLOG_PROMOTE + `non_interactive =
  true`. Interactive runs do not probe (the user can see the working
  tree themselves), and modes other than BACKLOG_PROMOTE have no
  marker in scope to stamp against.

#### Shared invariants (both variants)

- **Sole signal — written by the worker, with a dispatcher fallback.**
  Each variant's stamp is the canonical and only bookkeeping artifact
  for its abort. The **worker** (`/base:bug` or `/base:feature`) writes
  it: when `non_interactive = true` AND the worker was invoked with a
  `backlog:<marker>` argument, the worker performs the stamp `Edit`
  on `BACKLOG.md` *before* emitting the matching `ABORT:UNDERSPECIFIED`
  or `ABORT:ALREADY-RESOLVED` signal on stdout. Co-locating the write
  with the actor that holds the marker and the relevant context makes
  the bookkeeping survive prompt-context locality — the worker's abort
  signal does not have to round-trip through a dispatcher's catch step
  to land on disk. `/base:next` Step 6a is a **post-return sanity
  check / fallback**: it inspects the bullet on return, and writes
  the matching stamp itself only when the worker skipped the write
  (direct invocation without a backlog marker, the worker's `Edit`
  failed, etc.). The loop-break invariant — that a re-dispatch of
  the same finding is suppressed by `/base:next` Step 3's `deferred`
  classification — holds under both paths and for both variants.
- **Retired duplicate writes.** Earlier versions of this contract had
  the auto-aborting worker also append a separate question finding
  capturing the gap; that produced duplicate writes (the stamp said
  "skip in walk" while the question said "halt the pipeline") and the
  question would later orphan when the original was resolved. The
  append was retired 2026-05-13. Existing pre-retire orphans (question
  findings whose `<text>` contains the literal substring
  `Auto-dispatch aborted:`) are folded into the same `deferred`
  bucket by `/base:next` Step 3 — they no longer block the pipeline;
  they're awaiting manual resolve.
- **Validity.** Stamped bullets (either variant) are NOT a
  malformation. `/base:orient` Rule 0 (format-integrity check) treats
  both `[INSUFFICIENT: <gap>]` and `[ALREADY-RESOLVED: <evidence>]`
  prefixes as valid grammar — this reference is the authority Rule 0
  cites. The anchor and `(YYYY-MM-DD)` trailer are unchanged from the
  un-stamped form, so substring-marker lookups (curator
  `finding_marker`, `/base:next` Step 5 derivation) continue to work.
  Operations that intentionally target a stamped bullet — resolve,
  reject, hand-edit, or `/base:next <hint>` re-dispatch — remain
  fully functional and MUST NOT be filtered out.
- **Dispatch classification.** `/base:next` Step 3 classifies bullets
  beginning with either prefix into the same `deferred` bucket: not a
  candidate in the document-order walk, not surfaced in the
  detail-mode top-3 render, and not subject to question-halt. The
  hint short-circuit's first pass also excludes them; only the
  explicit "escape hatch" second pass can reach a stamped bullet, and
  that path un-stamps before dispatching (see below).
- **Workload-signal exclusion.** Scanners that surface `## Findings`
  as workload-pressure or activity signal MUST exclude bullets stamped
  with either deferred-state prefix — they're deferred work, not
  active pressure, and counting them against the cap or oldest-N
  lists creates phantom load. The specific exclusion points (other
  scanner sites NOT listed here continue to see stamped bullets
  normally):
    - `/base:orient` Rule 5 (cap pressure count + oldest-5 listing),
      Rule 6 (oscillation vs `## Archive`), Rule 8 (ready-to-promote
      age clock).
    - `base:project-curator` `append_finding` dedup check (a stamped
      bullet must not suppress a fresh actionable finding on the same
      topic) and the Recurrence rule's matching pass (a fresh
      recurrence must not be absorbed into a stamped bullet that
      `/base:next` will never pick).
- **Manual un-stamping.** A user may un-stamp a finding by hand
  (delete the `[INSUFFICIENT: …] ` or `[ALREADY-RESOLVED: …] `
  prefix) once the gap / evidence referenced in the stamp text has
  been addressed and the original is actionable again.
  `/base:backlog resolve` does not currently provide an automated
  un-stamp op.
- **Automatic un-stamping on hint re-dispatch.** `/base:next <hint>`
  automatically un-stamps a finding when its hint uniquely targets a
  stamped bullet (the escape-hatch path), regardless of which prefix
  is in place. The bullet is rewritten in place to drop the prefix
  *before* dispatch so downstream consumers
  (`/base:feature backlog:<marker>` slug + spec stub derivation,
  `/base:bug backlog:<marker>` slug + report-text derivation) read
  the original prose and not the defer-marker. If the downstream
  skill aborts again with either `ABORT:UNDERSPECIFIED` or
  `ABORT:ALREADY-RESOLVED`, the bullet gets re-stamped with the new
  reason/evidence.

Empty placeholder when no findings exist: `- _no findings yet_`.

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
"backlog:<marker>")` as the `(feature-work, full)` cell. This is the
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
    - `Skill("base:feature", args: "backlog:foo.md auto")`
    - `Skill("base:bug", args: "backlog:bar.md auto")`
    - `Skill("base:backlog", args: "resolve baz.md done-mechanical")`
    - `Skill("base:backlog", args: "resolve qux.md done→spec:specs/epic-foo/spec.md")`
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
