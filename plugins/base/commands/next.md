---
name: next
description: Pick the next actionable finding from BACKLOG.md and dispatch it to the right workflow (/base:bug or /base:feature). Runs in detail mode by default (renders top candidates with a prose paragraph and asks for confirmation) or auto mode (/base:next auto — silently dispatches the top actionable finding without prompting).
argument-hint: "(no args = detail) | auto | <hint> [auto]"
allowed-tools: Read, Edit, Bash, AskUserQuestion, Skill, Grep
model: sonnet
---

# Backlog Dispatcher

You are a thin dispatcher. Your job is to pick the top actionable finding from `BACKLOG.md` and hand it to the right command. You do one dispatch and exit. You do not loop. You do not modify `BACKLOG.md` — that is the target command's responsibility.

## Input: $ARGUMENTS

Accepts an optional argument string. Valid forms:

- `/base:next` — no argument; runs in **detail** mode (default).
- `/base:next auto` — single token `auto`; runs in **auto** mode (silent dispatch).
- `/base:next <hint>` — free-text content hint; runs in **detail** mode and
  short-circuits selection to the bullet that best matches the hint.
- `/base:next <hint> auto` — hint plus trailing `auto`; auto-dispatches the
  hint-matched bullet without confirmation.

---

## Step 0: Parse Mode Argument

Parse `$ARGUMENTS` into `mode` and `hint` variables before any other step
executes. Both are consumed by Steps 3 and 4.

```
trimmed = $ARGUMENTS with leading/trailing whitespace removed.

IF trimmed is empty:
    mode = "detail"
    hint = None

ELSE IF trimmed == "auto" (case-sensitive, exact match — "Auto", "AUTO",
                           "--auto" do NOT qualify; a leading/trailing
                           space was already stripped above):
    mode = "auto"
    hint = None

ELSE:
    # trimmed is non-empty and is not the bare token "auto".
    # Check for a trailing auto-mode token.
    tokens = trimmed split on whitespace.
    IF tokens has length ≥ 2 AND the LAST token == "auto" (case-sensitive):
        mode = "auto"
        hint = tokens[:-1] rejoined with single spaces
    ELSE:
        mode = "detail"
        hint = trimmed

    # hint is now a non-empty string; mode is "detail" or "auto".

proceed to Step 1.
```

`mode` is exactly one of `"detail"` or `"auto"`. `hint` is either `None`
(no hint supplied; document-order walk applies) or a non-empty string
(hint-mode dispatch, see Step 3).

There is no longer a strict-exit branch on unrecognised arguments —
anything that is not empty and is not exactly `auto` is interpreted as
a content hint. Hint matching itself can still fail (Step 3 handles
zero-match and ambiguous-match cases).

---

## Step 1: Read BACKLOG.md

Read `BACKLOG.md` at the repo root. If it does not exist, exit with:

> No `BACKLOG.md` found. Run `/base:backlog init` to bootstrap project state.

---

## Step 2: Parse ## Findings

Locate the `## Findings` section. The bullet grammar (per
`plugins/base/skills/backlog/references/format.md`) is:

```
- <anchor> — <text> (YYYY-MM-DD)
```

A residual leading `[label]` token on any bullet (legacy from the
pre-prose-routing format) is part of the prose; ignore it for routing.
Do not abort on its presence.

If the section is absent, empty, or contains only the placeholder `- _no findings yet_`, exit with:

> No findings to dispatch. Run `/base:orient` for a project-wide view, or `/base:backlog add-finding` to log one.

---

## Step 3: Classify and Pick

Two paths: **hint short-circuit** (when `hint != None` from Step 0) or the
default **document-order walk**.

### Per-bullet classification

For every finding bullet, read its prose (anchor + text) and classify it
into exactly one of four buckets:

- **`deferred`** — the bullet's `<text>` (everything between ` — ` and
  ` (YYYY-MM-DD)`) matches **any** of:
    - begins with the literal token `[INSUFFICIENT:` — the canonical
      "spec is incomplete" stamp written by a prior `/base:next auto`
      dispatch whose worker returned `ABORT:UNDERSPECIFIED`. The worker
      writes the stamp before emitting the signal (it holds the marker
      and the gap reason); Step 6a falls back to writing it on the
      worker's behalf if needed.
    - begins with the literal token `[ALREADY-RESOLVED:` — the parallel
      "fix appears already present in the working tree" stamp written
      by the worker's BACKLOG_PROMOTE working-tree probe when
      `git status --porcelain -- <anchor-path>` returns non-empty
      output. The worker emits `ABORT:ALREADY-RESOLVED: <evidence>`;
      Step 6a's fallback writes the stamp when the worker skipped.
    - contains the literal substring `Auto-dispatch aborted:` anywhere in
      `<text>` — a legacy orphan from the pre-2026-05-13 contract, when
      auto-aborting targets also appended a separate question finding
      capturing the gap. That append has been retired; existing orphans
      are absorbed into this bucket so they no longer halt the pipeline.
  See `plugins/base/skills/backlog/references/format.md` for the stamp
  grammar (both variants). These are **deferred**, not blocking — the
  walk treats them as not-present. The two stamps differ only in
  semantics (gap to fill vs. fix already present) and resolution path;
  the dispatcher treats them identically.
