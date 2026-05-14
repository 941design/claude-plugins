# next auto backlog audit

## Problem

`/base:next auto` exit prose names only the one blocking finding. The rest of the backlog state — deferred bullets, plugin-bound bullets, what would dispatch on the next run, stale findings — is invisible at the moment the user is deciding what to do next, forcing them to re-read `BACKLOG.md` and infer the per-item remediation by hand.

This affects every non-dispatching exit: question halt, all-plugin-bound, post-`ABORT:UNDERSPECIFIED`, post-`ABORT:ALREADY-RESOLVED`, and the hint-mode plugin-bound short-circuit. In all of these the user has no structured view of what is stuck and why.

Source: BACKLOG.md finding promoted 2026-05-14.

## Solution

When `/base:next auto` reaches a non-dispatching exit, append a structured **Backlog status** audit block after the existing per-exit message. The audit lists every non-actionable finding grouped by classification (deferred-spec-gap, deferred-already-resolved, deferred-legacy-orphan, plugin-bound, blocked-question) with the specific unstuck command for each, plus a "would dispatch next" section showing the doc-order-next actionable candidate.

The audit is a pure renderer over the per-bullet classifications Step 3 already produces during the document-order walk. No new classifier pass; no new agent; no `AskUserQuestion`; no file writes.

The audit fires only on non-dispatching auto-mode exits — successful dispatches, missing-BACKLOG.md, empty-findings, and all detail-mode exits are unchanged.

## Scope

### In Scope

- Audit rendering on five non-dispatching exit paths in `plugins/base/commands/next.md`:
  1. Question halt (leading `question` in doc-order walk).
  2. All-plugin-bound exit (consumer cwd, no actionable candidates).
  3. Post-`ABORT:UNDERSPECIFIED` (Step 6a, worker-stamp and fallback-stamp paths alike).
  4. Post-`ABORT:ALREADY-RESOLVED` (Step 6a, same).
  5. Hint-mode plugin-bound short-circuit (Step 3 hint path).
- Per-classification unstuck-command rendering:
  - `[INSUFFICIENT: gap]` → edit anchored file then `/base:next "<hint>"`; or `/base:feature <spec-path>` (when anchor walks to `specs/epic-*/`); or `/base:backlog resolve <marker> rejected:<reason>`.
  - `[ALREADY-RESOLVED: evidence]` → `git diff -- <path>`; `git commit` then `/base:next "<hint>"`; or `/base:backlog resolve <marker> done-mechanical`.
  - Legacy `Auto-dispatch aborted:` orphans → `/base:backlog resolve <marker> rejected:legacy-orphan`.
  - Plugin-bound (consumer cwd) → `cd <plugin-source-repo>` and re-run; or `/base:backlog resolve <marker> rejected:not-our-project`.
  - Blocked question → the three existing `/base:backlog resolve <marker>` variants.
- A `### Would dispatch next` section naming the doc-order-position-1 actionable candidate (anchor, truncated text, `(kind, scale)` tuple, literal `Skill(...)` invocation).
- Per-category cap of 5 with `(+N more — see BACKLOG.md ## Findings)` overflow footer.
- Bullet-text truncation to ~80 chars with `…` (matching the existing `Dispatching as` notice line).

### Out of Scope

