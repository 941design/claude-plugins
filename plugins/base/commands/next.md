---
name: next
description: Pick the next actionable finding from BACKLOG.json and dispatch it to the right workflow (/base:bug or /base:feature). Runs in detail mode by default (renders top candidates with a prose paragraph and asks for confirmation) or auto mode (/base:next auto — silently dispatches the top actionable finding without prompting).
argument-hint: "(no args = detail) | auto | <hint> [auto]"
allowed-tools: Read, Bash, AskUserQuestion, Skill, Grep
model: sonnet
---

# Backlog Dispatcher

You are a thin dispatcher. Your job is to pick the top actionable finding from `BACKLOG.json` and hand it to the right command. You do one dispatch and exit. You do not loop. You do not modify `BACKLOG.json` — that is the target command's responsibility (workers call `scripts/defer-stamp.sh` to mark deferred findings; the dispatcher only un-stamps via the escape-hatch path documented below).

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

## Step 1: Read BACKLOG.json

Read `BACKLOG.json` at the repo root by calling
`plugins/base/skills/backlog/scripts/list.sh --status all --format json`.
The script returns the findings array; the schema is at
`plugins/base/schemas/backlog.schema.json`.

If the script fails because the file does not exist, exit with:

> No `BACKLOG.json` found. Run `/base:backlog init` to bootstrap project state.

---

## Step 1.5: Auto-Migrate Legacy BACKLOG.md (if present)

If a legacy `BACKLOG.md` exists at the repo root and `BACKLOG.json` does
NOT, print exactly one line:

> Detected legacy v2 `BACKLOG.md`; invoking `/base:backlog migrate-v3` before dispatch.

Then invoke `Skill("base:backlog", args: "migrate-v3")` and re-read
`BACKLOG.json` after it returns. If the Skill call fails, surface a
WARNING and exit:

> WARNING: BACKLOG.md → BACKLOG.json migration failed; cannot dispatch until v3 grammar is in place. Run `/base:backlog migrate-v3` manually.

---

## Step 2: Parse findings[]

Findings are now read as JSON. Each finding is an object with these
fields (per `plugins/base/schemas/backlog.schema.json`):

- `slug` — kebab-case identifier (unique within `findings[]`)
- `scope` — scope token (`any`, `base-plugin`, `<plugin-name>`, …)
- `anchor` — `{path, line?, range?}` or `null`
- `text` — full finding prose, one line
- `created_at` — `YYYY-MM-DD`
- `deferred` — `{reason, detail, stamped_at}` or absent

A finding is **actionable** when `deferred` is absent (or null). A
finding is **deferred** when `deferred` is set; the deferred-state
policy is at
`plugins/base/skills/backlog/references/format.md#deferred-state`.

If `findings[]` is empty, exit with:

> No findings to dispatch. Run `/base:orient` for a project-wide view, or `/base:backlog add-finding` to log one.

---

## Step 3: Classify and Pick

Two paths: **hint short-circuit** (when `hint != None` from Step 0) or the
default **document-order walk**.

### Scope filter

Before classification, resolve the **active scope** from cwd per
`plugins/base/skills/backlog/references/format.md ## Scope axis`:

```bash
if [ -f "$(git rev-parse --show-toplevel)/plugins/base/commands/retros-derive.md" ]; then
  # plugin source repo
  active_scopes={"base-plugin", "<plugin-name>", "any"}
else
  # consumer repo
  consumer_name=$(basename "$(git rev-parse --show-toplevel)")
  active_scopes={"<consumer_name>", "any"}
fi
```

Filter `findings[]` to only entries whose `scope` field matches
`active_scopes`. Non-matching findings are silently filtered out — not
classified, not counted, not surfaced. The shell equivalent for a
plugin-source repo is:

```bash
plugins/base/skills/backlog/scripts/list.sh --status all --format json \
  | jq 'map(select(.scope == "base-plugin" or .scope == "any"))'
```

This single filter replaces the legacy plugin-bound classifier, the
cwd-detection branch, the tally line, the all-plugin-bound exit, and
the hint-mode plugin-bound short-circuit. The format authority is the
section cited above.

### Per-finding classification