- **`bug`** — describes a defect: something is broken, fails, errors, regresses,
  or behaves incorrectly. Verbs like "fails", "crashes", "returns wrong", "leaks",
  "silently drops" signal this.
- **`question`** — describes an undecided behavior, unresolved scope, or pending
  decision. Verbs and shapes like "should X be A or B?", "is X correct?",
  "undocumented whether…", "unclear if…", "TBD", "waiting on…", trailing `?`
  signal this. A bullet is a question when no implementation can proceed
  without a human decision first.
- **`feature-work`** — everything else: chores, observations, cleanups,
  enhancements, refactors, additions. Anything actionable that isn't a bug
  and isn't blocked on a decision.

When in doubt between `feature-work` and `bug`, prefer the classification
that lets the right workflow take over — `/base:bug` is for defects with a
reproduction; `/base:feature` handles everything else, including chores so
small they barely warrant a story.

### Per-bullet scale classification

After the `kind` classification, a **second, orthogonal axis** —
`scale ∈ {full, amendment, mechanical}` — refines the routing decision.
Each finding produces exactly one `(kind, scale)` pair. The authoritative
description of this axis (heuristics, routing matrix, inferred-path rule,
notice grammar) lives at
`plugins/base/skills/backlog/references/format.md` under the section
`/base:next Step 3 — scale axis`. The rules below are the operational
restatement the dispatcher executes.

For each bullet whose `kind ∈ {bug, feature-work}`, classify scale.
Bullets whose `kind ∈ {question, deferred}` SKIP the scale
classification entirely (they are not dispatched; scale is not
meaningful).

**Precedence: `mechanical` is evaluated first; only when it does NOT
match is `amendment` evaluated.** This means a "rename typo in
specs/epic-foo/spec.md" is `mechanical`, not `amendment` — the work
shape is mechanical even though the file is a spec.

```
For each bullet whose kind ∈ {bug, feature-work}:

  Let mechanical_keywords = {"typo", "rename", "dead code",
                             "formatting", "lint", "whitespace"}.
  Let mechanical_extensions = {".json", ".yaml", ".yml", ".toml",
                               ".lock", ".gitignore"}.
  Let behavior_verbs = {"fails", "crashes", "returns wrong",
                        "leaks", "drops", "blocks"}.
  Let amendment_keywords = {"AC ", "AC-", "spec", "amendment",
                            "amends", "AC ID", "rule", "convention"}.
  Let amendment_path_prefixes = {"specs/", "plugins/base/skills/"}.

  Keyword and substring matching is case-insensitive. Keyword matches
  use word-boundary semantics; behavior-verb matches use substring
  semantics. Extension matching is on the anchor file's extension.
  When the anchor is `-` or has no file path, both
  `mechanical_extensions` and `amendment_path_prefixes` checks treat
  their respective predicates as false (no path → no match).

  scale = "mechanical" IF
    (bullet_text contains any token from mechanical_keywords)
    OR
    (anchor file extension ∈ mechanical_extensions
       AND bullet_text contains NO substring from behavior_verbs)

  ELIF
    (bullet_text contains any token from amendment_keywords)
    AND
    (anchor path starts with any prefix in amendment_path_prefixes)
  THEN scale = "amendment"

  ELSE scale = "full"
```

The (kind, scale) tuple is carried through to Step 4 (detail-mode
rendering) and Step 6 (dispatch).

### Default path: document-order walk (when `hint == None`)

Walk findings in **document order** — do not reorder by age or any other
heuristic. **Skip every bullet classified as `deferred`** as if it were
not in the file (do not surface, do not count toward question-halt or
the top-3 list).

**Question halt** — if any finding classified as `question` appears
**before** the first non-question, non-deferred finding in document
order, surface the bullet verbatim and exit without dispatching:

> **Blocked by an open question:**
> `<full bullet text>`
>
> Resolve it before dispatching:
> - `/base:backlog resolve <marker> done-mechanical` — question answered, no spec change
> - `/base:backlog resolve <marker> done→spec:<path>` — answer is captured in a spec
> - `/base:backlog resolve <marker> rejected` — close without action

