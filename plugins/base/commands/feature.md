---
name: feature
description: Implement features from specs or natural language using an agent team. ALWAYS use this for ALL feature work, including small tasks.
argument-hint: <@spec-file> OR <feature-description> OR <epic-directory>
allowed-tools: Task, Read, Write, Edit, Bash, AskUserQuestion, Skill
model: sonnet
---

# Feature Implementation — Agent Team Blueprint

You are the **team lead**. Your job is to create and coordinate an agent team that implements a feature from specification through verified, tested code.

## Conventions for spawning vs. messaging

Three distinct mechanisms exist; do not confuse them. **Agent creates a new instance; SendMessage either finds an existing teammate by role name OR continues a previously-spawned subagent by its agentId.**

- **Spawning a fresh subagent** → use the **Agent tool** with an explicit `subagent_type` (e.g. `subagent_type: base:integration-architect`). This is the only way to launch agents named `base:*` such as `base:integration-architect`, `base:code-explorer`, `base:spec-validator`, `base:story-planner`, `base:pbt-dev`, `base:verification-examiner`, `base:retro-synthesizer`. Always namespace-qualify with `base:`.
- **Messaging an existing TeamCreate teammate (by role name)** → use **SendMessage** with the teammate's role name (e.g. `architect`, `verifier`, `planner`, `Decider`). SendMessage to a name that does not match a current teammate **routes successfully but silently no-ops** — work will stall with no error. There is no hook or runtime check that catches this; prevention is by getting the call right. Never use SendMessage to "spawn" a `base:*` subagent.
- **Continuing a previously-spawned subagent (by agentId)** → use **SendMessage** with the `agentId` returned from the original Agent spawn. This is a different addressing mode from role-name SendMessage and is the mechanism Step 5a uses to probe a still-reachable architect for retro clarification. The `to:` field is the literal agentId string. This mode does NOT require the subagent to be a TeamCreate teammate.

Whenever this document says "spawn an X subagent" it means: call the Agent tool with `subagent_type: base:X`.

## Retrospective collection (cross-cutting)

This document references a `retro_bundle` — an in-session scratch object you (the lead)
maintain throughout a `/feature` run. Whenever a non-architect subagent's return contains a
`RETROSPECTIVE:` block with `skipped: false`, capture it into `retro_bundle` keyed by
phase:

- `retro_bundle.spec_validation` — at most one entry, from `base:spec-validator` (Step 2).
- `retro_bundle.exploration` — array, one per `base:code-explorer` parallel run (Step 3).
- `retro_bundle.planning` — array, one per `base:story-planner` mode invocation (Step 4 and Mode 3 calls).
- `retro_bundle.examiners` — array of `{story_id, flag}` from `base:verification-examiner` returns (Step 5.3).

Architect retros live in `{story_dir}/result.json#retrospective` (the canonical doer
record), including `absorbed_from` entries that already aggregate pbt-dev and codex/ollama
review POV. Do not duplicate them into `retro_bundle`.

If a return omits the `RETROSPECTIVE:` block entirely, treat it as skipped — that is a
valid state. Skip-allowed is part of the protocol.

`retro_bundle` is not written to disk. It is passed as input to `base:retro-synthesizer`
in Step 6.

## Input: $ARGUMENTS

### Non-Interactive Mode Detection

IF $ARGUMENTS ends with the literal token ` auto` (space + "auto", case-sensitive):
    non_interactive = true
    Strip the trailing ` auto` token from $ARGUMENTS before Step 1 processes it.
ELSE:
    non_interactive = false