For every scope-matching finding, read its prose (anchor + text) and
classify it into exactly one of four buckets. **Precedence order:
`deferred` first, then the kind buckets `bug` / `question` /
`feature-work`.**

- **`deferred`** — the finding's `.deferred` field is set (an object
  with `reason`, `detail`, and `stamped_at`). The worker (`/base:bug`
  or `/base:feature`) calls `scripts/defer-stamp.sh` before emitting
  the matching `ABORT:DEFERRED:<reason>:<detail>` signal on stdout; it
  is the sole writer (no dispatcher fallback). See
  `plugins/base/skills/backlog/references/format.md ## Deferred state`
  for the closed `<reason>` enum (`spec-gap`, `already-resolved`,
  `escalated`, `arch-debate-required`, `legacy-orphan`). Deferred
  findings are skipped by the document-order walk; the hint path's
  escape hatch (Step 3 step 4) is the only way to reach them.
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
Bullets classified as `question` or `deferred` SKIP the scale
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
the top-3 list). The scope filter (above) has already removed bullets
that do not match the active scope.

**Question halt** — if any finding classified as `question` appears
**before** the first non-question, non-deferred finding in document
order, surface the finding's prose verbatim and exit without dispatching:

> **Blocked by an open question:**
> `<full finding text>`
>
> Resolve it before dispatching:
> - `/base:backlog resolve <slug> --as done-mechanical` — question answered, no spec change
> - `/base:backlog resolve <slug> --as done --target <path>` — answer is captured in a spec
> - `/base:backlog resolve <slug> --as rejected --reason "..."` — close without action

**Candidate selection** — the first finding classified as `bug` or
`feature-work` (skipping `deferred` bullets, halting on a leading
`question`) is the candidate.

### Hint path: content-overlap match (when `hint != None`)

Skip the document-order walk. Instead, narrow scope-matching findings
to the single finding whose identity or content best matches the
hint:

1. **Exact slug match first.** Check whether the hint is a literal
   match for one of the scope-matching findings' `slug` fields (e.g.
   `scripts/get.sh "<hint>"` returns a finding). If exactly one slug
   matches the hint verbatim (after trimming whitespace), that finding
   is the candidate — skip directly to step 3's classification step.
   If zero or >1 exact slug matches, fall through to step 2 (fuzzy
   tokenizer).

2. **Fuzzy fallback.** Tokenize `hint` on whitespace and punctuation,
   lowercase, then drop stopwords: `the / a / an / is / are / and / or
   / to / of / in / on / for / this / that / it / be / do`. Call the
   result `hint_tokens`. If `hint_tokens` is empty after stopword
   removal, fall through to step 5 (no-match exit).

   For each scope-matching bullet (**excluding** `deferred` bullets
   in this first pass; step 4 revisits them as an escape hatch):
     - Tokenize the bullet's full content (slug + anchor + text + date)
       the same way to get `bullet_tokens`.
     - Score = count of `hint_tokens` that appear in `bullet_tokens`
       (substring match, case-insensitive).

   Pick the bullet with the highest score. Selection is unique iff:
     - Top score ≥ 2 meaningful tokens matched, AND
     - Top score exceeds the second-best score by ≥ 1 token.

3. On a unique winner (from step 1 exact match or step 2 fuzzy
   fallback), classify the bullet (per the four buckets above). If the
   classification is `question`, the question-halt applies — surface
   and exit. Otherwise proceed to Step 4 with this single candidate;
   the candidate list has size 1 and Step 4 still renders synthesis in
   detail mode.