**Candidate selection** — the first finding classified as `bug` or
`feature-work` (skipping `deferred` bullets, halting on a leading
`question`) is the candidate.

### Hint path: content-overlap match (when `hint != None`)

Skip the document-order walk. Instead, narrow `## Findings` to the single
bullet whose content best matches the hint:

1. Tokenize `hint` on whitespace and punctuation, lowercase, then drop
   stopwords: `the / a / an / is / are / and / or / to / of / in / on /
   for / this / that / it / be / do`. Call the result `hint_tokens`. If
   `hint_tokens` is empty after stopword removal, fall through to step 5
   (no-match exit) — a hint composed entirely of stopwords cannot
   discriminate.

2. For each bullet in `## Findings` (**excluding** `deferred` bullets
   in this first pass; step 4 revisits them as an escape hatch):
     - Tokenize the bullet's full content (anchor + text + date) the
       same way to get `bullet_tokens`.
     - Score = count of `hint_tokens` that appear in `bullet_tokens`
       (substring match, case-insensitive).

3. Pick the bullet with the highest score. Selection is unique iff:
     - Top score ≥ 2 meaningful tokens matched, AND
     - Top score exceeds the second-best score by ≥ 1 token.

   On a unique winner, the bullet becomes the candidate. Classify it
   (per the four buckets above). If its classification is `question`,
   the question-halt above still applies — surface and exit. Otherwise
   proceed to Step 4 with this single candidate; the candidate list
   has size 1 and Step 4 still renders synthesis in detail mode.