- Detail mode (no `auto` suffix). Detail's top-3 candidate rendering is untouched.
- Successful auto-dispatch exits.
- Missing-BACKLOG.md and empty-findings exits (existing one-line prose already names the action).
- The Step 3 classifier itself. The audit consumes its output; it does not reclassify.
- The `Skipped N plugin-bound finding(s)` end-of-walk tally line, which stays where it is (greppable; the audit's section is human-readable; the duplication is intentional).

## Design Decisions

1. **Append, do not replace.** The audit prints AFTER the existing per-exit message, separated by a blank line. The existing messages name the immediate blocker concisely; the audit gives broader context. Replacement loses the "this is what just happened" signal. Refs: `plugins/base/commands/next.md:270-280` (question-halt block), `:476-484` (all-plugin-bound block), `:914-941` (Step 6a abort templates).

2. **Reuse, do not reclassify.** Step 3's document-order walk already classifies every `## Findings` bullet into `deferred` / `plugin-bound` / `question` / `bug` / `feature-work` and tracks the actionable position-1 candidate; the audit composer is a pure function of that data. Refs: `plugins/base/commands/next.md:124-261`.

3. **Inline composer, no subagent.** The audit is rendered by a single inline subroutine in `next.md`, mirroring Step 4a's inline paragraph synthesis. Spawning an agent to render text the dispatcher already holds in scope would invert the cost. Refs: `plugins/base/commands/next.md:674-721`.

4. **Per-category cap of 5 with overflow footer.** Matches `/base:orient` Rule 5's oldest-stale cap and protects auto-mode output from pathological backlogs. Refs: `plugins/base/skills/orient/SKILL.md` Rule 5.

5. **~80-char truncation with `…`.** Matches the existing `<truncated-bullet>` rule in the `Dispatching as` notice line so audit text and dispatch notices read uniformly. Refs: `plugins/base/commands/next.md:516-518`.

6. **Legacy `Auto-dispatch aborted:` orphans get `rejected:legacy-orphan`.** The pre-stamp-grammar contract appended question-style findings on abort; the original abort cause is unrecoverable from the bullet text alone, so re-dispatch would regenerate the same stamp without fresh information. Closing via `rejected` is the only clean path. Refs: `plugins/base/commands/next.md:148-152`.

7. **`[ALREADY-RESOLVED]` items reuse the stamp's evidence verbatim.** The stamp captures the working-tree evidence at abort time (`M path/to/file` etc.); the audit quotes it so the user does not have to grep `git diff` themselves. Refs: `plugins/base/commands/next.md:380-388`.

8. **Hint-mode plugin-bound short-circuit gets the audit too.** Even though the user explicitly named a plugin-bound bullet, the audit's broader view (other deferred items, would-dispatch-next, etc.) is still useful — the user is in auto mode and won't see this state again until the next invocation. Refs: `plugins/base/commands/next.md:330-346`.

9. **Suppress audit on successful dispatch.** When the downstream Skill in Step 6 returns without an `ABORT:` line, the dispatcher's job is done; the downstream skill produces its own output and the audit would be noise.

## Technical Approach

### `plugins/base/commands/next.md`

Add one new subsection (`## Step 7a: Audit Block Renderer`) defining the inline composer, and edit the five non-dispatching exit paths to invoke it before exiting.

**Composer inputs (all already in scope at the call sites):**
- The full classified bullet list from Step 3's walk: `[{anchor, text, date, classification, scale?}]`.
- `plugin_bound_skipped` counter from Step 3.
- The position-1 actionable candidate (if any) from Step 3's selection.
- The reason for non-dispatch (one of: `question-halt`, `all-plugin-bound`, `abort-underspecified`, `abort-already-resolved`, `hint-plugin-bound`).

**Composer output:** a single multi-line markdown string beginning with `## Backlog status`. Print after the existing per-exit message with one blank line of separation.

**Worked example.** For a `BACKLOG.md` carrying one `[INSUFFICIENT]`-stamped finding, two `[ALREADY-RESOLVED]` stamps, one plugin-bound bullet (consumer cwd), and three actionable findings, after a successful auto-dispatch the audit MUST NOT print. After an `ABORT:UNDERSPECIFIED` on the first actionable finding the audit prints:

```
Auto-dispatch aborted.
Reason: spec gap — § Solution un-authored
Original finding stamped [INSUFFICIENT] in BACKLOG.md (deferred).
Address the gap (fill the referenced anchor) then re-dispatch via /base:next <hint> to un-stamp and retry, or close via /base:backlog resolve <marker>.

## Backlog status

### Deferred — spec gap (2)
- `specs/epic-foo/spec.md` — Is spec for epic-foo ready? …
  Gap: § Solution un-authored
  → Edit `specs/epic-foo/spec.md` `## Solution`, then `/base:next "epic-foo"` to un-stamp + re-dispatch.
  → OR `/base:feature specs/epic-foo/spec.md` for interactive validation.
  → OR `/base:backlog resolve specs/epic-foo rejected:<reason>` to close.
- `plugins/base/skills/adr/SKILL.md:65-69` — proposed+supersedes composability is undocumented …
  Gap: spec stub `## Solution` and acceptance-criteria.md un-authored
  → (same three options as above; spec path is `specs/epic-proposed-supersedes-composability/spec.md`)

### Deferred — fix may already be in working tree (1)
- `plugins/base/commands/bug.md` — /base:bug leaves working tree dirty after ACCEPTED …
  Evidence: M plugins/base/commands/bug.md
  → `git diff -- plugins/base/commands/bug.md` to review.
  → `git commit` then `/base:next "bug.md"` to un-stamp + retry.
  → OR `/base:backlog resolve plugins/base/commands/bug.md done-mechanical` to close.

### Plugin-bound — not dispatchable from this cwd (1)
- `plugins/base/skills/spec-template/SKILL.md:244` — AC-ID uniqueness rule disagrees with de facto convention …
  → `cd <claude-plugins-source>` and re-run /base:next.
  → OR `/base:backlog resolve plugins/base/skills/spec-template rejected:not-our-project`.

### Would dispatch next
- `plugins/base/agents/story-planner.md` — Mode-3 VQ literal-string grep lint is missing …
  (feature-work/full) → Skill("base:feature", args: "backlog:plugins/base/agents/story-planner.md auto")
```

Note: the worked example above is illustrative of shape and tonality; the exact bullet text, line counts, and formatting are bound only by the acceptance criteria.

### Call-site changes

- `plugins/base/commands/next.md:270-280` (question-halt) — after the existing block, invoke the composer with `reason = "question-halt"`.
- `plugins/base/commands/next.md:476-484` (all-plugin-bound) — after the existing block, invoke with `reason = "all-plugin-bound"`.
- `plugins/base/commands/next.md:914-941` (Step 6a abort templates) — after each template (`UNDERSPECIFIED` and `ALREADY-RESOLVED`), invoke with `reason = "abort-underspecified"` or `reason = "abort-already-resolved"`.
- `plugins/base/commands/next.md:330-346` (hint-mode plugin-bound short-circuit) — after the existing block, invoke with `reason = "hint-plugin-bound"`.

## Stories

- **S1 — audit-block renderer for non-dispatching exits** — adds `## Step 7a: Audit Block Renderer` to `plugins/base/commands/next.md` and wires it into the five non-dispatching exit paths. Single file change. Covers AC-PRES-*, AC-CONTENT-*, AC-NEXT-*, AC-CAP-*, AC-COMPAT-*, AC-INV-*.

(Single-story by design — the change is one file, one focused behavior, one renderer. A multi-story split would fragment the rendering rules from their call sites.)

## Acceptance Criteria

See [`acceptance-criteria.md`](./acceptance-criteria.md).

## Relationship to Other Epics

- **epic-base-next** — defines the full `/base:next` command including the Step 3 classifier this epic consumes; no changes to the classifier itself.
- **epic-next-modes** — introduced the detail/auto split; the audit fires in auto mode only, preserving the mode boundary.
- **epic-fast-track-routing** — introduced the (kind, scale) tuple the `### Would dispatch next` section renders; no changes to routing logic.

## Non-Goals

- A standalone spec-interrogation command (e.g. `/base:interrogate`, `/base:spec-validate`). Question clarification belongs inside `/base:feature` where project knowledge is built; splitting it off would let users clarify a spec without ever building the implementation context the clarification was supposed to seed.
- Changing the single-dispatch-per-invocation contract of auto mode. Auto still processes exactly one item; the audit is a post-exit summary, not a multi-dispatch loop.
- Changing detail-mode rendering. The audit is auto-only.
- Auto-resolving deferred findings on the user's behalf. The audit surfaces commands; the user runs them.