4. **`deferred` escape hatch.** If step 1 and step 2 produced no unique
   winner from non-deferred findings, re-run them *including* `deferred`
   findings. If a unique winner now emerges and its `.deferred` field
   is set:

     a. Surface a one-line warning:

        > Warning: hint matched a deferred finding (reason: `<reason>`).
        > Re-dispatching anyway because you named it explicitly; un-stamping in BACKLOG.json before dispatch.

     b. **Un-stamp the finding.** Invoke
        `plugins/base/skills/backlog/scripts/defer-stamp.sh <slug> --clear`.
        This clears the `.deferred` field atomically; the slug, scope,
        anchor, text, and created_at are unchanged.

        Rationale: the text flows downstream into `/base:feature` and
        `/base:bug` (spec stub, bug-report description). The `.deferred`
        field is now structured rather than embedded in prose, so
        downstream consumers do not need to strip a marker — but
        clearing it explicitly marks the finding as actionable again so
        a subsequent `/base:next` invocation won't skip it as deferred.
        If the downstream skill aborts again, the worker re-stamps with
        the new reason/detail by calling `defer-stamp.sh` again before
        emitting `ABORT:DEFERRED:…`.

        If `defer-stamp.sh --clear` fails (slug no longer unique,
        BACKLOG.json missing, validation failure), print a single
        WARNING line and **do not proceed**:

        > WARNING: could not un-stamp finding in BACKLOG.json; aborting hint dispatch to avoid stale deferred state.

        Exit without dispatching. The user can resolve manually.

     c. Classify the un-stamped finding (per the four buckets above; it
        is now no longer `deferred`). If the classification is
        `question`, the question-halt applies — surface and exit.
        Otherwise proceed to Step 4 with this single candidate.

   This honors explicit user intent — a hint that points squarely at a
   deferred finding overrides the default skip semantics, and the
   un-stamp action keeps downstream consumers reading clean text.

5. **No unique match** (zero hits, or ambiguous even after the escape
   hatch). Print and exit without dispatching:

   ```
   No unique BACKLOG finding matches: "<hint>"

   Closest candidates:
     1. <finding text, truncated to ~120 chars>
     2. <finding text, truncated to ~120 chars>
     ...

   Refine the hint or run `/base:next` (no args) to see top findings.
   ```

   List up to 5 candidates ranked by score (include `deferred` findings
   here, prefixed `[deferred]` so the user sees them).

---

## Step 4: Mode-Gated Dispatch