4. **`deferred` escape hatch.** If step 3 produced no unique winner
   from non-deferred bullets, re-run step 3 *including*
   `deferred` bullets. If a unique winner now emerges and it is
   `deferred`-stamped (either `[INSUFFICIENT:` or `[ALREADY-RESOLVED:`):

     a. Surface a one-line warning naming the actual stamp matched:

        > Warning: hint matched an `[INSUFFICIENT]`-stamped finding.
        > Re-dispatching anyway because you named it explicitly; un-stamping in BACKLOG.md before dispatch.

        or

        > Warning: hint matched an `[ALREADY-RESOLVED]`-stamped finding.
        > Re-dispatching anyway because you named it explicitly; un-stamping in BACKLOG.md before dispatch.

     b. **Un-stamp the bullet on disk.** Perform a single `Edit`
        read-modify-write on `BACKLOG.md` that strips the leading
        deferred-state prefix (including the trailing space) from the
        matched bullet's `<text>`. The prefix is one of:
          - `[INSUFFICIENT: <anything>] ` (canonical "spec gap"
            stamp), or
          - `[ALREADY-RESOLVED: <anything>] ` (canonical "fix appears
            already present" stamp).
        The transform strips whichever prefix the bullet actually
        carries; both shapes are mutually exclusive at the head of
        `<text>` by construction (only one is written per abort). The
        anchor, original text, and `(YYYY-MM-DD)` trailer are
        unchanged. Example transforms:

        ```
        before: - `path/spec.md` — [INSUFFICIENT: gap reason] Original prose. (2026-05-13)
        after:  - `path/spec.md` — Original prose. (2026-05-13)

        before: - `path/spec.md` — [ALREADY-RESOLVED: M path/spec.md] Original prose. (2026-05-13)
        after:  - `path/spec.md` — Original prose. (2026-05-13)
        ```

        Rationale: the bullet text flows downstream into
        `/base:feature` and `/base:bug` (slug derivation, spec stub,
        bug-report description). Leaving either stamp in place would
        poison those derivations. Un-stamping reactivates the
        finding — the user has explicitly chosen to work on it
        again. If the downstream skill aborts again (with either
        `ABORT:UNDERSPECIFIED` or `ABORT:ALREADY-RESOLVED`), the
        worker re-stamps with the new reason/evidence before emitting
        the signal; Step 6a falls back if the worker skipped.

        If the Edit fails (file gone, marker no longer unique,
        etc.), print a single WARNING line and **do not proceed**:

        > WARNING: could not un-stamp finding in BACKLOG.md; aborting hint dispatch to avoid poisoned downstream slug/text.

        Exit without dispatching. The user can resolve manually.

     c. Classify the un-stamped bullet (per the four buckets
        above; it is now no longer `deferred`). If the
        classification is `question`, the question-halt applies —
        surface and exit. Otherwise proceed to Step 4 with this
        single candidate.

   This honors explicit user intent — a hint that points squarely at a
   stamped bullet overrides the default skip semantics, and the
   un-stamp action keeps downstream consumers (feature/bug slug and
   stub derivation) reading clean text.

5. **No unique match** (zero hits, or ambiguous even after the escape
   hatch). Print and exit without dispatching:

   ```
   No unique BACKLOG finding matches: "<hint>"

   Closest candidates:
     1. <bullet text, truncated to ~120 chars>
     2. <bullet text, truncated to ~120 chars>
     ...

   Refine the hint or run `/base:next` (no args) to see top findings.
   ```

   List up to 5 candidates ranked by score (include `deferred`
   bullets here, prefixed `[deferred]` so the user sees them).

---

## Step 4: Mode-Gated Dispatch

**Pre-branch invariant (question-halt):** The question-halt check in Step 3
already ran before this step. If execution reaches Step 4, no leading
`question` finding was present (or, in hint mode, the matched bullet is not
a `question` — a `deferred` bullet may have been accepted via the
escape hatch). The candidate is `bug` or `feature-work`. Neither `auto`
mode nor `detail` mode bypasses the question-halt; both modes rely on
Step 3's check firing before this branch. This satisfies AC-INV-1.

Branch first on **`hint`** (set by Step 0), then on `mode`:

- `hint == None` → doc-order top-3 detail rendering OR doc-order auto
  one-shot, depending on `mode`. This is the original two-branch flow.
- `hint != None` → single-candidate rendering (detail) OR silent
  single-candidate dispatch (auto). Step 3's hint path produced exactly
  one candidate.

---

### IF mode == auto AND hint == None

Select the candidate using the following rule: **the first actionable finding
in document order** from `## Findings` — the same position-1 candidate that
Step 3 identified. No re-scanning is needed; Step 3 already produced this.

**Pre-notice resolution.** Before printing the notice line, perform the
following preparatory steps so the notice template renders the correct
route and Step 6 has everything it needs:

1. Derive the unique marker per Step 5's algorithm. Needed for every
   downstream Skill invocation regardless of `(kind, scale)`.
2. If `(kind, scale) == (feature-work, amendment)`, attempt to infer the
   spec path per Step 6's inferred-spec-path rule. **If inference
   fails, reclassify `scale = full` here** — the route then falls
   through to `Skill("base:feature", ...)` as `(feature-work, full)`.
   If inference succeeds, the resolved `<inferred-path>` is embedded
   in the `done→spec:<inferred-path>` arg passed to
   `Skill("base:backlog", ...)` in Step 6.
3. Compose the Skill invocation string per the Step 6 routing matrix
   (with the auto-mode ` auto` suffix where applicable, see Step 6's
   "Mode-dependent args" subsection). The same composed string is
   used in the notice line below AND in the Skill call.

Print exactly one notice line before proceeding — no other output, no prompt:

```
Dispatching as <kind>/<scale>: <truncated-bullet> → <Skill invocation>
```

Where:
- `<kind>` is exactly `bug` or `feature-work` (the kind from Step 3).
- `<scale>` is exactly `full`, `amendment`, or `mechanical` (the scale
  from Step 3's per-bullet scale classification, after the
  inference-failure reclassification above).
- `<truncated-bullet>` is a non-empty excerpt of the selected finding's
  bullet text (truncate to approximately 60 characters, appending `…`
  if longer).
- `<Skill invocation>` is the literal Skill call composed in step 3
  above — e.g. `Skill("base:feature", args: "backlog:foo.md auto")`,
  `Skill("base:bug", args: "backlog:bar.md auto")`,
  `Skill("base:backlog", args: "resolve baz.md done-mechanical")`, or
  `Skill("base:backlog", args: "resolve qux.md done→spec:specs/epic-foo/spec.md")`.

The notice line is greppable by the literal token
`Dispatching as <kind>/<scale>:` (e.g. `grep -E "^Dispatching as
[a-z-]+/[a-z]+:"`). One line per dispatch. The `<Skill invocation>`
suffix names the actual call so audits correlate routing decisions
with what ran.

Do **not** invoke `AskUserQuestion`. Do not present any confirmation
prompt. After printing the notice line, fall through to Step 5 (marker
already derived) and Step 6 (Skill dispatch composed) for every
`(kind, scale)` cell — the four fast-track cells
(`(bug, mechanical)`, `(feature-work, mechanical)`,
`(feature-work, amendment)`) flow through Step 6 just like the
full-pipeline cells. Step 6a (auto-mode abort sanity check) then runs
only for the `(*, full)` and `(bug, amendment)` routes that invoked
`base:bug` / `base:feature`; the `base:backlog resolve` routes do not
emit the abort signals it watches for.

The Skill dispatch in Step 6 will append ` auto` to the args when `mode == auto`,
signaling non-interactive mode to the downstream skill (`/base:feature` or `/base:bug`).
If the downstream skill cannot proceed, it stamps the original finding in
`BACKLOG.md` with one of two deferred-state variants (the worker holds the
marker and the relevant context, so it writes the canonical bookkeeping
signal itself) and then returns the matching literal abort signal on stdout:

- `[INSUFFICIENT: <gap>]` paired with `ABORT:UNDERSPECIFIED: <gap>` — the
  worker cannot proceed without human input (spec gap, decider escalation,
  arch-debate required, etc.).
- `[ALREADY-RESOLVED: <evidence>]` paired with
  `ABORT:ALREADY-RESOLVED: <evidence>` — the worker's BACKLOG_PROMOTE
  working-tree probe found uncommitted changes touching the anchored
  file; the finding may already be addressed.

Step 6a below is a post-return sanity check for both variants: it confirms
the bullet was stamped and falls back to writing the stamp itself only if
the worker skipped the write (direct invocation without a marker, `Edit`
failure, etc.). Either path preserves the loop-break invariant for both
variants.

---

### IF mode == auto AND hint != None

Step 3's hint path produced a unique candidate. Perform the same
**Pre-notice resolution** as the no-hint auto branch (derive the marker
per Step 5; for `(feature-work, amendment)`, attempt inferred-path
resolution and reclassify to `(feature-work, full)` on failure; compose
the Skill invocation string per Step 6's matrix with the auto-mode suffix
where applicable).

Print exactly one notice line before proceeding — no other output, no
prompt. Same unified `Dispatching as` grammar as the no-hint auto
branch; the only difference is the parenthetical `(hint-matched)`
token, which marks the candidate as user-named rather than
document-order-selected:

```
Dispatching as <kind>/<scale> (hint-matched): <truncated-bullet> → <Skill invocation>
```

`<kind>`, `<scale>`, `<truncated-bullet>`, `<Skill invocation>`, and
`<inferred-path>` follow the same rules as the no-hint auto branch
above. After printing, fall through to Step 5 / Step 6 (Skill dispatch)
for every `(kind, scale)` cell. Do **not** invoke `AskUserQuestion`.

---

### IF mode == detail AND hint != None

Step 3's hint path produced a unique candidate. Invoke Step 4a to
synthesise a paragraph for it. Render:

```
## Hint-matched finding

**Match.** <anchor> → <kind>/<scale>
      <paragraph>
```

The `<kind>/<scale>` token is the (kind, scale) tuple from Step 3 — e.g.
`feature-work/full`, `bug/mechanical`, `feature-work/amendment`. The
user reads this tuple to understand the proposed dispatch (full
pipeline vs. resolve-style fast-track).

Then invoke `AskUserQuestion` with two options:

- `Dispatch` — proceed to Step 5 with this candidate.
- `Abort` — exit without dispatching.

On `Dispatch`: continue to Step 5. On `Abort`: exit.

When the user picks `Dispatch` for a `(feature-work, amendment)` or
`(*, mechanical)` candidate, Step 6's dispatch invokes the `base:backlog`
resolve skill interactively (the user is in the loop and can answer the
skill's `AskUserQuestion` prompts). See Step 6 for the matrix.

---

### IF mode == detail AND hint == None

Collect candidates: take the first 3 actionable findings in document order (the same
ordered list Step 3 produced — position 1, 2, 3). There may be fewer than 3.

For each candidate, invoke Step 4a to synthesise a paragraph. The anchor reads for
all candidates MAY be performed in parallel — they are independent.

Render the findings to the user:

```
## Top 3 actionable findings

**1.** <anchor#1> → <kind#1>/<scale#1>
      <paragraph#1>

**2.** <anchor#2> → <kind#2>/<scale#2>
      <paragraph#2>

**3.** <anchor#3> → <kind#3>/<scale#3>
      <paragraph#3>
```

The `<kind>/<scale>` tuple is the per-candidate (kind, scale) pair from
Step 3 (e.g. `feature-work/full`, `bug/mechanical`,
`feature-work/amendment`). The user reads the tuple alongside the
synthesis paragraph to understand what dispatch the candidate would
trigger (full pipeline vs. resolve-style fast-track).

Omit any numbered entry for which no candidate exists. A single-candidate invocation
renders only the `**1.**` block — there is no special case that skips synthesis or the
prompt for the 1-finding scenario; detail mode always renders and always confirms.

Then invoke `AskUserQuestion` with the following options (conditional inclusion rule
stated explicitly):

- `Dispatch #1` — always present when at least one actionable finding exists.
- `Dispatch #2` — present **only when a second actionable finding exists** (i.e.
  the candidate list has ≥ 2 entries). Omit entirely when only 1 candidate exists.
- `Dispatch #3` — present **only when a third actionable finding exists** (i.e.
  the candidate list has ≥ 3 entries). Omit entirely when fewer than 3 candidates exist.
- `Abort` — always present.

On selection of `Dispatch #1`, `Dispatch #2`, or `Dispatch #3`: identify the
corresponding candidate and continue to Step 5 with that candidate.

On `Abort`: exit without dispatching.

---

## Step 4a: Paragraph Synthesis

Invoked once per candidate by Step 4 in `detail` mode. Executes inline by the lead
agent — no subagent is spawned (architecture.md Boundary Rule 2, Design Decision 7).

**Inputs.** A finding bullet (anchor + text + date) and the bullet's classification
(`bug` or `feature-work`).

**1. Parse anchor.** Extract the anchor field (the first token before ` — ` in the
bullet grammar). Three forms are recognised:

- `path:line` form — anchor contains a colon followed by a line number. Split into
  `path` and `line` (integer).
- `path` form (no `:line`) — anchor is a file path with no line number component.
  `line` is absent.
- `-` form — anchor is the literal `-`. No file path. Skip steps 2–3 entirely and
  proceed directly to step 4 (bullet-only composition).

**2. Read the anchor file.** Perform a bounded Read call:

- **With line:** Read the file using `offset = max(1, line - 10)` and `limit = 21`.
  This produces a centred 21-line window around the anchor line, with the offset
  clamped to line 1 for near-top anchors.
- **Without line:** Read the first 30 lines of the file (`offset = 1`, `limit = 30`).

Any read failure — file not found, directory not found, permission denied, anchor path
containing glob characters (`*`, `?`, `[`), or ambiguous path — is treated identically:
fall back to bullet-only composition (step 4) and append the literal string
`(anchor file missing)` to the paragraph. The fallback note text is fixed and does not
vary by failure mode.

**3. (Optional) Grep for context.** If cheaply available, grep the anchor file for the
nearest preceding heading (Markdown `#` or `##`) or function declaration (e.g. `def `,
`function `, `fn `, `func `) relative to the anchor line. Use the result to name the
surrounding section in the paragraph. Skip this step if the result is not obvious or the
file type does not lend itself to heading/function extraction — the paragraph is still
valid from bullet text and the read window alone.

**4. Compose paragraph.** Write 3–5 sentences that cover all three of the following
topics:

- **(a) What** — what the issue or opportunity is (drawn from the bullet prose,
  sharpened by the anchor file context).
- **(b) Where** — where the relevant code lives: named file, section heading, or
  function name. Use the anchor path and any heading/function found in step 3.
- **(c) Goal** — what resolving this finding accomplishes for the user or the system.

The paragraph must be self-contained: a reader who has not seen the raw bullet should
still understand what dispatching this finding would do.

**5. Return.** The paragraph as a single string with no trailing whitespace.

---

## Step 5: Derive Unique Marker

The marker must uniquely identify the selected finding — when grepped case-sensitively
against `## Findings`, it must match **exactly one bullet**.

**If the finding's anchor is not `-`:** use the anchor's path component (the part before
any `:line` suffix) as the initial marker candidate.

**If the anchor is `-`:** use the first 4–6 words of the finding's text as the initial
marker candidate.

**Uniqueness check:** Grep `## Findings` for the candidate. If more than one bullet
matches, extend the candidate (add the next word or path segment) and recheck. Repeat
until exactly one match.

---

## Step 6: Dispatch via Skill

Route by the selected finding's `(kind, scale)` tuple from Step 3.
The full routing matrix:

| kind | scale=full | scale=amendment | scale=mechanical |
|---|---|---|---|
| `bug` | `Skill("base:bug", args: "backlog:<m>")` | `Skill("base:bug", args: "backlog:<m>")` | `Skill("base:backlog", args: "resolve <m> done-mechanical")` |
| `feature-work` | `Skill("base:feature", args: "backlog:<m>")` | `Skill("base:backlog", args: "resolve <m> done→spec:<inferred-path>")` | `Skill("base:backlog", args: "resolve <m> done-mechanical")` |

Per AC-NEXT-4, the `(bug, amendment)` cell routes to `/base:bug`
unchanged from today's behavior — bugs with amendment-shape framing
still warrant the bug workflow because behavior is broken; the
`amendment` scale value is recorded (and surfaced in the notice
line) but does not alter routing for the bug kind.

### Inferred spec path rule (`done→spec:<inferred-path>`)

For the `(feature-work, amendment)` cell, the dispatcher MUST attempt to
infer the spec path that should receive the AC patch. Inference rule:

1. Starting from the anchor's path component (the part before any
   `:line` suffix), walk **upward** through the directory chain.
2. If a directory matching the pattern `specs/epic-*/` is found in the
   walk, the inferred path is `specs/epic-<slug>/spec.md` for that
   epic.
3. ELSE, if the anchor is under `plugins/base/skills/<name>/`, the
   inferred path is the anchored file itself — these skill prompts
   ARE specs in the meta sense (they document agent behavior).
4. ELSE (the walk reaches the repo root with no match, OR the anchor
   is `-`, OR the anchor points at an arbitrary file with no spec
   association), inference **fails**: reclassify `scale = full` and
   route to `Skill("base:feature", args: "backlog:<marker>")` as the
   `(feature-work, full)` cell of the matrix. This fallback is the
   conservative path — the full pipeline can always handle the work.

When inference fails, the route falls through to the
`(feature-work, full)` cell and the notice line names the
`Skill("base:feature", ...)` invocation that actually runs.

### Mode-dependent args

`auto` mode appends a trailing ` auto` token to the args for
`base:bug` and `base:feature` calls (existing behavior, signals
non-interactive mode to the downstream worker):

```
[when mode == auto]
base:bug     → args: "backlog:<marker> auto"
base:feature → args: "backlog:<marker> auto"
```

For `base:backlog resolve` dispatches (the `mechanical` and
`(feature-work, amendment)` routes), the args are NOT extended with
`auto` — the `base:backlog` skill does not have an auto-mode
contract in the same sense (its op selector is structural, not
mode-keyed). The args composed by the matrix carry the action token
directly (`done-mechanical` or `done→spec:<inferred-path>`); the
resolve op parses the action token from args and skips the
top-level "which resolution path?" prompt (see
`plugins/base/skills/backlog/SKILL.md` `## Operation: resolve`,
"Argument forms" / "Parsing"). Behavior by mode:

- **`mode == auto`** — Step 6 invokes `Skill("base:backlog", args:
  "resolve <marker> done-mechanical")` or `Skill("base:backlog",
  args: "resolve <marker> done→spec:<inferred-path>")` per the
  matrix. For `done-mechanical` the resolve op completes silently
  (the dispatcher has already classified the bullet as mechanical;
  the two-word-test confirmation prompt is skipped). For
  `done→spec` the resolve op skips the path-selection prompt
  (target path is supplied via args) but still prompts for AC ID /
  AC text / amendment rationale — that is genuine user-authorship
  territory and AC-NEXT-3 requires that dispatch occur, not that
  the entire resolution complete silently.
- **`mode == detail`** — The user has explicitly picked the candidate
  via `AskUserQuestion`. Step 6 invokes the same Skill calls per
  the matrix. The user is already in the loop and can answer the
  resolve op's remaining prompts.

---

## Step 6a: Auto-Mode Abort Sanity Check (auto mode only)

This step runs only when `mode == auto` AND Step 6 dispatched to
`base:bug` or `base:feature`. Skip entirely in detail mode, and skip
for `base:backlog resolve` dispatches (the resolve op does not emit
the abort signals this step watches for — its single-write outcome
either succeeded or surfaced an error directly).

The **worker** (`/base:bug` or `/base:feature`) is the primary writer of the
deferred-state stamp — it performs the `Edit` on `BACKLOG.md` before emitting
the matching abort signal on stdout, while the marker and the relevant
context are still in scope (see each worker's Stamp-write procedure, and
`plugins/base/skills/backlog/references/format.md` "Sole signal"). Two
variants are recognised:

- `ABORT:UNDERSPECIFIED: <gap>` → stamp `[INSUFFICIENT: <gap>]` ("spec is
  incomplete; fill the gap").
- `ABORT:ALREADY-RESOLVED: <evidence>` → stamp
  `[ALREADY-RESOLVED: <evidence>]` ("fix appears already present in the
  working tree; commit and re-dispatch or close via
  `done-mechanical`").

This step is a **post-return sanity check** that confirms a stamp landed
and acts as the **fallback writer** when it did not. The loop-break
invariant (a re-dispatch of the same finding is suppressed by Step 3's
`deferred` classification) holds under both paths and for both variants.

After the Skill call in Step 6 returns in auto mode, inspect the return
output for the first line that contains either `ABORT:UNDERSPECIFIED:`
or `ABORT:ALREADY-RESOLVED:`. If neither appears, skip this step entirely
and proceed to Step 7. If a line is found:

1. **Identify the variant and extract the description.**
     - If the line contains `ABORT:UNDERSPECIFIED:`, set
       `signal = "UNDERSPECIFIED"`, `stamp_token = "INSUFFICIENT"`, and
       `description` = all text after the first `ABORT:UNDERSPECIFIED:`
       on that line, trimmed.
     - Else (line contains `ABORT:ALREADY-RESOLVED:`), set
       `signal = "ALREADY-RESOLVED"`, `stamp_token = "ALREADY-RESOLVED"`,
       and `description` = all text after the first
       `ABORT:ALREADY-RESOLVED:` on that line, trimmed.

   Use only the first matching line if multiple exist. Then truncate
   `description` to ≤80 characters; if longer, replace the trailing
   portion with a single `…` so the total stamp framing
   (`[` + stamp_token + `: ` + description + `]`) fits the
   one-line-per-bullet tonality rule
   (`plugins/base/skills/backlog/references/format.md`).

2. **Sanity check / fallback stamp.** Read `BACKLOG.md` at the repo root
   and locate the dispatched bullet using the marker derived in Step 5
   (unique by construction).

     a. **Already stamped?** If the bullet's `<text>` (everything between
        ` — ` and ` (YYYY-MM-DD)`) already begins with the literal token
        `[` + stamp_token + `:` (i.e., the variant that matches this
        signal), the worker stamped successfully — no further write is
        needed. Set `stamp_status = "worker"` and proceed to step 3.

     b. **Not stamped — fallback write.** Compute the new bullet line by
        injecting `[` + stamp_token + `: <truncated-description>] ` (with
        a trailing space) immediately after the ` — ` separator between
        `<anchor>` and `<text>`. The anchor, the original `<text>`, and
        the ` (YYYY-MM-DD)` trailer are unchanged. Example transforms:

        ```
        UNDERSPECIFIED signal → INSUFFICIENT stamp:
        before: - `path/to/spec.md` — Original prose. (2026-05-13)
        after:  - `path/to/spec.md` — [INSUFFICIENT: gap reason] Original prose. (2026-05-13)

        ALREADY-RESOLVED signal → ALREADY-RESOLVED stamp:
        before: - `path/to/spec.md` — Original prose. (2026-05-13)
        after:  - `path/to/spec.md` — [ALREADY-RESOLVED: M path/to/spec.md] Original prose. (2026-05-13)
        ```

        Apply via the `Edit` tool with the full original bullet line as
        `old_string` and the stamped bullet line as `new_string`. Edit's
        uniqueness guarantee combined with the unique marker makes this
        write safe. On success, set `stamp_status = "fallback"`.

     c. **Both writes failed.** If `BACKLOG.md` is missing, the marker is
        no longer unique (file was hand-edited between dispatch and here),
        or the fallback `Edit` itself errored, set `stamp_status = "failed"`.
        The user gets a WARNING line in step 3 instead of the standard
        "stamped" line; the loop-break invariant is unmet for this run
        and a manual `/base:backlog resolve <marker>` is the path forward.

3. **Print the abort message.** Two templates by signal variant; both
   branches respect the `stamp_status = "failed"` fallback shape at the
   bottom.

   When `signal == "UNDERSPECIFIED"` AND
   `stamp_status ∈ {"worker", "fallback"}`:

   ```
   Auto-dispatch aborted.
   Reason: {description}
   Original finding stamped [INSUFFICIENT] in BACKLOG.md (deferred).
   Address the gap (fill the referenced anchor) then re-dispatch via `/base:next <hint>` to un-stamp and retry, or close via `/base:backlog resolve <marker>`.
   ```

   When `signal == "ALREADY-RESOLVED"` AND
   `stamp_status ∈ {"worker", "fallback"}`:

   ```
   Auto-dispatch aborted.
   Evidence: {description}
   Original finding stamped [ALREADY-RESOLVED] in BACKLOG.md (deferred).
   Review the diff in the anchored path; commit and re-dispatch via `/base:next <hint>` to un-stamp and retry, or close via `/base:backlog resolve <marker> done-mechanical` if the working tree already addresses it.
   ```

   When `stamp_status == "failed"` (rare — both the worker and the
   fallback could not write), regardless of signal variant:

   ```
   Auto-dispatch aborted.
   {Reason|Evidence}: {description}
   WARNING: could not stamp original finding — manual /base:backlog resolve recommended to avoid re-dispatch.
   ```

   The label is `Reason:` when `signal == "UNDERSPECIFIED"` and
   `Evidence:` when `signal == "ALREADY-RESOLVED"`.

Then exit. Do NOT attempt the next candidate. Auto mode processes exactly
one item regardless of result (success or abort).

The next `/base:next auto` invocation will see the stamped bullet,
classify it as `deferred` in Step 3, and skip it — breaking the
re-rejection loop. This holds whether the stamp was written by the worker
(the common case) or by this step's fallback (the safety net), and for
either variant.

---

## Step 7: Return

Exit after the Skill call returns. Report the dispatched finding and which workflow
received it.

In auto mode, Step 7 is reached after either a successful dispatch or an abort —
the skill exits after one dispatch attempt in either case.
