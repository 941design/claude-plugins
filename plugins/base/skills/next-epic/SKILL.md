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

## Step 2: Compute per-epic status

For each enumerated dir, classify status using this precedence (matches the mapping in `plugins/base/schemas/backlog.schema.json#/$defs/epic.status` and the description of `BACKLOG.json#epics[]`):

```
For each epic at path `specs/epic-<slug>/`:

  IF spec.md is missing:
      status = "UNKNOWN"        # broken/orphan dir; surface as drift, do not dispatch
  ELSE IF epic-state.json is missing:
      status = "PLANNED"        # stub, never picked up by /base:feature
  ELSE:
      Read epic-state.json#status (a JSON string field).
      Map:
        "planning"     → "IN_PROGRESS"
        "in_progress"  → "IN_PROGRESS"
        "done"         → "DONE"
        "escalated"    → "ESCALATED"
        anything else  → "UNKNOWN"
      (file unreadable / malformed JSON / missing `status` field → "UNKNOWN")
```

Use `jq -r '.status // ""' specs/epic-<slug>/epic-state.json` to extract the field; a non-zero exit or empty result falls through to `"UNKNOWN"`.

The skill does NOT consult `BACKLOG.json#epics[]` for status — `epic-state.json` is closer to the truth (it is what `/base:feature` writes). The `epics[]` array can lag (registration drift). See Step 2.5 for drift detection.

### Step 2a: Title↔slug alignment check (PLANNED epics only)

For every epic classified `PLANNED`, also compute a **`title_aligned`** boolean. This guard prevents the dispatcher from putting `/base:feature` into a configuration that would orphan the original epic dir.

```bash
# For each PLANNED epic at specs/epic-<dir-slug>/:
dir_slug=<the slug portion of the dir name>
title=$(grep -m1 '^# ' specs/epic-<dir-slug>/spec.md | sed 's/^# //')
derived_slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

IF "$derived_slug" == "$dir_slug":
    title_aligned = true
ELSE:
    title_aligned = false
```

The derivation algorithm mirrors `commands/feature.md` Step 3 (`grep -m1 "^# " "$spec_file" | sed 's/^# //' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-'`). When `title_aligned == false`, dispatching the `.md` form into NEW mode would derive a different `epic_name` from the title, copy the spec to `specs/epic-<derived_slug>/spec.md`, and leave the original `specs/epic-<dir-slug>/` as orphan repo state. This is a latent bug in `/base:feature` Step 3's title-keyed naming — see the project-state finding raised alongside this skill.

`title_aligned` is not meaningful for IN_PROGRESS / DONE / ESCALATED / UNKNOWN epics (those don't use the title-derivation path). Skip the check for those.

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

Walk the enumerated epics in document order (lexical sort from Step 1). Skip `DONE` and `UNKNOWN` epics silently — they are not candidates. Skip `PLANNED` epics with `title_aligned == false` from the dispatchable set (but surface them in a footer per Step 4's render — they need title↔slug realignment before they can be dispatched safely). Surface `ESCALATED` epics inline in detail mode (see Step 4) but do NOT pick them as the dispatch candidate.

**Candidate selection rule:**

1. The first epic with `status == PLANNED` AND `title_aligned == true` is the candidate. Stop scanning.
2. If no aligned `PLANNED` epic exists, the first epic with `status == IN_PROGRESS` is the candidate. Stop scanning.
3. If neither exists (all epics are `DONE`, `ESCALATED`, `UNKNOWN`, or PLANNED-but-misaligned), exit with:

   ```
   No dispatchable epics — nothing to do.

   <if any PLANNED-but-misaligned exists>
   PLANNED epics with title↔slug mismatch (would orphan dirs in NEW mode; not dispatched):
     - specs/epic-<dir-slug-1>/  (title derives '<derived-slug-1>')
     - specs/epic-<dir-slug-2>/  ...
   Fix by renaming the dir to match the title (or editing the title to match the dir slug), then re-run.
   </if>

   <if any ESCALATED exists>
   Escalated epics blocked on human resolution:
     - specs/epic-<slug-1>/  (resolve via ADR or spec amendment)
     - specs/epic-<slug-2>/  ...
   </if>

   Run `/base:next` (no `epic` token) to walk findings, or author a fresh spec.
   ```

PLANNED is preferred over IN_PROGRESS because a stub that has never been started is a fresh-context dispatch (cheaper to onboard); an IN_PROGRESS epic implies a partial state and a RESUME flow. The user can override either choice with a hint.

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

   > Hint matched a broken epic dir: `specs/epic-<slug>/` (missing `spec.md` or malformed `epic-state.json`). Repair the dir first.

   If status is `PLANNED` AND `title_aligned == false`, surface and exit:

   > Hint matched a PLANNED epic with title↔slug mismatch: `specs/epic-<dir-slug>/` (title derives `<derived-slug>`). NEW mode would orphan the original dir. Fix by renaming the dir to match the title, or editing the title to match the dir slug, then re-run.

   Otherwise (`PLANNED` with `title_aligned == true`, or `IN_PROGRESS`) proceed to Step 4 with this single candidate.

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

NEW mode derives `epic_name` from the spec's `# Title` heading (`commands/feature.md` Step 3, "Create Directories and State"). When the title's kebab-case form matches the dir slug — the case for every epic scaffolded by `base:project-curator` or by this dispatcher's upstream pipeline — the `realpath` self-copy guard fires and no orphan is created. When the title and slug mismatch (hand-authored, hand-edited), NEW mode will copy to a second `specs/epic-<title-derived>/` dir and leave the original as orphan repo state. This dispatcher does NOT pre-check title↔slug alignment — the user authored the spec and owns the title; `/base:orient` Rule 2 will surface any resulting orphan.

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

Collect candidates: the first 3 **dispatchable** epics in document order, preferring PLANNED first then IN_PROGRESS — i.e. concatenate `[PLANNED epics with title_aligned == true in doc order]` + `[IN_PROGRESS epics in doc order]` and take the first 3. There may be fewer than 3. PLANNED-but-misaligned epics are NOT dispatchable; they surface in a footer.

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

If any PLANNED-but-misaligned epics exist, append a footer (informational; they are not options):

```
PLANNED with title↔slug mismatch (not dispatchable — would orphan dir):
  - specs/epic-<dir-slug>/  (title derives '<derived-slug>')
  ...
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