**Pre-branch invariant (question-halt):** The question-halt check in Step 3
already ran before this step. If execution reaches Step 4, no leading
`question` finding was present (or, in hint mode, the matched finding is not
a `question` — a `deferred` finding may have been accepted via the
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
in document order** from scope-matching findings — the same
position-1 candidate that Step 3 identified (document order is the
order in which findings appear in the `findings[]` array). No
re-scanning is needed; Step 3 already produced this.

**Pre-notice resolution.** Before printing the notice line, perform the
following preparatory steps so the notice template renders the correct
route and Step 6 has everything it needs:

1. The unique `<slug>` was parsed in Step 2 (position 1 of the bullet).
   Step 5 (slug-as-marker) is a no-op; the slug is used directly in
   every downstream Skill invocation.
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
  above — e.g. `Skill("base:feature", args: "backlog:<slug> auto")`,
  `Skill("base:bug", args: "backlog:<slug> auto")`,
  `Skill("base:backlog", args: "resolve <slug> done-mechanical")`, or
  `Skill("base:backlog", args: "resolve <slug> done→spec:specs/epic-foo/spec.md")`.

The notice line is greppable by the literal token
`Dispatching as <kind>/<scale>:` (e.g. `grep -E "^Dispatching as
[a-z-]+/[a-z]+:"`). One line per dispatch. The `<Skill invocation>`
suffix names the actual call so audits correlate routing decisions
with what ran.

Do **not** invoke `AskUserQuestion`. Do not present any confirmation
prompt. After printing the notice line, fall through to Step 5 (slug
already parsed) and Step 6 (Skill dispatch composed) for every
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
`BACKLOG.json` by calling
`plugins/base/skills/backlog/scripts/defer-stamp.sh <slug> --reason <r> --detail <d>`
(the worker holds the slug and the relevant context, so it writes the
canonical bookkeeping signal itself — there is no dispatcher fallback)
and then returns the matching literal `ABORT:DEFERRED:<reason>:<detail>`
signal on stdout. See
`plugins/base/skills/backlog/references/format.md ## Deferred state` for
the closed `<reason>` enum and the worker-as-sole-writer invariant.

Step 6a below is a post-return sanity check: it confirms the finding
was stamped and surfaces a WARNING + exits if it was not (the
dispatcher does NOT write the stamp).

---

### IF mode == auto AND hint != None

Step 3's hint path produced a unique candidate. Perform the same
**Pre-notice resolution** as the no-hint auto branch (the slug is
already parsed; for `(feature-work, amendment)`, attempt inferred-path
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

## Step 5: Slug as Marker

The `slug` field of the selected finding IS the dispatch marker —
unique within `findings[]` by schema (enforced at write time per
`plugins/base/skills/backlog/references/format.md ## Findings - policy`,
slug subsection).

No derivation is needed. The slug read during Step 2 is used directly
as the `backlog:<slug>` argument to Skill invocations in Step 6.

---

## Step 6: Dispatch via Skill

Route by the selected finding's `(kind, scale)` tuple from Step 3.
The full routing matrix (where `<slug>` is the finding's `slug` field):

| kind | scale=full | scale=amendment | scale=mechanical |
|---|---|---|---|
| `bug` | `Skill("base:bug", args: "backlog:<slug>")` | `Skill("base:bug", args: "backlog:<slug>")` | `Skill("base:backlog", args: "resolve <slug> --as done-mechanical")` |
| `feature-work` | `Skill("base:feature", args: "backlog:<slug>")` | `Skill("base:backlog", args: "resolve <slug> --as done --target <inferred-path>")` | `Skill("base:backlog", args: "resolve <slug> --as done-mechanical")` |

Per AC-NEXT-4, the `(bug, amendment)` cell routes to `/base:bug`
unchanged from today's behavior — bugs with amendment-shape framing
still warrant the bug workflow because behavior is broken; the
`amendment` scale value is recorded (and surfaced in the notice
line) but does not alter routing for the bug kind.

### Inferred spec path rule (`--target <inferred-path>`)

For the `(feature-work, amendment)` cell, the dispatcher MUST attempt to
infer the spec path that should receive the AC patch. Inference rule:

1. Starting from `anchor.path` (the file path; if `anchor` is `null`,
   inference fails immediately), walk **upward** through the directory
   chain.
2. If a directory matching the pattern `specs/epic-*/` is found in the
   walk, the inferred path is `specs/epic-<slug>/spec.md` for that
   epic.
3. ELSE, if the anchor is under `plugins/base/skills/<name>/`, the
   inferred path is the anchored file itself — these skill prompts
   ARE specs in the meta sense (they document agent behavior).
4. ELSE (the walk reaches the repo root with no match, OR `anchor` is
   `null`, OR the anchor points at an arbitrary file with no spec
   association), inference **fails**: reclassify `scale = full` and
   route to `Skill("base:feature", args: "backlog:<slug>")` as the
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
base:bug     → args: "backlog:<slug> auto"
base:feature → args: "backlog:<slug> auto"
```

For `base:backlog resolve` dispatches (the `mechanical` and
`(feature-work, amendment)` routes), the args are NOT extended with
`auto` — the `base:backlog` skill does not have an auto-mode
contract in the same sense (its op selector is structural, not
mode-keyed). The args composed by the matrix carry the action flag
directly (`--as done-mechanical` or `--as done --target <inferred-path>`);
the resolve script enforces the action without prompts (see
`plugins/base/skills/backlog/SKILL.md` `### resolve <slug>` and
`scripts/resolve.sh --help`). Behavior by mode:

- **`mode == auto`** — Step 6 invokes `Skill("base:backlog", args:
  "resolve <slug> --as done-mechanical")` or `Skill("base:backlog",
  args: "resolve <slug> --as done --target <inferred-path>")` per the
  matrix. For `--as done-mechanical` the script completes silently
  (the dispatcher has already classified the finding as mechanical;
  no two-word-test prompt). For `--as done --target …` the script
  removes the finding from `findings[]` and surfaces a one-line
  reminder that the spec amendment is the caller's responsibility — in
  auto mode the dispatcher does not block on AC authorship; the user
  must follow up by amending the named spec.
- **`mode == detail`** — The user has explicitly picked the candidate
  via `AskUserQuestion`. Step 6 invokes the same Skill calls per
  the matrix. For `--as done --target …` in detail mode, the user
  should be reminded of the spec amendment they need to author (the
  notice line names the target path).

---

## Step 6a: Auto-Mode Abort Sanity Check (auto mode only)

This step runs only when `mode == auto` AND Step 6 dispatched to
`base:bug` or `base:feature`. Skip entirely in detail mode, and skip
for `base:backlog resolve` dispatches (the resolve script does not
emit the abort signal this step watches for).

The **worker** (`/base:bug` or `/base:feature`) is the **sole writer**
of the deferred stamp — it calls
`plugins/base/skills/backlog/scripts/defer-stamp.sh <slug> --reason <r> --detail <d>`
before emitting the matching `ABORT:DEFERRED:<reason>:<detail>` signal
on stdout, while the slug and the relevant context are still in scope
(see each worker's Stamp-write procedure, and
`plugins/base/skills/backlog/references/format.md ## Deferred state`
"Sole signal — worker writes" + "No dispatcher fallback").

This step is a **post-return sanity check**: it verifies the stamp
landed by re-reading the finding, and surfaces a WARNING + exits if it
did not. The dispatcher does NOT write the stamp itself.

After the Skill call in Step 6 returns in auto mode, inspect the return
output for the first line that contains `ABORT:DEFERRED:`. If no such
line appears, skip this step entirely and proceed to Step 7. If a line
is found:

1. **Parse the signal.** Grammar: `ABORT:DEFERRED:<reason>:<detail>`.
   Extract `<reason>` (closed enum: `spec-gap`, `already-resolved`,
   `escalated`, `arch-debate-required`, `legacy-orphan`) and `<detail>`
   (truncated gap/evidence text — everything after the second colon on
   that line, trimmed). Use only the first matching line if multiple
   exist.

2. **Verify the worker stamped.** Invoke
   `plugins/base/skills/backlog/scripts/get.sh <slug> --field deferred`
   (returns the deferred object as JSON, or empty if not deferred):

     a. **Stamped.** If the script returns a non-empty value, the
        worker stamped successfully. Proceed to step 3.

     b. **Not stamped.** Surface a single WARNING line and exit:

        ```
        WARNING: worker emitted ABORT:DEFERRED:<reason>:<detail> but did not stamp <slug> in BACKLOG.json.
        Loop-break invariant unmet for `<slug>`. Resolve manually via `/base:backlog resolve <slug> --as ...` or `defer-stamp <slug> --reason <r> --detail <d>` to prevent re-dispatch.
        ```

        Do NOT write the stamp from the dispatcher. The dispatcher is
        audit-and-exit only — the sole-writer invariant lives in the
        worker.

3. **Print the abort message.** One template, parameterised by `<reason>`:

   ```
   Auto-dispatch aborted.
   Reason: <reason> — <detail>
   Original finding stamped (deferred) in BACKLOG.json.
   <next-action>
   ```

   `<next-action>` varies slightly by `<reason>`:
   - `spec-gap` → "Address the gap (fill the referenced anchor) then re-dispatch via `/base:next <slug>` to un-stamp and retry, or close via `/base:backlog resolve <slug> --as ...`."
   - `already-resolved` → "Review the diff in the anchored path; commit and re-dispatch via `/base:next <slug>` to un-stamp and retry, or close via `/base:backlog resolve <slug> --as done-mechanical` if the working tree already addresses it."
   - `escalated` → "Resolve the escalation (typically by amending the spec or recording an ADR), then re-dispatch via `/base:next <slug>`."
   - `arch-debate-required` → "Run `/base:arch-debate <spec-path>` interactively. Re-dispatch via `/base:next <slug>` after the debate lands an ADR."
   - `legacy-orphan` → "Original framing cannot be re-dispatched safely. Close via `/base:backlog resolve <slug> --as rejected --reason 'legacy-orphan: <evidence>'`."

Then exit. Do NOT attempt the next candidate. Auto mode processes exactly
one item regardless of result (success or abort).

The next `/base:next auto` invocation will see the stamped finding,
classify it as `deferred` in Step 3, and skip it — breaking the
re-rejection loop.

---

## Step 7: Return

Exit after the Skill call returns. Report the dispatched finding and which workflow
received it.

In auto mode, Step 7 is reached after either a successful dispatch or an abort —
the skill exits after one dispatch attempt in either case.