When `non_interactive = true`, every `AskUserQuestion` call site in this document
has a paired abort branch — see Step 1 (slug derivation, SCAN), Step 1.5 (RECONCILE
adjudication), Step 2 (clarification rounds), and Step 5 (ESCALATE). At each such
site, instead of invoking `AskUserQuestion`, run the **Stamp-write procedure**
below with the appropriate `<reason>` from the closed enum (so the deferred-state
bookkeeping lands on disk while the slug is still in scope), then output
`ABORT:DEFERRED:<reason>:<detail>` on stdout and exit. The `already-resolved`
reason is emitted by the BACKLOG_PROMOTE working-tree probe (Step 1
### BACKLOG_PROMOTE mode); the `arch-debate-required` reason is emitted by the
arch-debate gate (Step 3 ### Produce Epic Architecture); the `escalated` reason
is emitted by the Decider escalation path (Step 5); the `spec-gap` reason covers
every other abort site (validator clarifications, planner gaps, etc.).

**The worker is the sole writer of the `[DEFERRED:<reason>:<detail>]` stamp.**
When this skill is dispatched in auto mode from `/base:next` with a
`backlog:<slug>` argument, the slug and the gap/evidence both live here, in
the worker's context. The worker writes the stamp BEFORE emitting the matching
`ABORT:DEFERRED:<reason>:<detail>` signal on stdout. `/base:next` Step 6a does
NOT fallback-write: if the worker skipped the stamp (direct invocation without
a `backlog:<slug>` argument, `Edit` failure), the dispatcher surfaces a WARNING
and exits. See `plugins/base/skills/backlog/references/format.md ### Deferred-state stamp`
("Sole signal — worker writes" + "No dispatcher fallback").

Earlier versions of this contract had `/base:feature` also append a separate
question finding capturing the gap; that produced duplicate writes (the
stamp said "deferred, skip" while the question said "blocked, halt the
pipeline"), and the question would later become an orphan when the original
was resolved. The append has been retired (and stays retired here). Direct
invocations (no dispatcher in front and therefore no `backlog:<slug>`
argument) still emit the abort signal on stdout for the human watching, but
skip the stamp write — there is no slug in scope to stamp against.

#### Stamp-write procedure (worker-side)

Run before emitting an abort signal on stdout, at every abort site referenced
from this section. Parameterised by a `<reason>` argument drawn from the
closed enum in `plugins/base/skills/backlog/references/format.md ### Deferred-state stamp`:

- `spec-gap` — worker cannot proceed without human spec input. Default for
  `AskUserQuestion` abort sites (Step 1 SCAN, Step 2 validator clarifications,
  Step 4 planner gaps).
- `already-resolved` — BACKLOG_PROMOTE working-tree probe found uncommitted
  hunks overlapping the anchor.
- `escalated` — Decider escalated (Step 5 ESCALATE branch).
- `arch-debate-required` — spec has `arch_debate: true` (Step 3 arch-debate gate).
- `legacy-orphan` — pre-v2 bullet with insufficient signal to re-classify.

The caller follows the stamp write with `ABORT:DEFERRED:<reason>:<detail>`
on stdout.

```
Preconditions: non_interactive = true AND the worker was invoked with
argument `backlog:<slug>` (so <slug> is in scope from Step 1's
BACKLOG_PROMOTE mode lookup, captured as `pending_finding_removal`).
If either fails, skip the stamp and exit with a WARNING — there is
no dispatcher fallback (per format.md "No dispatcher fallback").

1. Compute <detail> from the abort reason / evidence being constructed.
   Truncate so the total stamp framing
   (`[DEFERRED:` + <reason> + `:` + <detail> + `]`) is ≤80 chars; if
   longer, replace the trailing portion of <detail> with a single `…`
   per the one-line tonality rule in
   `plugins/base/skills/backlog/references/format.md`.

2. Read `BACKLOG.md` at the repo root. If missing, skip the stamp.

3. Locate the bullet under `## Findings` whose position-1 slug matches
   <slug> exactly (slug uniqueness is enforced at write time per
   `format.md ### Slug derivation`). If the lookup fails (file was
   hand-edited between dispatch and abort), skip the stamp.

4. Use the `Edit` tool to inject `[DEFERRED:<reason>:<detail>] ` (with a
   trailing space) immediately after the second ` — ` separator (between
   `` `<anchor>` `` and <text>). The slug, scope token, anchor, original
   <text>, and the ` (YYYY-MM-DD)` trailer are unchanged. Example:

       before: - my-slug [scope:base-plugin] — `path/to/spec.md` — Original prose. (2026-05-13)
       after:  - my-slug [scope:base-plugin] — `path/to/spec.md` — [DEFERRED:spec-gap:gap reason] Original prose. (2026-05-13)

5. If the `Edit` fails (file gone, slug no longer unique, race
   condition), proceed to emit the abort signal anyway — the dispatcher's
   sanity check will WARN and exit. There is no fallback writer.
```

After the stamp attempt (success or fail-silently), continue to emit
`ABORT:DEFERRED:<reason>:<detail>` on stdout and exit.

**Propagation to subagents and teammates.** The `non_interactive` flag does not
stop at the lead. Subagents (`base:spec-validator`, `base:code-explorer`,
`base:story-planner`, `base:integration-architect`, `base:verification-examiner`)
and TeamCreate teammates (`Decider`) each have their own prompts and can
independently invoke `AskUserQuestion` at their own decision points. When
`non_interactive = true`, every site that spawns one of those agents or defines a
teammate role MUST append the following instruction to the briefing:

> **Non-interactive mode:** You are operating without a human in the loop. Do NOT
> invoke `AskUserQuestion` under any circumstances. If you reach a decision point
> that requires human judgment to resolve — a design choice, an ambiguous spec, a
> conflict you cannot settle from available context — output the single line
> `ABORT:DEFERRED:spec-gap:<concise description of what needs specifying>` as the
> first line of your response and stop immediately. Do not guess, do not default
> silently, do not proceed with incomplete information.

And after every Agent spawn return or teammate message receive, when
`non_interactive = true`, apply this catch:

```
IF the return/message contains the literal string "ABORT:DEFERRED:":
    Parse the signal: <reason> and <detail> from "ABORT:DEFERRED:<reason>:<detail>".
    Run the Stamp-write procedure above with the parsed <reason> and <detail>.
    Output: "ABORT:DEFERRED:<reason>:<detail>" on stdout and exit the current skill.
```

Subagents that are pure data processors with no human-judgment decision
points (`base:retro-synthesizer`, `base:project-curator`) are exempt from
the instruction injection and the catch.

---

## Step 1: Determine What We're Working With

```
IF argument starts with "specs/epic-":
    mode = RESUME (read epic-state.json, pick up where we left off; runs RECONCILE first — see Step 1.5)
ELSE IF argument starts with "backlog:":
    mode = BACKLOG_PROMOTE (read BACKLOG.md, promote the named finding to a stub spec, then NEW)
ELSE IF argument is a .md file path or starts with @:
    mode = NEW (validate spec, plan stories, then implement)
ELSE IF no argument:
    mode = SCAN (look for in-progress epics in specs/epic-*/)
ELSE:
    mode = NATURAL_LANGUAGE (gather requirements, generate spec, then NEW)
```

If SCAN finds in-progress epics, ask the user which to resume or whether to start fresh. SCAN should also note whether `BACKLOG.md` exists and has open Findings — if so, mention it as one option ("Or run `/base:orient` to see the project-wide picture") without making it the default.

**Non-interactive abort.** When `non_interactive = true` and mode resolves to SCAN
(no argument), abort immediately. This path is reached without a
`backlog:<slug>` argument (the worker was invoked on a bare prompt with
`auto`), so the Stamp-write procedure's precondition fails and the stamp is
skipped — there is no dispatcher fallback. Output
`ABORT:DEFERRED:spec-gap:auto mode requires an explicit backlog slug or spec path; cannot scan interactively.` and exit.

### BACKLOG_PROMOTE mode

Argument form: `backlog:<slug>` where `<slug>` is the position-1 slug
of an entry in `BACKLOG.md ## Findings` (unique by construction per
`plugins/base/skills/backlog/references/format.md ### Slug derivation`).

```
1. Read BACKLOG.md. If missing, abort with: "no BACKLOG.md — run /base:backlog init first."

   **v1 refusal.** If `## Findings` contains any v1 bullets (position 1
   starts with backtick `` ` ``, the literal `-`, or position 3 contains
   `[INSUFFICIENT:` / `[ALREADY-RESOLVED:` / `Auto-dispatch aborted:`),
   refuse to proceed and surface the migration command:

   > BACKLOG.md contains v1 bullets; run `/base:backlog migrate-v2` first.
   > Direct worker invocations do not auto-migrate — only `/base:next` and `/base:orient` do.

   See `plugins/base/skills/backlog/references/format.md ### Migration from v1 grammar`.
2. Locate the matching finding bullet under ## Findings by exact
   position-1 slug match (`grep -F "<slug>"` against the position-1
   token). If zero matches, abort with the candidate list. Slug
   uniqueness is enforced at write time, so >1 matches indicates a
   malformed BACKLOG.md.
2a. **Working-tree probe (auto mode only).** When `non_interactive = true`,
    before doing any other work for this finding, perform the BACKLOG_PROMOTE
    working-tree probe defined canonically in
    `plugins/base/commands/bug.md` ### BACKLOG_PROMOTE mode (Step 3a). The
    algorithm is identical here: parse the bullet's anchor into
    `(path, line_range)`; when the anchor has a `:line` or `:N-M` suffix
    the probe is line-precise (uses `git diff HEAD -- <path>` and requires
    a hunk's HEAD-side range to overlap the anchored line range); when
    the anchor has no line component it falls back to file-level
    detection via `git status --porcelain -- <path>`; when the anchor is
    `-` the probe is skipped entirely. See `bug.md` for the full
    procedure, including edge cases (untracked files with a line_range,
    empty `git diff` despite non-empty porcelain status, pure-addition
    `-0,0` hunks) and the truncation rules for `<evidence>`.

    On abort, run the **Stamp-write procedure** (see Non-Interactive Mode
    Detection block above) with `<reason> = already-resolved` and
    `<detail> = <evidence>`, then emit on stdout, exactly:
        ABORT:DEFERRED:already-resolved:<evidence>
    and exit the worker. Do not scaffold the spec stub, do not write
    `epic-state.json`, do not invoke any subagent. (This is the
    `/base:feature` substitution for `bug.md`'s "do not scaffold the bug
    report …" abort exit — the rest of the algorithm is unchanged.)

    Skip this probe entirely when `non_interactive = false` (the user
    can see the working tree themselves).
3. The epic slug for this promotion is the finding's `<slug>` (position
   1 of the bullet, already in scope from step 2). Coined per
   `plugins/base/skills/backlog/references/format.md ### Slug derivation`
   when the finding was first written. No re-derivation — the slug is
   the durable identity that links the BACKLOG bullet, the dispatcher
   args, the epic dir, and every downstream stamp/resolve op.
4. Scaffold the empty stub by invoking Skill("base:spec-template", args: "<slug>") — that skill creates `specs/epic-<slug>/spec.md` and `acceptance-criteria.md` with title-only content (it deliberately does NOT generate project-specific content; see its SKILL.md).

   Then the lead authors the spec inline. **Draft depth branches on `non_interactive`:**

   - **`non_interactive == true` (auto dispatch).** No session context to draw on — the dispatcher handed in a finding slug, no design conversation occurred. Edit `specs/epic-<slug>/spec.md` to inject the finding's text into `## Problem` (plus a `Source: BACKLOG.md finding promoted YYYY-MM-DD` line) and the finding's anchor into `## Technical Approach` as a starting reference. Leave the rest as template stubs — Step 2's spec validation catches the gaps and emits `ABORT:DEFERRED:spec-gap:<detail>` per the existing flow. Continue directly to step 5; no pause.

   - **`non_interactive == false` (interactive dispatch).** The lead is in the same session that produced or refined this finding; draw on that session context plus the finding text. Author every section the session context warrants: `## Problem` (with Source line), `## Solution` at intent level, `## Scope` (In Scope / Out of Scope), `## Design Decisions` with file:line refs where useful, `## Technical Approach` with affected-file subsections and a worked example when helpful, `## Stories` (typically single-story for a backlog promotion — split only when scope genuinely warrants), `## Non-Goals` fencing off rejected directions surfaced in session. Also author `acceptance-criteria.md` with executable AC text — not just section headers.

     **Authorship guardrail.** For any section the session context does NOT genuinely warrant (cold invocation, finding text doesn't constrain that section, design question is genuinely open), leave the template stub in place rather than guessing. The lead's authorship authority comes from session context; absent context, visible blanks are honest. A shallow draft beats a confident-but-wrong draft.

     **Rationale.** Earlier versions of this contract had the lead inject minimal text and pause for the user to fill the remaining sections. In interactive mode that proved too heavy when the design conversation had already happened in-session — the lead has the context to write the whole spec and the user has to redirect anyway during review. Authoring up front converts the pause from a fill-in-the-blanks task into a review checkpoint, which the user redirects from faster.
5. Capture the finding slug in an in-session variable `pending_finding_removal = <slug>`. **Do NOT remove the bullet yet** — the source finding stays in `## Findings` until Step 3 has successfully written `epic-state.json`. This makes promotion atomic: if Step 2 validation aborts or the user abandons the run, the finding is still in the backlog (and the orphaned `specs/epic-<slug>/` stub is detectable by `/base:orient` Rule 2 as drift).
6. Set the spec file path to `specs/epic-<slug>/spec.md`, capture the slug as the in-session variable `promoted_slug = <slug>` (Step 3 will pin `epic_name` to this value rather than re-deriving from the title — the user is allowed to edit the title before validation, and re-deriving would orphan the promoted stub), and fall through to NEW mode (Step 2). Mark the in-session mode as `BACKLOG_PROMOTE` so Step 3 can skip the redundant copy and consume `pending_finding_removal`.
```

After authoring (per step 4 above), in **interactive mode** the lead pauses with a review prompt — surfacing the spec path and inviting either edits or `proceed`. The pause is a review checkpoint, not a fill-in-the-blanks task; users redirect from a complete draft faster than they author from template stubs, so favor authoring up front. In **auto mode** the lead does not pause; it falls through directly into Step 2 (which carries its own `ABORT:DEFERRED:spec-gap:…` catch for any remaining spec gaps). If the user abandons interactive mid-validation, the half-scaffolded spec dir is left in place — `/base:orient` will surface it as a stale spec on the next session and the user can either resume or delete.

---

## Step 1.5: RECONCILE (mode = RESUME only)

When resuming an existing epic, the spec on disk may have drifted from code reality — work was done out-of-band, the spec was hand-edited, or another epic touched the same surface. This phase re-grounds the spec against the workspace before consuming it. **Cheap when nothing moved; bounded when something did.**

### Cache check

```bash
spec_sha=$(cat specs/epic-{name}/spec.md specs/epic-{name}/acceptance-criteria.md 2>/dev/null \
    | git hash-object --stdin \
    | cut -c1-12)
git_sha=$(git rev-parse HEAD)
cache_path="specs/epic-{name}/reconciliation.json"
```

The `cat | git hash-object --stdin` form is intentional: it produces one deterministic SHA-1 over the concatenated content of both files, with **no dependency on `sha256sum`** (which is not present on stock macOS — the BSD-derived install ships `shasum` but not `sha256sum`, and any choice here must work cleanly on macOS, Linux, and CI containers without extra packages). `git hash-object --stdin` is universally available wherever this plugin runs (it requires only `git`, which the workflow already requires elsewhere).

The cache is valid only if all three of the following hold:
1. `reconciliation.json` exists.
2. Its `spec_sha` and `git_sha` fields match the current values.
3. Its `verdicts` array contains zero entries with `verdict` of `violated` or `partially-holds` (i.e., the prior reconcile left no outstanding drift — every AC was either `holds`/`unverifiable` at inspection time, or was adjudicated into one of those states by `retire`/`rewrite`/`split` which mutate the spec and so would have also moved the spec_sha).

If all three hold → skip the inspection; proceed to Step 2 (validation). If any fail → run the inspection.

This is the load-bearing guarantee against the `keep`-then-cache-then-suppress failure mode: when the user picks `keep` on a `violated` AC (defect to be fixed during the epic, no spec change), the post-adjudication verdicts still contain that violation, so the cache check below refuses to short-circuit on the next resume — RECONCILE re-inspects until either the code now satisfies the AC (verdict becomes `holds`) or the user adjudicates differently.

### Inspection

The lead reads `acceptance-criteria.md` and classifies each AC into one of four states using read-only tools (Read, Grep, Glob, Bash for read-only inspection — never Edit/Write during this phase):

| Verdict | Meaning |
|---|---|
| `holds` | Code or tests demonstrate the AC is satisfied today. |
| `partially-holds` | Some aspects covered, others not. Cite the gap. |
| `violated` | Code or test evidence contradicts the AC. |
| `unverifiable` | Cannot determine from cheap inspection (e.g. AC requires manual validation, or refers to runtime behavior that needs a test run). |

Bound the work: ≤5 read-only tool calls per AC, skip ACs whose `## Manual Validation` section flags them as manual-only. For epics with >20 ACs, batch the inspection — spawn `Agent(subagent_type: base:code-explorer)` once per story-grouped AC subset, in parallel, with a focus prompt that explicitly asks for the four-state verdict per AC. Each explorer returns a JSON list of `{ac_id, verdict, evidence}`.

### Persist and adjudicate

Write `specs/epic-{name}/reconciliation.json`:

```json
{
  "spec_sha": "<12-char hex>",
  "git_sha": "<full sha>",
  "computed_at": "<ISO timestamp>",
  "verdicts": [
    {"ac_id": "AC-STRUCT-1", "verdict": "holds", "evidence": "src/foo.ts:42 implements"},
    {"ac_id": "AC-ERR-3", "verdict": "violated", "evidence": "test/foo.test.ts:88 expects different shape"},
    ...
  ]
}
```

If every verdict is `holds` or `unverifiable`, log the result and proceed to Step 2.

If ANY verdict is `partially-holds` or `violated`, present an adjudication menu via `AskUserQuestion`. For each non-holds AC, the user picks one of:

**Non-interactive abort.** When `non_interactive = true`, do NOT present the adjudication menu. RECONCILE only runs in RESUME mode (Step 1.5), so there is no `backlog:<slug>` argument in scope — the Stamp-write procedure's precondition fails and the stamp is skipped; there is no dispatcher fallback. Output `ABORT:DEFERRED:spec-gap:RECONCILE requires human adjudication.` on stdout and exit.


- **`keep`** — the AC stays unchanged. Use this both when "the AC is correct, the code is wrong" (defect to be fixed during this epic) AND when "the AC is correct and the code already satisfies it" (the verification examiner will find it satisfied during normal flow — usually fast-path pass with no architect work). RECONCILE does not pre-mark stories `done`; that pathway corrupts crash-recovery's artifact-validation contract (each `done` story must own all four artifacts, which RECONCILE does not produce).
- **`retire`** — the AC is no longer applicable; replace its line in `acceptance-criteria.md` with `**AC-<TAG>-N** — *retired (RECONCILE 20YY-MM-DD)*` and append an entry to `spec.md ## Amendments`.
- **`rewrite`** — the AC needs new wording; user supplies replacement text inline. Edit in place; append amendment.
- **`split`** — the AC needs to become two; user supplies the split. Add new IDs (next available N for the tag); append amendment.

Apply the chosen actions, then **always** rewrite `reconciliation.json` so the next resume sees the post-adjudication picture. The verdict for each AC is recomputed for persistence by the simple rule:

- `retire` → drop the AC from the persisted verdicts list (it no longer exists in `acceptance-criteria.md`).
- `rewrite` / `split` → drop the affected verdict and add a fresh `unverifiable` entry per replacement AC (these will get inspected on the next resume because the spec_sha will have changed anyway).
- `keep` → **leave the original `violated` / `partially-holds` verdict in the persisted file**. This is what makes the cache check above refuse to short-circuit until the underlying code is fixed; do NOT downgrade the verdict to `holds` just because the user accepted it as known work.

Net effect: a clean adjudication (every non-holds AC retired/rewritten/split) produces a cache that legitimately short-circuits next resume; an adjudication containing any `keep`-on-non-holds produces a cache that records the open work and forces re-inspection next resume. The cache file is the durable record of "what RECONCILE found and how the user routed it" rather than just "we ran RECONCILE once."

**Never auto-rewrite the spec.** The user adjudicates every non-holds verdict. Silent spec rewrites are the load-bearing failure mode this phase exists to prevent. **Never auto-mark stories `done` from RECONCILE either.** RECONCILE operates at AC granularity; story completion is granted only by Step 5's implementation loop (which produces the four artifacts crash recovery validates against).

After adjudication, proceed to Step 2 (validation) — which will now operate on a spec consistent with the workspace.

---

## Step 2: Validate the Specification (Lead does this directly)

Read the spec file. Check for:
- Clear problem statement and motivation
- Defined functional requirements with inputs/outputs
- Testable acceptance criteria
- Scope boundaries (in-scope and out-of-scope)
- Error handling and edge cases

The canonical format for `specs/epic-<slug>/spec.md` and
`acceptance-criteria.md` is documented in `base:spec-template` — cite it in
clarification messages when a section is missing or an AC ID is malformed
(e.g. "spec rejected: `## Non-Goals` missing — see `base:spec-template`").

### Load adjacent project state

Before validating, gather lightweight context from project meta-state — this catches the "we're about to relitigate a settled question" case at the cheapest possible point:

- **ADRs**. For each `docs/adr/ADR-*.md` read only the frontmatter block — everything from line 1 through the first blank line that precedes `## Context`, which captures `Title`, `Status`, `Date`, `Type`, `Affects:`, `Supersedes:`, and `Superseded by:` (typically lines 1–9 inclusive; use `awk '/^## /{exit} {print}'` to extract precisely the right span without hardcoding a line count). Identify any ADR whose title OR `Affects:` field plausibly governs this spec's domain. If matches exist, read their full bodies and surface them to the user before validation: "this spec proposes X; ADR-007 constrains <related area>. Confirm consistency." `Status: Superseded` ADRs are skipped — only Accepted (or Proposed, surfaced with that caveat) ADRs are constraints.
- **Rejection archive**. If `BACKLOG.md` exists, read its `## Archive` section. Every entry in this section is a rejection by virtue of where it lives (the canonical bullet shape is `- YYYY-MM-DD — <text> — <reason>`; there is no per-line tag — see `plugins/base/skills/backlog/references/format.md`). For each entry whose text shares a topic word or path component with the proposed spec, surface verbatim: "the spec proposes X; archive entry from YYYY-MM-DD rejected a similar approach because <reason>. Reconcile."

Both checks are advisory — the user decides whether the new spec is consistent or needs adjustment. The lead does not block on these surfaces; it raises them once and proceeds based on the user's response.

For NEW mode (spec just authored or scaffolded from BACKLOG_PROMOTE), this is the spec's first encounter with project state. For RESUME mode, Step 1.5 has already reconciled the spec against the workspace; this step's job is to catch ADR/archive constraints rather than spec-vs-code drift.

If gaps exist, use AskUserQuestion to get clarifications. Update the spec. Max 3 rounds — if still unclear, stop and explain what's missing.

**Non-interactive abort.** When `non_interactive = true`, do NOT invoke `AskUserQuestion` for spec clarifications. Capture the first gap identified, run the Stamp-write procedure (see Non-Interactive Mode Detection block above) with `<reason> = spec-gap` and `<detail> = "{first gap}"`, then output `ABORT:DEFERRED:spec-gap:{first gap}` on stdout and exit. There is no dispatcher fallback; if the stamp Edit fails or no slug is in scope (direct invocation), the dispatcher surfaces a WARNING.

For complex specs, use the Agent tool with `subagent_type: base:spec-validator` for thorough analysis. Pass the discovered ADRs and matching archive entries to the validator as input context. When `non_interactive = true`, include the non-interactive mode instruction (see Non-Interactive Mode Detection block above) in the spawn prompt — the validator might otherwise surface clarification needs via `AskUserQuestion`. If its return contains a `RETROSPECTIVE:` block with `skipped: false`, capture it into `retro_bundle.spec_validation` (see "Retrospective collection (cross-cutting)" near the top of this file).

When `non_interactive = true`, apply the ABORT:DEFERRED catch (see Non-Interactive Mode Detection block above) to the spec-validator return before processing the retrospective.

---

## Step 3: Create Epic Structure

### Language Detection

Detect project language from config files:
- `pyproject.toml` / `setup.py` → Python
- `package.json` → JavaScript/TypeScript
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml` / `build.gradle` → Java
- `build.gradle.kts` → Kotlin

Consult `skills/languages/{language}.md` for build/test commands and conventions throughout.

### Create Directories and State

```bash
if [ "$mode" = "BACKLOG_PROMOTE" ]; then
    # In BACKLOG_PROMOTE mode the slug captured in Step 1 is authoritative —
    # do NOT re-derive from the spec's # title heading, because the user is
    # explicitly allowed to edit the title before validation. Re-deriving
    # would create a second specs/epic-<title-derived>/ directory and orphan
    # the original specs/epic-<slug>/ stub.
    epic_name="$promoted_slug"
else
    epic_name=$(grep -m1 "^# " "$spec_file" | sed 's/^# //' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
fi
mkdir -p "specs/epic-${epic_name}"
canonical_spec="specs/epic-${epic_name}/spec.md"
if [ "$(realpath "$spec_file" 2>/dev/null)" != "$(realpath "$canonical_spec" 2>/dev/null)" ]; then
    cp "$spec_file" "$canonical_spec"
fi
```

In `BACKLOG_PROMOTE` mode the slug captured by Step 1 (stored as `promoted_slug` in-session) is the authoritative epic name. Re-deriving from the spec's `# Title` heading would silently rename the epic when the user edits the title before validation — creating a second `specs/epic-*/` directory and leaving the original promoted stub as orphan repo state. In every other mode, the title-heading derivation stands.

The `realpath` check skips a self-copy in `BACKLOG_PROMOTE` mode (where `$spec_file` already points to `specs/epic-<slug>/spec.md` because the spec was scaffolded there in Step 1) and in any other case where the source already sits at the canonical destination. macOS `cp X X` exits 1 with "are identical (not copied)"; the guard prevents that.

### Write epic state

Write `specs/epic-${epic_name}/epic-state.json`:
```json
{
  "epic_name": "{epic_name}",
  "status": "planning",
  "phase": "SPEC_VALIDATED",
  "created_at": "{timestamp}",
  "updated_at": "{timestamp}",
  "completed_stories": [],
  "escalated_stories": [],
  "phase_history": [
    {"phase": "SPEC_VALIDATED", "timestamp": "{timestamp}", "trigger": "validation_passed"}
  ]
}
```

### Update BACKLOG.md (atomic — append-epic + consume-pending-finding)

These two `BACKLOG.md` mutations both run only after `epic-state.json` has been successfully written above — the new `specs/epic-<slug>/` directory and its state file are the durable replacement record. Perform them as a single read-modify-write on `BACKLOG.md` so they cannot half-apply: read the file once, prepare both edits in memory, write once. If `BACKLOG.md` does not exist, both substeps are skipped silently; the curator at Step 6 will hint to the user that `/base:backlog init` would unlock backlog integration.

1. **Append the epic bullet to `## Epics`** so the in-progress epic is visible to parallel readers and to `/base:orient` from this point forward (the corresponding end-of-run flip to `DONE`/`ESCALATED` is performed unconditionally by the lead at Step 6.1; the curator is not involved in the bullet's lifecycle for this epic):

   ```
   - specs/epic-{epic_name}/ — IN_PROGRESS — created YYYY-MM-DD
   ```

   At Step 6.1, the **lead** unconditionally flips this bullet to `DONE` (or to `ESCALATED` if the run escalated) — outside the curator's cap-5 budget. The curator's `update_epics_section` action is reserved for *other* drift cases the lead's bookkeeping cannot have caught (deleted out-of-band, parallel-session-created, etc.); see `base:project-curator` for the enumerated cases.

2. **Consume `pending_finding_removal`** (BACKLOG_PROMOTE mode only): if the in-session mode is `BACKLOG_PROMOTE` and `pending_finding_removal` is set, remove the source bullet from `## Findings` whose position-1 slug matches the captured `<slug>` exactly.

If the combined write fails (permission, I/O), surface the failure rather than silently leaving partial state; the user picks: retry, hand-edit, or accept the no-backlog-update outcome (the spec dir + epic-state.json are already on disk, so re-running `/base:feature specs/epic-<slug>` will resume cleanly with `/base:orient` flagging the missing bullet via Rule 2).

### Codebase Exploration

Use the Agent tool with `subagent_type: base:code-explorer` to launch 2-3 explorers in parallel (one Agent call per focus, sent in a single message), with different focuses:
- **similar-features**: Existing features resembling this one
- **architecture**: Module boundaries, abstraction layers, data flow
- **testing-and-conventions**: Test framework, conventions, E2E infrastructure

When `non_interactive = true`, append the non-interactive mode instruction (see Non-Interactive Mode Detection block above) to each explorer's prompt.

Merge results into `specs/epic-{name}/exploration.json`. For each explorer return that contains a `RETROSPECTIVE:` block with `skipped: false`, append it to `retro_bundle.exploration` (one entry per non-skipped flag, with the focus name preserved).

When `non_interactive = true`, apply the ABORT:DEFERRED catch (see Non-Interactive Mode Detection block above) to each explorer return before merging.

### Initialize Mocks Registry

```json
{
  "created_at": "{timestamp}",
  "updated_at": "{timestamp}",
  "mocks": [],
  "all_resolved": true
}
```

### Produce Epic Architecture (always-on)

After codebase exploration, before creating the team, produce `specs/epic-{name}/architecture.md`.

Check `specs/epic-{name}/spec.md` YAML frontmatter for `arch_debate: true`.

**If `arch_debate: true`:**

When `non_interactive = true`, do NOT invoke the skill — `base:arch-debate` requires human deliberation and is not auto-dispatchable. Run the Stamp-write procedure (see Non-Interactive Mode Detection block above) with `<reason> = arch-debate-required` and `<detail> = "arch_debate: true requires human deliberation"`, then output `ABORT:DEFERRED:arch-debate-required:arch_debate: true requires human deliberation` on stdout and exit. There is no dispatcher fallback; if the stamp Edit fails the dispatcher surfaces a WARNING.

Otherwise (interactive mode), invoke `Skill("base:arch-debate", args: "--epic {epic_name} --spec specs/epic-{name}/spec.md")`.
The skill reads `exploration.json`, runs a two-round Proposer ↔ Codex adversary debate, and outputs:
- `docs/adr/ADR-{N:03d}-{epic-name}.md` — the decision record
- `specs/epic-{name}/architecture.md` — the operational document all agents read

**Default path (no debate flag):**
Synthesize `exploration.json` directly into `specs/epic-{name}/architecture.md`:
1. **Paradigm** — use the named paradigm from the code-explorer architecture findings. If the exploration did not identify one, default to: modular monolith at top level, package-by-feature for module layout, hexagonal seams at external boundaries.
2. **Module map** — list each module this epic touches or creates: name, purpose, directory location, owned data.
3. **Boundary rules** — "No direct imports across module boundaries. Cross-module access only through declared seam contracts." Add any project-specific rules from exploration.json.
4. **Seams** — initially empty; the planner populates these when it identifies cross-story dependencies.
5. **Implementation constraints** — any constraints from the spec or existing codebase patterns.

`architecture.md` must exist before the team is created.

---

## Step 4: Create the Team

Create an agent team with one role. The lead (this session, running on Sonnet) does the mechanical coordination — spawning subagents, reading artifacts, updating state files, applying fast-path decision rules. The Decider (Opus) is the decision authority, consulted only on non-trivial judgment calls.

### Team Composition

**Decider** (1 teammate, model: opus)
> You are the decision authority for this epic. You are consulted only when
> the lead escalates a non-trivial judgment call. Routine outcomes (story
> passed, first retry on a clear failure) are handled by the lead without
> your input.
>
> When the lead messages you, it will provide: story artifacts, failure
> details, remediation history, and a specific question. Respond with one of:
>   RETRY — restate the problem as a specific remediation prompt for the
>           architect. Include the exact files, lines, and what must change.
>   ESCALATE — the story cannot be resolved automatically. Provide the reason
>              and what the user must decide.
>   ACCEPT — the story outcome is acceptable despite partial findings. State
>            any caveats to record in result.json.
>   REJECT — enumerate the specific failures that block acceptance.
>
> You do not spawn subagents. You do not manage state files. You do not read
> artifacts yourself unless the lead provides them in context.

When `non_interactive = true`, append the non-interactive mode instruction (see Non-Interactive Mode Detection block above) to the Decider's role definition. Additionally, because the Decider's `ESCALATE` response routes back to `AskUserQuestion` in the lead, append: "When `non_interactive = true`, if you would respond `ESCALATE`, respond `ABORT:DEFERRED:escalated:<reason>` instead — the lead will catch this, stamp the original finding `[DEFERRED:escalated:<reason>]` via the worker-side Stamp-write procedure, and emit `ABORT:DEFERRED:escalated:<reason>` on stdout rather than asking the user."

### Planning Phase

After creating the Decider, run the planning phase. The planner runs in
three modes; spawn it once per mode (fresh subagent each time).

1. Spawn `Agent(subagent_type: base:story-planner)` in **Mode 1** with: spec
   path, exploration.json path, architecture.md path. Output:
   `acceptance-criteria.md`. When `non_interactive = true`, include the
   non-interactive mode instruction (see Non-Interactive Mode Detection block
   above) in the spawn prompt. Wait for completion. When `non_interactive = true`,
   apply the ABORT:DEFERRED catch (see Non-Interactive Mode Detection
   block above) to the planner return before processing.
2. Spawn `Agent(subagent_type: base:story-planner)` in **Mode 2** with: spec
   path, acceptance-criteria.md path, architecture.md path. Output:
   `stories.json`. When `non_interactive = true`, include the non-interactive
   mode instruction in the spawn prompt. Wait for completion. When
   `non_interactive = true`, apply the ABORT:DEFERRED catch to the
   planner return before processing.
3. Read `stories.json` directly. Sanity check: all ACs covered,
   `story_order` defined, no duplicate story IDs.
   - If issues are minor and unambiguous (typos, missing scope boundary,
     missing AC reference): re-spawn Mode 2 with targeted corrections (apply
     the same non-interactive instruction injection and ABORT catch as above).
   - If issues require judgment (AC interpretation, story split
     disagreement, scope ambiguity): `SendMessage(Decider)` with the gap
     and the specific question. Apply the Decider's response before
     proceeding. When `non_interactive = true`, apply the ABORT:DEFERRED
     catch to the Decider's message before acting on it — if it contains
     `ABORT:DEFERRED:`, parse `<reason>` and `<detail>`, run the
     Stamp-write procedure with those parameters, then emit
     `ABORT:DEFERRED:<reason>:<detail>` on stdout and exit.
4. Spawn `Agent(subagent_type: base:story-planner)` in **Mode 3** with:
   stories.json path, acceptance-criteria.md path, architecture.md path.
   Output: one `{story_dir}/verification.json` per story containing the
   pre-impl commitment set. The planner creates the story directories.
   When `non_interactive = true`, include the non-interactive mode instruction
   in the spawn prompt. Wait for completion. Sanity check: every story listed in
   `stories.json` has a `verification.json` with at least 5 pre-impl
   records plus one SPEC record per AC in its `acceptance_criteria`. When
   `non_interactive = true`, apply the ABORT:DEFERRED catch to the
   planner return before processing.
5. When all three modes have produced their artifacts, proceed to the
   implementation loop in Step 5.

For each story-planner return (Mode 1, Mode 2, Mode 3) that contains a `RETROSPECTIVE:` block with `skipped: false`, append it to `retro_bundle.planning` (preserve the mode label).

The lead spawns `base:story-planner` via the Agent tool — never via TeamCreate or SendMessage. There is no persistent Planner teammate.

**Why three modes, not one.** The pre-impl commitment set is authored by
the planner — not by the implementing architect — to eliminate the
rubber-stamp risk of letting the agent that writes the code also write
the questions about its own code. The planner is also the only agent
that has both the AC list and the story split in front of it at once,
which is what Part B (one SPEC question per AC) needs.

---

## Step 5: Coordinate the Workflow

As lead, you drive the implementation loop directly. There is no persistent Architect or Verifier teammate. For each story you spawn fresh `base:integration-architect` and `base:verification-examiner` subagents via the Agent tool. The Decider is consulted only on judgment calls per the routing rules below.

### Implementation loop

```
FOR each story in stories.json ordered by story_order WHERE status = pending:

  1. Update stories.json: story status → in_progress.
     Update epic-state.json: updated_at.

  2. Read `story.lighter_path` from stories.json for the current story
     (default `false` if the property is absent — the schema marks it
     optional; old stories.json files that predate S2 of
     `epic-fast-track-routing` lack the field and MUST route through the
     full architect path).

     **IF `story.lighter_path == true` (lighter-path branch):**

       a. Write `{story_dir}/architecture.json` with the minimal
          lighter-path contract:

          ```json
          {
            "decision": "lighter_path",
            "architect_skipped": true,
            "reason": "<one-line summary of the heuristic match — e.g. 'all file targets in markdown_class_extensions; every AC fully specified; no new file'>"
          }
          ```

       b. Write `{story_dir}/baseline.json` with the no-test-baseline
          stub:

          ```json
          {
            "test_snapshot": "skipped",
            "reason": "markdown-class-no-test-baseline"
          }
          ```

       c. The lead implements the story directly via `Edit` calls on the
          story's file targets, citing the story's ACs inline as the
          implementation proceeds. **No `Agent(subagent_type:
          base:integration-architect)` spawn occurs on this story under
          this branch** (AC-FEATURE-1). There is no architect agentId to
          capture for the retro probe in bullet 5; record the absence
          via the `result.json.retrospective.skipped: true` write in
          step 2d below.

       d. Write `{story_dir}/result.json` with the lighter-path stub.
          The four fields below are the load-bearing additions for
          AC-FEATURE-2 and AC-OBS-2; honour the rest of
          `plugins/base/schemas/result.schema.json` for required fields
          (`story_id`, `status`, `remediation_rounds`, `retrospective`):

          ```json
          {
            "story_id": "<id>",
            "status": "done",
            "final_outcome": "accepted",
            "architect_skipped": true,
            "files_modified": ["<list of files Edit was called on>"],
            "remediation_rounds": 0,
            "completed_at": "<ISO 8601 timestamp>",
            "retrospective": {
              "skipped": true,
              "reason": "lighter-path; no architect retro"
            }
          }
          ```

       e. **Continue to bullet 3 below — the examiner still runs**
          (AC-FEATURE-3). The lighter-path branch only skips the
          architect, not the examiner. Do NOT mark `stories.json` /
          `epic-state.json` done yet — that promotion lives in bullet
          4's FAST PATH — pass / FAST PATH — retry / Decider branches,
          which run identically for both paths.

     **ELSE (`story.lighter_path == false` or absent — existing full
     path):**

     Spawn Agent(subagent_type: base:integration-architect) with:
       - the story spec (the relevant entry from stories.json)
       - acceptance criteria (acceptance-criteria.md, filtered to this story's ACs)
       - exploration.json (path)
       - architecture.md (path)
       - {story_dir}/verification.json (path) — pre-authored by the
         story-planner in Mode 3; pre-impl questions are immutable, the
         architect appends post-impl records only.
     When `non_interactive = true`, include the non-interactive mode instruction
     (see Non-Interactive Mode Detection block above) in the spawn prompt.
     Context MUST NOT include result.json or artifacts from prior stories — every story gets a fresh subagent with a clean context window. **Capture the architect's agentId** (returned by the Agent tool) and keep it for this story so Step 5 (the optional retro probe) can re-engage the same architect by agentId. Wait for the subagent to write {story_dir}/result.json.

     When `non_interactive = true`, apply the ABORT:DEFERRED catch (see
     Non-Interactive Mode Detection block above) to the architect return.

     If {story_dir}/verification.json is missing for this story, the
     planner did not complete Mode 3 — re-spawn `base:story-planner` in
     Mode 3 for this story before spawning the architect (apply the same
     non-interactive instruction injection and ABORT catch as in Step 4).

  3. Read {story_dir}/verification.json.
     Spawn Agent(subagent_type: base:verification-examiner) for each verification question, or each batch of related questions. Independent batches MUST be sent in parallel — single message, multiple Agent tool calls. When `non_interactive = true`, include the non-interactive mode instruction (see Non-Interactive Mode Detection block above) in each examiner's spawn prompt. Each examiner returns YES, NO, or PARTIAL with severity and evidence.
     Collect all results. When `non_interactive = true`, apply the ABORT:DEFERRED catch to each examiner return before tallying. For each examiner return that contains a `RETROSPECTIVE:` block with `skipped: false`, append `{story_id, flag}` to `retro_bundle.examiners` (see "Retrospective collection (cross-cutting)" near the top of this file).

     **Examiner spawn is unconditional on `lighter_path`** (AC-FEATURE-3).
     This bullet runs identically whether bullet 2 took the lighter-path
     branch or the full-path branch; only the architect is skipped on
     the lighter path, never the examiner.

  4. Apply decision rules:

     FAST PATH — pass:
       All questions YES, or PARTIAL with severity < 4 AND confidence ≥ 0.7. All tests pass. No examiner reports a stub-scan hit or a missing-test downgrade. No `root_cause_category` of `security_gap`, `arch_violation`, or `missing_contract` on any PARTIAL.
       → Update {story_dir}/result.json: status=done, final_outcome=accepted, completed_at. (On the lighter-path branch the stub written in bullet 2d already has these fields; treat the FAST PATH — pass write as idempotent.)
       → Update stories.json: this story's status → done.
       → Update epic-state.json: append story ID to completed_stories.
       → Continue to next story. (No Decider consult.)

     FAST PATH — first retry:
       One or more questions NO, or PARTIAL with severity 4–6. remediation_round = 0. Root cause is clear and unambiguous in the examiner output (single named file, single named defect) AND `root_cause_category` is one of {missing_test, impl_bug, dead_code, duplication, documentation}.
       → Spawn a fresh Agent(subagent_type: base:integration-architect) with the examiner findings as the remediation brief.
       → Re-run step 3 (spawn fresh examiners). If the result is now FAST PATH — pass, advance. Otherwise → ESCALATE.

     **Lighter-path remediation fallback (AC-FEATURE-4).** If bullet 2
     took the lighter-path branch (this story's `architect_skipped` is
     `true` in the freshly-written `result.json`) AND the examiner
     outcome triggers either FAST PATH — first retry OR an ESCALATE that
     leads to a Decider `RETRY` / `REJECT` response, the remediation
     path MUST spawn `Agent(subagent_type: base:integration-architect)`
     with the examiner findings (or Decider remediation prompt) as the
     brief — even though no architect ran in bullet 2. The lead MUST NOT
     attempt a second lead-written implementation on the same story.
     The architect is the round-1 remediator for lighter-path failures.

     Before that fallback spawn, update bookkeeping so the recorded path
     matches the actual path taken:
       - Set `story.lighter_path = false` in stories.json (the recorded
         flag now reflects that this story fell through to the full
         path; subsequent crash recovery and retros see reality).
       - On the eventual final write of `{story_dir}/result.json` by the
         architect, the `architect_skipped` field MUST be `false` (or
         omitted, which defaults to `false`) — the architect actually
         ran. The lighter-path stub's `architect_skipped: true` is
         superseded by the architect's authoritative write.

     Capture the architect's agentId from the fallback spawn so bullet 5's
     optional retro probe can reach the architect that did the
     remediation work — same agentId-capture convention as bullet 2's
     full-path branch.

     ESCALATE:
       Triggered by any of:
         - remediation_round ≥ 1 and still failing
         - Any PARTIAL with severity ≥ 7 (always — no fast-path retry, regardless of root-cause clarity)
         - Any PARTIAL with `root_cause_category` ∈ {security_gap, arch_violation, missing_contract, spec_gap} (always — these are not eligible for the architect-only retry path)
         - PARTIAL with severity 4–6 and ambiguous root cause (multiple files, contradictory signals, or unclear failure mode)
         - Any examiner reports confidence < 0.7 on a non-YES verdict
         - Examiner results contradict each other
         - Spec interpretation conflict surfaced during implementation
         - Architecture seam dispute
         - Story has hit max remediation rounds (5)
       → SendMessage(Decider) with: story ID, verification.json summary, examiner results, remediation history, and a specific question.
       → When `non_interactive = true`, apply the ABORT:DEFERRED catch (see Non-Interactive Mode Detection block above) to the Decider's message before acting on it. If the message contains `ABORT:DEFERRED:`, parse `<reason>` (typically `escalated`) and `<detail>`, run the Stamp-write procedure with those parameters, then emit `ABORT:DEFERRED:<reason>:<detail>` on stdout and exit — do not also fall through to the ESCALATE branch.
       → Execute the Decider's response:
           RETRY    → spawn a fresh Agent(subagent_type: base:integration-architect) with the Decider's remediation prompt (apply the same non-interactive instruction injection and ABORT catch as bullet 2 above); re-run step 3. **If the current story is on the lighter path, apply the lighter-path remediation-fallback bookkeeping above (flip stories.json's `story.lighter_path` to `false`) before the architect spawn.**
           ESCALATE → mark the story escalated in stories.json and epic-state.json; surface to the user via AskUserQuestion.
           ACCEPT   → update result.json with the Decider's caveats; mark done.
           REJECT   → treat as a remediation round; re-run step 2 with the Decider's failure list. **If the current story is on the lighter path, apply the lighter-path remediation-fallback bookkeeping above (flip stories.json's `story.lighter_path` to `false`) so the re-run takes the full-path branch of bullet 2.**

     **Non-interactive abort.** When `non_interactive = true`, do NOT invoke `AskUserQuestion` for escalations. Run the Stamp-write procedure (see Non-Interactive Mode Detection block above) with `<reason> = escalated` and `<detail> = "story {story-id} — {reason-detail}"`, then output `ABORT:DEFERRED:escalated:story {story-id} — {reason-detail}` on stdout and exit. There is no dispatcher fallback; if the stamp Edit fails or no slug is in scope (direct invocation), the dispatcher surfaces a WARNING.

  5. **Optional retro probe** (per story, end-of-iteration). After bullet 4 has reached a terminal state for this story (FAST PATH pass, FAST PATH retry-then-pass, or post-Decider RETRY/ACCEPT/REJECT settled), read `{story_dir}/result.json.retrospective`.
       - **Lighter-path skip case.** If the story took the lighter-path
         branch in bullet 2 AND never fell back to a full-path architect
         spawn in bullet 4 (no architect ever ran for this story), skip
         the probe entirely. The `result.json.retrospective.skipped:
         true` write from step 2d is the canonical record; there is no
         architect agentId to probe and no architect retro to enrich.
         The probe is a no-op for these stories.
       - If `retrospective.skipped: true` AND `result.json.remediation_rounds > 0`, append a discrepancy note to `retro_bundle.discrepancies` (e.g. `"S{id} retro skipped despite N remediation rounds"`). Do NOT probe — that punishes skip-allowed.
       - Else if `retrospective.skipped: false` AND a field is unclear or incomplete in a way that would materially improve the meta-retro at Step 6, you MAY probe the architect via `SendMessage(to: <architect_agentId>, message: <one specific question>)`. Use the agentId you captured in bullet 2 above (or, on a lighter-path remediation fallback, the agentId captured during bullet 4's fallback spawn). This is agentId-based addressing — see "Conventions for spawning vs. messaging" — NOT role-name SendMessage. Cap: 3 follow-ups per architect.
       - Append each Q/A pair to `result.json.retrospective.lead_clarifications` as `[{question, answer}]`.
       - Skip the probe entirely when the retro is clear; that is the default.
       - The most recent architect spawn's agentId is the one to use. If a story went through multiple architect spawns (FAST PATH retry, Decider RETRY/REJECT), only the agentId of the spawn whose `result.json` is the final canonical record is reachable for this probe.

  6. After all stories are done or escalated:
       - The lead runs the full test suite directly. If failures, SendMessage(Decider) before declaring the epic done.
       - Check that all ACs from acceptance-criteria.md are covered by done stories.
       - Check mocks-registry.json: if unresolved mocks remain, create an additional story and re-enter the loop. Spawn `base:story-planner` in Mode 3 for the new story before re-entering the architect spawn at step 2.
       - Update epic-state.json: status="done", phase="COMPLETE".
```

### Spawn-vs-message invariants

- Every Agent tool call in this Step 5 originates from the lead (this session). No teammate or subagent spawns `base:integration-architect` or `base:verification-examiner` on the lead's behalf.
- No **role-name** SendMessage in this Step 5 targets `planner`, `architect`, or `verifier` — those teammates do not exist. Role-name SendMessage in this Step 5 targets only the `Decider` role.
- **agentId-based** SendMessage IS used in this Step 5 — exclusively in bullet 5 (the optional retro probe), to continue an architect by its agentId. This is a different addressing mode and does not require a TeamCreate teammate.

---

## Step 6: Wrap Up

1. Update `specs/epic-{name}/epic-state.json` with final status.

   **Then immediately update `BACKLOG.md ## Epics`** to match: locate the bullet whose path is `specs/epic-{name}/` and rewrite its status field (`IN_PROGRESS` → `DONE` or `ESCALATED`) and its trailing date. This step is **unconditional and lead-driven** — it does NOT go through the curator. The curator's `update_epics_section` action exists for *other* drift (an epic dir was deleted out-of-band, a parallel session created one, the bullet is missing entirely) and is subject to the curator's cap-5 proposal limit; closing the lifecycle of state this workflow itself created in Step 3 must not be best-effort. Skip silently if `BACKLOG.md` does not exist (consistent with Step 3's behavior).

2. **Synthesize the retrospective AND curate project-state proposals in parallel.** Both subagents read the same `retro_bundle` but cover disjoint domains: the synthesizer handles workflow friction; the curator handles project meta-state (`BACKLOG.md`, spec amendments, ADR candidates). Spawn both in a single message (one Agent call each):

   **2a. `base:retro-synthesizer`** — input bundle:
     - Paths to all `{story_dir}/result.json` files (architect retros, including absorbed pbt-dev/codex/ollama POV).
     - The lead's `retro_bundle` (in-session object): `spec_validation`, `exploration`, `planning`, `examiners`, `discrepancies`.
     - Paths to `stories.json`, `epic-state.json`, and per-story `verification.json` summaries (worst severity per story, examiner verdicts).
     - Project provenance JSON: `project_slug` (= `basename "$(git rev-parse --show-toplevel)"` lowercased and sanitized), `project_path`, `git_remote` (or `"none"`), `commit_at_start` (epic's earliest baseline commit), `commit_at_end` (current HEAD), `started_date`, `completed_date`, `stories_total`, `stories_done`, `stories_escalated`.

     The synthesizer returns either the literal string `STATUS: NO_RETRO` (strict floor: every subagent retro skipped AND zero remediations AND zero escalations AND zero discrepancies) or a markdown body. If `STATUS: NO_RETRO`, write nothing. Otherwise the lead writes the markdown body to:
     ```
     ${CLAUDE_PLUGIN_DATA}/retros/<project-slug>/<epic-name>-<YYYY-MM-DD>.md
     ```
     where `<epic-name>` is `epic_name` from `epic-state.json` and `<YYYY-MM-DD>` is the completion date. Create the directory tree if missing (`mkdir -p`). The synthesizer never touches the filesystem; only the lead writes the file.

   **2b. `base:project-curator`** — input bundle:
     - The lead's `retro_bundle` (same object the synthesizer gets — for factual signal about abandoned approaches, tightened tests, surprising failures).
     - Paths to all `{story_dir}/result.json` files (for `files_modified`, `files_created`, root-cause descriptions).
     - Paths to `specs/epic-{name}/spec.md` and `acceptance-criteria.md` (the curator may propose `amend_spec`).
     - Path to `BACKLOG.md` at the repo root if it exists (the curator skips `append_finding`/`append_rejection`/`update_epics_section` proposals when it does not — surface a one-time hint to the user that `/base:backlog init` would unlock those).
     - `docs/adr/` listing — `ls docs/adr/*.md 2>/dev/null` (titles only, not bodies).
     - Project provenance JSON (same fields as 2a).

     The curator returns a JSON object inside `---CURATOR_OUTPUT---` / `---END_CURATOR_OUTPUT---` markers (schema in `plugins/base/agents/project-curator.md`). If `decisions` is empty, skip step 3 entirely.

3. **Apply curator decisions.** Read the curator's `decisions` array from the `---CURATOR_OUTPUT---` block. Apply each decision directly in sequence — no AskUserQuestion, no user confirmation. The lead applies each action using the per-action rules below:

     - **`append_finding`** → append the formatted bullet to `BACKLOG.md ## Findings` (use the format documented in `plugins/base/skills/backlog/references/format.md`).
     - **`append_rejection`** → append the bullet to `BACKLOG.md ## Archive` in the canonical format `- YYYY-MM-DD — <text> — <rejection_reason>` (no `[rejected]` prefix; the section header conveys that). See `plugins/base/skills/backlog/references/format.md`.
     - **`amend_spec`** → apply the AC patch to `acceptance-criteria.md` AND append an entry to `spec.md ## Amendments` (create the section if it doesn't yet exist; see `base:spec-template`). Both edits are a single logical amendment.
     - **`resolve_finding_via_spec`** → apply the AC patch + append to `## Amendments` (same as `amend_spec`) AND remove the source bullet from `BACKLOG.md ## Findings` matched by `finding_slug` (exact position-1 slug match). The amendment entry must cite the resolved finding's text. All three edits are one transactional unit; if any fails, surface the failure rather than partially applying.
     - **`resolve_finding_mechanical`** → remove the source bullet from `BACKLOG.md ## Findings` matched by `finding_slug` (exact position-1 slug match). No spec change, no archive entry. The `evidence_commit` is for audit only — do not write it anywhere; git is the record.
     - **`move_finding_to_archive`** → remove the source bullet from `BACKLOG.md ## Findings` AND append a bullet to `## Archive` in the canonical format `- YYYY-MM-DD — <text> — <rejection_reason>` (no `[rejected]` prefix). One transactional unit.
     - **`promote_to_adr`** → invoke `Skill("base:adr", args: "<title> affects:<comma-separated-paths> proposed [supersedes:ADR-NNN]")` using the decision's `affects` list. The `proposed` flag causes the ADR to be scaffolded as `Status: Proposed`. The skill also appends a `## Constrained by ADRs` pointer to each affected spec automatically (see `base:adr` SKILL.md). The lead does NOT fill in ADR content — that's the user's job in a follow-up session.
     - **`promote_rejections_to_adr`** → invoke `Skill("base:adr", args: "<title> from-archive:<comma-joined-archive_markers>")` passing **all** of the curator's `archive_markers` (the skill matches each marker independently and embeds every matched archive entry verbatim under the new ADR's `## Context` so the cluster's full evidence is preserved). After the ADR is created, append `[→ ADR-NNN]` to each matched archive entry in `BACKLOG.md`.
     - **`update_epics_section`** → apply the diff to `BACKLOG.md ## Epics`.
     - **`annotate_retro`** → edit the retro file at `retro_path`, locate the `finding_anchor` text, and append `_Curator: YYYY-MM-DD → <disposition>_` on the line immediately following it. If the annotation is already present (idempotency guard: check for `_Curator:` suffix on a line near the anchor), skip silently.

4. Clean up the team.

5. Report to the user:
   - Stories completed vs escalated.
   - Test count (baseline → final).
   - Path to the retrospective file (if one was written), or note that the run was friction-free and no retro was emitted.
   - Curator summary: `<N> decisions applied` (omit the line entirely if the curator returned zero decisions).
   - Any issues that need attention.

---

## Epic State Transitions

```
planning → in_progress → done
                      → escalated (if stories can't be resolved)
```

## Story State Transitions (in stories.json)

```
pending → in_progress → done
                     → escalated (after 5 remediation rounds)
```

---

## Crash Recovery (mode = RESUME)

If resuming an epic:

0. **RECONCILE first.** Run Step 1.5 (RECONCILE phase) before any of the steps below. The cache check makes this free when nothing has moved since the last resume; when the cache misses, the four-state inspection + adjudication produces a spec consistent with the workspace before crash recovery proceeds.
1. Read `epic-state.json` for current phase and completed stories
2. Check that `specs/epic-{name}/architecture.md` exists. If missing, produce it following the "Produce Epic Architecture" step above before resuming any stories.
3. Read `stories.json` for per-story statuses
4. Check story directories for artifacts to determine exact resume point:
   - No `verification.json` → story needs pre-impl commitment set; re-spawn `base:story-planner` in Mode 3 for this story before any architect spawn
   - No `architecture.json` → story needs architecture contract (Step 1.5)
   - No `baseline.json` → story needs baseline
   - `baseline.json` but no `result.json` → story needs implementation
   - `result.json` with status="in_progress" → check verification_rounds for resume point
   - `result.json` with status="done" → story complete
5. Validate completed stories: each must have all 4 required artifacts (architecture.json, baseline.json, verification.json, result.json) with valid schemas. If violations found, present options to user: reset story, force continue, or abort.
6. Check for escalated stories — if any, STOP. Present escalation to user via AskUserQuestion. Do not proceed past escalated stories.
7. **Recreate the Decider teammate only** (single TeamCreate call with one role — the Decider role block from Step 4). Do NOT recreate Planner, Architect, or Verifier teammates — those roles no longer exist.
8. Resume the implementation loop in Step 5 from the first story with `status` ≠ `done` and ≠ `escalated`. Pass Decider context only when an escalation arises: which stories are done, which is current, remediation history if mid-round.
9. Continue through the remaining stories per the Step 5 loop.
10. **Retro bundle on resume.** `retro_bundle` is an in-session scratch object and is not persisted across resumes — non-architect retros (spec-validator, code-explorer, story-planner) that were captured before the crash are lost. Architect retros are preserved (they live in `result.json`, which is on disk). The Step 6 synthesizer composes the retro from whatever is available on resume; a partial retro is still better than no retro.

---

## Strict Artifact Requirements

Story directories MUST contain ONLY these files:
```
{story_id}-{story_name}/
├── verification.json  # Pre-impl commitment set — authored by story-planner Mode 3 BEFORE the architect runs; architect appends post-impl questions only
├── architecture.json  # Module contract — written by the architect before any stubs (Step 1.5)
├── baseline.json      # Test snapshot before implementation
└── result.json        # Implementation outcome, verification rounds
```

NO .md, .txt, .bak, .tmp, .log, or any other files. This enables crash recovery.

---

## Key Files

| File | Purpose |
|------|---------|
| `specs/epic-{name}/spec.md` | Feature specification (living; amended in `## Amendments`) |
| `specs/epic-{name}/epic-state.json` | Epic-level state machine (frozen post-completion) |
| `specs/epic-{name}/reconciliation.json` | RECONCILE cache — `(spec_sha, git_sha)` keyed AC verdicts; consumed on RESUME |
| `specs/epic-{name}/exploration.json` | Codebase exploration findings |
| `specs/epic-{name}/architecture.md` | Living epic architecture (paradigm, modules, seams, boundary rules) |
| `specs/epic-{name}/arch-debate.json` | Debate state for crash recovery (present when arch_debate: true) |
| `specs/epic-{name}/acceptance-criteria.md` | Testable ACs |
| `specs/epic-{name}/stories.json` | Story definitions (schema: `schemas/stories.schema.json`) |
| `specs/epic-{name}/mocks-registry.json` | Temporary mock tracking |
| `specs/epic-{name}/{id}-{name}/architecture.json` | Per-story module contract (written before stubs) |
| `specs/epic-{name}/{id}-{name}/baseline.json` | Pre-implementation test snapshot |
| `specs/epic-{name}/{id}-{name}/verification.json` | Verification questions + answers |
| `specs/epic-{name}/{id}-{name}/result.json` | Implementation outcome |
| `docs/adr/` | Architecture Decision Records (one per arch_debate run or major revision) |
| `skills/languages/{language}.md` | Project language conventions |
| `${CLAUDE_PLUGIN_DATA}/retros/{project-slug}/{epic-name}-{date}.md` | Cross-epic factory retrospective (plugin-scoped, written by Step 6, survives project deletion) |
| `BACKLOG.md` | Project-level backlog (Epics / Findings / Archive) — read by `/base:orient`, written by lead from `base:project-curator` proposals at Step 6 |
| `docs/adr/ADR-NNN-*.md` | Architecture Decision Records — created by `base:arch-debate` (debated) or `/base:adr` (lightweight). Cited by spec `## Constrained by ADRs` sections. |
| `plugins/base/schemas/result.schema.json` | Authoritative `result.json` schema (includes the `retrospective` field) |
