---
name: next-epic
description: Pick the next un-shipped epic from `specs/epic-*/` and dispatch it to `/base:feature`. Walks the filesystem as ground truth, cross-references with `BACKLOG.json#epics[]` and each epic's `epic-state.json` to compute status, and prefers PLANNED (no `epic-state.json` yet) over IN_PROGRESS (paused). Reached as a sub-mode of `/base:next` via `/base:next epic [<hint>] [auto]`, or invoked directly as `/base:next-epic [<hint>] [auto]`. Detail mode renders top candidates with a synthesized paragraph and asks for confirmation; auto mode silently dispatches the top epic.
user-invocable: true
argument-hint: "(no args = detail) | auto | <hint> [auto]"
allowed-tools: Read, Bash, AskUserQuestion, Skill, Grep, Glob
---

# Epic Dispatcher

You are a thin dispatcher. Your job is to pick the top un-shipped epic from `specs/epic-*/` and hand it to `/base:feature`. You do one dispatch and exit. You do not loop. You do not modify `BACKLOG.json` or any `epic-state.json` — that is `/base:feature`'s responsibility once dispatched.

## Why this skill exists separate from `/base:next`

`/base:next` walks `BACKLOG.json#findings[]` (short, one-line items routed to `/base:bug` or `/base:feature`). This skill walks `specs/epic-*/` (full spec directories already authored, waiting to ship). They are different lifecycles:

- A **finding** is a backlog bullet. `/base:feature` promotes it via BACKLOG_PROMOTE mode (scaffolds an `specs/epic-<slug>/` stub) or `/base:bug` fixes it inline.
- An **epic** is a directory that already contains `spec.md` (and usually `acceptance-criteria.md`). It may have been authored manually, escalated from a finding, or paused mid-run. The next step is RESUME or NEW mode of `/base:feature`.

The filesystem is ground truth for epics. `BACKLOG.json#epics[]` is a curated registration list maintained by `/base:feature` Step 3 — many on-disk epic dirs are unregistered until `/base:feature` first runs on them. The walker must read the filesystem, not just `epics[]`, or it will miss exactly the stubs the user wants to discover.

---

## Input: $ARGUMENTS

Accepts an optional argument string. Valid forms (identical to `/base:next`'s sub-grammar; the `epic` token, if any, was already stripped by the router):

- `(empty)` — runs in **detail** mode (default).
- `auto` — single token; runs in **auto** mode (silent dispatch).
- `<hint>` — free-text content hint; runs in **detail** mode and short-circuits selection to the epic that best matches the hint.
- `<hint> auto` — hint plus trailing `auto`; auto-dispatches the hint-matched epic without confirmation.

---

## Step 0: Parse Mode Argument

```
trimmed = $ARGUMENTS with leading/trailing whitespace removed.

IF trimmed is empty:
    mode = "detail"
    hint = None

ELSE IF trimmed == "auto" (case-sensitive, exact match):
    mode = "auto"
    hint = None

ELSE:
    tokens = trimmed split on whitespace.
    IF tokens has length ≥ 2 AND the LAST token == "auto" (case-sensitive):
        mode = "auto"
        hint = tokens[:-1] rejoined with single spaces
    ELSE:
        mode = "detail"
        hint = trimmed

proceed to Step 1.
```

`mode ∈ {"detail", "auto"}`. `hint` is either `None` (document-order walk) or a non-empty string (hint short-circuit, see Step 3).

---

## Step 1: Enumerate epic directories

Ground truth is the filesystem. Run:

```bash
ls -d specs/epic-*/ 2>/dev/null | sort
```

The lexical sort defines **document order** for this skill (deterministic, matches `ls` output, and is stable across sessions). If the result is empty, exit with:

> No epic directories found under `specs/`. Run `/base:feature` on a spec to create one, or `/base:next` (no `epic` token) to walk findings instead.

For each `specs/epic-<slug>/` dir, capture:

- `path` — the directory path with trailing slash (e.g. `specs/epic-foo-bar/`).
- `slug` — the portion after `epic-` (e.g. `foo-bar`).

---

## Step 2: Compute per-epic status (evidence-based)

For each enumerated dir, classify status by **aggregating signals from the epic itself**, not by mapping a single field. The schema's `epic.status` enum (`PLANNED | IN_PROGRESS | DONE | ESCALATED | UNKNOWN`) is the output vocabulary; the inputs are everything observable about the epic dir.

This is deliberately tolerant. `epic-state.json#status` is the canonical signal when present and recognized, but a missing state file, a non-canonical value (e.g. legacy `complete`), or a hand-edited spec marked `Status: Implemented` should not collapse the epic into `UNKNOWN`. Consumers (`/base:feature`, this dispatcher) need to know what state the epic is *in*, not what literal string the writer used.

### Signal collection (per epic at `specs/epic-<slug>/`)

```
spec_present       = test -f spec.md
state_present      = test -f epic-state.json
state_status       = jq -r '.status // ""' epic-state.json   (or "" if not present / unreadable)
state_phase        = jq -r '.phase // ""'  epic-state.json   (or "" if not present / unreadable)
state_escalated    = jq -e '.escalated // .escalation // empty' epic-state.json (truthy if present)
spec_done_marker   = grep -E -q '^(#+ Implementation Summary|#+ Done|Status:[[:space:]]+Implemented)' spec.md  (true/false)
story_dirs         = ls -d S[0-9]*-*/ 2>/dev/null  (count)
story_results      = count of story dirs containing result.json
story_results_done = count of story dirs whose result.json reports a done state (jq -e '.status == "done" or .done == true' result.json)
```

`spec_done_marker` matches:
- `# Implementation Summary` / `## Implementation Summary` (any heading level), or
- `# Done` / `## Done`, or
- A leading-line `Status: Implemented` (case-sensitive on `Implemented`; spec-format conventions use that capitalization).

These are the markers actually present in shipped epics in this repo. If a project adopts a different convention, add that pattern here — but resist enumerating arbitrary synonyms (`Status: Complete`, `Status: Shipped`, …). Pick the conventions that *exist* in the project's specs and stop.

### Classification (first match wins)

```
1. NOT spec_present                                                                  → UNKNOWN
2. state_escalated OR state_status == "escalated"                                    → ESCALATED
3. state_status == "done"
   OR spec_done_marker
   OR (story_results > 0 AND story_results_done == story_results)                    → DONE
4. state_status in {"planning", "in_progress"}
   OR state_phase is non-empty
   OR story_dirs count > 0
   OR (state_present AND state_status is non-empty AND none of the above matched)    → IN_PROGRESS
5. otherwise                                                                         → PLANNED
```

Notes:

- **Rule 3 — DONE on any-of evidence.** The `complete` legacy literal is unmatched by `state_status == "done"`, but the same epic's stories or spec marker will trigger DONE. The `swipe-to-delete-list`-shaped case (no state file, but spec marked `Status: Implemented`) is caught by `spec_done_marker`. No literal `complete → done` translation table exists.
- **Rule 4 — "writer set something non-canonical" biases toward IN_PROGRESS.** A state file with an unrecognized non-empty status (and no done evidence elsewhere) means the writer was tracking *something*; treating it as PLANNED would mis-classify a paused epic as fresh. IN_PROGRESS is the safer fallback because it routes to RESUME mode (RECONCILE first), which surfaces drift to the user instead of overwriting state.
- **Rule 5 — PLANNED is the residual.** Spec exists, no state file, no work artifacts, no done markers — that is genuinely a stub.
- **No `epics[]` consultation.** This skill does NOT read `BACKLOG.json#epics[]` for status. The on-disk evidence is closer to truth; `epics[]` can lag (registration drift). See Step 2.5.

The classification is the **lead's job**, executed inline (no subagent). Keep the per-epic shell calls cheap — `jq -r` extractions on small JSON files and a single `grep -E -q` per spec are fine for tens of epics. If a project ever exceeds ~200 epic dirs, revisit this.

---

## Step 2.5: Detect registration drift (one-line notice, non-blocking)

Compare the filesystem set to `BACKLOG.json#epics[]`:

```bash
fs_set=$(ls -d specs/epic-*/ 2>/dev/null | sort)
registered=$(plugins/base/skills/backlog/scripts/list.sh --status all --format json 2>/dev/null \
  | jq -r '.epics // [] | map(.path) | .[]' 2>/dev/null | sort)
```

(If the `list.sh` invocation fails because `BACKLOG.json` is missing, treat `registered` as empty — drift detection still works against the filesystem.)

If `fs_set` contains any path not in `registered`, surface exactly one informational line before continuing:

> Note: N epic dir(s) on disk are not registered in `BACKLOG.json#epics[]` (drift). Dispatch proceeds; run `/base:orient` for the project-wide reconciliation view.

Where `N` is the count of unregistered dirs. Do not list them — keep the notice to one line. Do not block dispatch on drift.

The reverse drift (a `BACKLOG.json#epics[]` entry whose `specs/epic-<slug>/` dir is missing) is `/base:orient`'s concern, not this skill's. Skip it here.

---

## Step 3: Classify and pick

Two paths: **hint short-circuit** (when `hint != None`) or the default **document-order walk**.

### Default path: document-order walk (when `hint == None`)

Walk the enumerated epics in document order (lexical sort from Step 1). Skip `DONE` and `UNKNOWN` epics silently — they are not candidates. Surface `ESCALATED` epics inline in detail mode (see Step 4) but do NOT pick them as the dispatch candidate.

**Candidate selection rule:**

1. The first epic with `status == PLANNED` is the candidate. Stop scanning.
2. If no `PLANNED` epic exists, the first epic with `status == IN_PROGRESS` is the candidate. Stop scanning.
3. If neither exists (all epics are `DONE`, `ESCALATED`, or `UNKNOWN`), exit with:

   ```
   No dispatchable epics — nothing to do.

   <if any ESCALATED exists>
   Escalated epics blocked on human resolution:
     - specs/epic-<slug-1>/  (resolve via ADR or spec amendment)
     - specs/epic-<slug-2>/  ...
   </if>

   Run `/base:next` (no `epic` token) to walk findings, or author a fresh spec.
   ```

PLANNED is preferred over IN_PROGRESS because a stub that has never been started is a fresh-context dispatch (cheaper to onboard); an IN_PROGRESS epic implies a partial state and a RESUME flow. The user can override either choice with a hint.

**Dispatcher does not pre-validate title↔slug alignment.** `/base:feature` Step 3 pins `epic_name` from the dir path when the spec lives at `specs/epic-<dir-slug>/spec.md` (the canonical case for every epic this dispatcher could pick). Title↔slug divergence cannot orphan a dir under that contract, so this skill carries no alignment guard. If a misaligned external spec slips through some other dispatch path, `/base:orient` Rule 2 surfaces the resulting drift on the next session.

### Hint path: content-overlap match (when `hint != None`)

Skip the document-order walk. Narrow the enumerated epics to the single epic whose identity or content best matches the hint:

1. **Exact slug match first.** If the hint, after trimming whitespace, is a literal match for exactly one epic's slug (the portion after `epic-` in the dir name), that epic is the candidate — proceed to step 3.

2. **Fuzzy fallback.** Tokenize `hint` on whitespace and punctuation, lowercase, then drop stopwords: `the / a / an / is / are / and / or / to / of / in / on / for / this / that / it / be / do`. Call the result `hint_tokens`. If empty after stopword removal, fall through to step 4.

   For each epic, build `epic_tokens` from the slug AND the first heading of `spec.md` (read line 1; strip leading `# `). Score = count of `hint_tokens` that appear in `epic_tokens` (substring match, case-insensitive).

   Pick the epic with the highest score. Unique iff: top score ≥ 2 AND exceeds the second-best score by ≥ 1.

3. On a unique winner, classify status (per Step 2). If status is `DONE`, surface and exit:

   > Hint matched a DONE epic: `specs/epic-<slug>/`. It is already shipped. Refine the hint or pick a different epic.

   If status is `ESCALATED`, surface and exit:

   > Hint matched an ESCALATED epic: `specs/epic-<slug>/`. It is blocked on human resolution (typically an ADR or spec amendment). Resolve the escalation first, then re-dispatch.

   If status is `UNKNOWN`, surface and exit:

   > Hint matched a broken epic dir: `specs/epic-<slug>/` (missing `spec.md`). Repair the dir first.

   Otherwise (`PLANNED` or `IN_PROGRESS`) proceed to Step 4 with this single candidate.

4. **No unique match.** Print and exit without dispatching:

   ```
   No unique epic matches: "<hint>"

   Closest candidates:
     1. specs/epic-<slug-1>/  [<status-1>]
     2. specs/epic-<slug-2>/  [<status-2>]
     ...

   Refine the hint or run `/base:next epic` (no args) to see the top candidates.
   ```

   List up to 5 candidates by score. Annotate each with its computed status.

---

## Step 4: Mode-gated dispatch

Branch on `hint` then on `mode`.

### Dispatch-arg shape (load-bearing)

`/base:feature`'s Step 1 routing keys on the literal argument prefix (per `commands/feature.md`):

- `specs/epic-<slug>/` (directory path, trailing slash) → RESUME mode. Reads `epic-state.json` and runs RECONCILE. **Requires `epic-state.json` to exist.**
- `specs/epic-<slug>/spec.md` (`.md` file path) → NEW mode. Validates spec, plans stories, writes a fresh `epic-state.json`.

The dispatcher MUST pick the arg shape that matches the epic's status, or `/base:feature` will fail (RESUME against a stub dir crashes when reading the missing `epic-state.json`):

```
IF status == "PLANNED":      dispatch_arg = "<epic-path>spec.md"   # NEW mode
ELSE IF status == "IN_PROGRESS": dispatch_arg = "<epic-path>"      # RESUME mode
```

Where `<epic-path>` is `specs/epic-<slug>/` with trailing slash. Use this `dispatch_arg` in the notice line and the Skill call below.

NEW mode pins `epic_name` from the spec's directory path when the spec is at `specs/epic-<dir-slug>/spec.md` (`commands/feature.md` Step 3, "Create Directories and State"). The dir slug is the identity; the title is presentation. Title↔slug divergence cannot orphan a dir under that contract, so this dispatcher carries no pre-check.

### IF mode == auto AND hint == None

Select the candidate per Step 3's document-order rule (first PLANNED, fallback first IN_PROGRESS). Compute `dispatch_arg` per the shape rule above. Print exactly one notice line before proceeding — no other output, no prompt:

```
Dispatching epic <status>: <epic-path> → Skill("base:feature", args: "<dispatch_arg> auto")
```

Then invoke:

```
Skill("base:feature", args: "<dispatch_arg> auto")
```

The trailing ` auto` token tells `/base:feature` to run non-interactively (its `non_interactive = true` branch). For PLANNED epics whose `## Solution` is a template stub, `base:spec-validator` (Step 2 of `/base:feature`) will emit `ABORT:DEFERRED:spec-gap:...` and exit. That is expected; the dispatcher does not pre-validate spec readiness.

Do NOT invoke `AskUserQuestion`. Auto mode processes exactly one epic regardless of the downstream result.

### IF mode == auto AND hint != None

Same as above, but with the hint-matched candidate from Step 3 (with its `dispatch_arg` computed per the shape rule). Notice line:

```
Dispatching epic <status> (hint-matched): <epic-path> → Skill("base:feature", args: "<dispatch_arg> auto")
```

### IF mode == detail AND hint != None

Step 3's hint path produced a unique candidate. Invoke Step 4a to synthesize a paragraph. Render:

```
## Hint-matched epic

**Match.** <epic-path>  [<status>]
      <paragraph>
```

Then invoke `AskUserQuestion` with two options:

- `Dispatch` — proceed to Step 5 with this candidate.
- `Abort` — exit without dispatching.

### IF mode == detail AND hint == None

Collect candidates: the first 3 **dispatchable** epics in document order, preferring PLANNED first then IN_PROGRESS — i.e. concatenate `[PLANNED epics in doc order]` + `[IN_PROGRESS epics in doc order]` and take the first 3. There may be fewer than 3.

For each candidate, invoke Step 4a (paragraph synthesis). The reads may run in parallel.

Render:

```
## Top epics ready to ship

**1.** <epic-path-1>  [<status-1>]
      <paragraph-1>

**2.** <epic-path-2>  [<status-2>]
      <paragraph-2>

**3.** <epic-path-3>  [<status-3>]
      <paragraph-3>
```

If any `ESCALATED` epics exist, append:

```
Escalated (not dispatchable):
  - specs/epic-<slug>/  (resolve via ADR or spec amendment)
  ...
```

Then invoke `AskUserQuestion` with these options (conditional on candidate count):

- `Dispatch #1` — always present when ≥1 candidate exists.
- `Dispatch #2` — present only when ≥2 candidates exist.
- `Dispatch #3` — present only when ≥3 candidates exist.
- `Abort` — always present.

On a `Dispatch #N` selection, continue to Step 5 with the corresponding candidate. On `Abort`, exit.

---

## Step 4a: Paragraph synthesis

Invoked once per candidate by Step 4 in `detail` mode. Executes inline by the lead agent — no subagent.

**Inputs.** An epic dir path (e.g. `specs/epic-foo-bar/`) and its computed status.

**1. Read `spec.md` head.** Read the first 40 lines of `<epic-path>spec.md`. This typically covers `# Title`, `## Problem`, and the opening of `## Solution`. If `spec.md` is missing or unreadable, fall back to bullet-only composition (step 3) and append the literal string `(spec.md missing or unreadable)`.

**2. (Optional) Read `acceptance-criteria.md` head if cheap.** Read the first 20 lines if it exists; otherwise skip. Use it only to mention AC count or scope if the spec's `## Solution` was a stub.

**3. Compose 3–5 sentences covering:**

- **(a) What** — what the epic does, drawn from the `# Title` and `## Problem` section.
- **(b) Where** — the named epic dir and (when status == IN_PROGRESS) the `epic-state.json#phase` so the user knows roughly how far it got.
- **(c) Goal** — what dispatching this epic accomplishes.

For `IN_PROGRESS` epics, name the current phase from `epic-state.json#phase` (e.g. `SPEC_VALIDATED`, `STORIES_PLANNED`, `STORY_IN_PROGRESS`). Use `jq -r '.phase // ""' <epic-path>epic-state.json` to extract it.

For stub epics whose `## Solution` is still a template placeholder (an HTML comment block), say so explicitly — those will likely abort with `spec-gap` once `/base:feature` runs `base:spec-validator`. The user benefits from knowing in advance.

**4. Return.** The paragraph as a single string with no trailing whitespace.

---

## Step 5: Dispatch via Skill

Use the `dispatch_arg` computed in Step 4 (per the "Dispatch-arg shape" subsection — PLANNED → `.md` form (NEW), IN_PROGRESS → dir form (RESUME)).

Invoke:

```
Skill("base:feature", args: "<dispatch_arg>")         # detail mode
Skill("base:feature", args: "<dispatch_arg> auto")    # auto mode
```

`/base:feature`'s Step 1 routes by argument prefix:

- `.md` suffix (PLANNED dispatch) → NEW mode. Validates spec, plans stories, writes `epic-state.json`, then implements. If `## Solution` or `acceptance-criteria.md` is stubbed, `base:spec-validator` will likely emit `ABORT:DEFERRED:spec-gap:...` in auto mode and exit.
- `specs/epic-` prefix without `.md` suffix (IN_PROGRESS dispatch) → RESUME mode. Runs RECONCILE first against the workspace.

No stamping is needed here — epics are not findings, and `BACKLOG.json#findings[]` is not touched. If `/base:feature` aborts in auto mode (any `ABORT:DEFERRED:...`), the abort surfaces to the user via `/base:feature`'s normal output; the epic dir stays as-is on disk and the next `/base:next epic` invocation will re-pick it (or, in the case of an IN_PROGRESS epic whose RECONCILE adjudication needs human input, the user can resolve interactively via `/base:feature specs/epic-<slug>/`).

---

## Step 6: Return

Exit after the Skill call returns. Report the dispatched epic path and the worker's exit state (success or abort).

This skill processes exactly one epic per invocation. It does not loop.
