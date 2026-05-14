# next auto backlog audit — Acceptance Criteria

## Terminology

- **audit block** — the structured markdown section this epic adds, beginning with the literal heading `## Backlog status`, appended to `/base:next auto` output on non-dispatching exits.
- **non-dispatching exit** — one of five `/base:next auto` exit paths that complete without invoking a downstream Skill: question-halt, all-plugin-bound, post-`ABORT:UNDERSPECIFIED`, post-`ABORT:ALREADY-RESOLVED`, hint-mode plugin-bound short-circuit.
- **deferred** — a `## Findings` bullet whose `<text>` begins with `[INSUFFICIENT:` or `[ALREADY-RESOLVED:` or contains the legacy substring `Auto-dispatch aborted:`.
- **plugin-bound** — a `## Findings` bullet whose anchor begins with `plugins/base/`, classified only in consumer cwd (`is_plugin_dev_cwd == false`).
- **actionable** — a `## Findings` bullet classified `bug` or `feature-work` and not `deferred` or `plugin-bound`.
- **position-1 candidate** — the first actionable bullet in document order from `## Findings`, as identified by Step 3's walk.

## Audit Block Presence and Placement (S1)

**AC-PRES-1** — On every non-dispatching exit (question-halt, all-plugin-bound, post-`ABORT:UNDERSPECIFIED`, post-`ABORT:ALREADY-RESOLVED`, hint-mode plugin-bound short-circuit), the audit block MUST be printed AFTER the existing per-exit message, separated by exactly one blank line.

**AC-PRES-2** — On any successful auto-dispatch (the Step 6 Skill invocation returns without an `ABORT:` line on first output), the audit block MUST NOT be printed.

**AC-PRES-3** — When `BACKLOG.md` is missing or `## Findings` is empty or contains only the placeholder `- _no findings yet_`, the audit block MUST NOT be printed.

**AC-PRES-4** — The audit block MUST begin with the literal line `## Backlog status` (greppable via `grep -F "## Backlog status"`).

**AC-PRES-5** — Detail mode invocations (no trailing ` auto` token, including hint and no-hint variants) MUST NOT print the audit block.

**AC-PRES-6** — The existing per-exit message wording at every non-dispatching exit MUST be unchanged. The audit block is strictly additive.

## Audit Block Content — Deferred Items (S1)

**AC-CONTENT-1** — Each finding stamped `[INSUFFICIENT: <gap>]` MUST appear under a section headed `### Deferred — spec gap (<N>)` where `<N>` is the count of such findings. Each item MUST render:
- A bullet with the anchor and truncated bullet text.
- A `Gap: <gap>` line quoting the verbatim `<gap>` text extracted from the stamp.
- At least three `→` lines listing: (a) edit the anchored file and re-run `/base:next "<hint>"`; (b) `/base:feature <inferred-spec-path>` when the anchor walks to a `specs/epic-*/` directory, otherwise omit option (b); (c) `/base:backlog resolve <marker> rejected:<reason>` to close.

**AC-CONTENT-2** — Each finding stamped `[ALREADY-RESOLVED: <evidence>]` MUST appear under a section headed `### Deferred — fix may already be in working tree (<N>)`. Each item MUST render:
- A bullet with the anchor and truncated bullet text.
- An `Evidence: <evidence>` line quoting the verbatim `<evidence>` text from the stamp.
- Three `→` lines: (a) `git diff -- <anchor-path>` to review; (b) `git commit` then `/base:next "<hint>"` to un-stamp and retry; (c) `/base:backlog resolve <marker> done-mechanical` to close.

**AC-CONTENT-3** — Each finding whose text contains the substring `Auto-dispatch aborted:` and is NOT already stamped with `[INSUFFICIENT:` or `[ALREADY-RESOLVED:` MUST appear under a section headed `### Deferred — legacy orphan (<N>)`. Each item MUST render:
- A bullet with the anchor and truncated bullet text.
- One `→` line: `/base:backlog resolve <marker> rejected:legacy-orphan`.

**AC-CONTENT-4** — Each plugin-bound finding (consumer cwd only) MUST appear under a section headed `### Plugin-bound — not dispatchable from this cwd (<N>)`. Each item MUST render:
- A bullet with the anchor and truncated bullet text.
- Two `→` lines: (a) `cd <plugin-source-repo>` and re-run `/base:next`; (b) `/base:backlog resolve <marker> rejected:not-our-project`.

**AC-CONTENT-5** — On a question-halt exit, the leading question MUST appear under a section headed `### Blocked by open question`. The item MUST render the full bullet verbatim followed by three `→` lines naming the existing resolve variants: `/base:backlog resolve <marker> done-mechanical`, `/base:backlog resolve <marker> done→spec:<path>`, `/base:backlog resolve <marker> rejected:<reason>`.

**AC-CONTENT-6** — Bullet text in any audit item MUST be truncated to approximately 80 characters, appending `…` when the original exceeds that length. Bullet text ≤80 characters is rendered verbatim with no trailing `…`.

**AC-CONTENT-7** — Sections with zero items in a given category MUST be omitted entirely. The audit block MUST NOT contain empty `(0)` sections.

## Audit Block Content — Next Candidate (S1)

**AC-NEXT-1** — When Step 3's walk produced a position-1 actionable candidate, the audit MUST include a section headed `### Would dispatch next`. The section MUST contain one bullet with the anchor and truncated bullet text, followed by exactly one line of the form `(<kind>/<scale>) → Skill("<name>", args: "<args>")` naming the literal Skill invocation that the next `/base:next auto` would run.

**AC-NEXT-2** — When Step 3's walk produced no position-1 actionable candidate (every non-deferred bullet was plugin-bound, OR a leading question halted the walk), the `### Would dispatch next` section MUST be omitted.

## Caps and Tonality (S1)

**AC-CAP-1** — Each per-category section (`### Deferred — *`, `### Plugin-bound — *`) MUST list at most 5 items. When the category has more than 5 findings, the section MUST end with a footer line `(+<N> more — see BACKLOG.md ## Findings)` where `<N>` is the count of items beyond the first 5.

**AC-CAP-2** — Items within a section MUST appear in document order from `## Findings` (oldest first by file position). The audit MUST NOT reorder by age, severity, or any other heuristic.

**AC-CAP-3** — Each audit item MUST be rendered as a top-level bullet line (anchor + truncated text) followed by zero or more indented lines (`Gap:`, `Evidence:`, `→ …`), each indented by two spaces. No item spans more than one top-level bullet.

## Backward Compatibility (S1)

**AC-COMPAT-1** — The `Dispatching as <kind>/<scale>: …` notice line emitted on successful auto-dispatch MUST be unchanged in wording and placement.

**AC-COMPAT-2** — The end-of-walk tally line `Skipped <N> plugin-bound finding(s) — …` MUST be unchanged. Its content duplicates the audit's `### Plugin-bound — *` section count; the duplication is intentional (the tally is greppable, the audit is human-readable).

**AC-COMPAT-3** — All Step 3 classification logic (`deferred`, `plugin-bound`, `question`, `bug`, `feature-work`, scale axis, precedence ordering, hint-path scoring, deferred escape hatch, un-stamp transform) MUST be unchanged. The audit composer is a pure renderer over Step 3's outputs.

**AC-COMPAT-4** — All Step 6 routing logic (matrix, inferred spec path rule, mode-dependent args, Step 6a abort handling and stamp fallback) MUST be unchanged. The audit fires after Step 6a's templates, never replaces them.

**AC-COMPAT-5** — Detail-mode top-3 candidate rendering (Step 4 `IF mode == detail AND hint == None` and `IF mode == detail AND hint != None`) MUST be unchanged.

## Cross-Cutting Invariants

**AC-INV-1** — The audit composer MUST NOT invoke any subagent. Rendering is inline in the dispatcher, consistent with Step 4a paragraph synthesis and architecture.md Boundary Rule 2.

**AC-INV-2** — The audit composer MUST NOT invoke `AskUserQuestion`. Auto mode is non-interactive by contract.

**AC-INV-3** — The audit composer MUST NOT write to `BACKLOG.md` or any other file. The audit is print-only.

**AC-INV-4** — When `BACKLOG.md` contains zero deferred, zero plugin-bound, zero legacy-orphan, zero blocked-question findings AND a single actionable candidate that successfully dispatches, the audit MUST NOT print (the happy path has no signal worth surfacing).

## Manual Validation

- Run `/base:next auto` on a `BACKLOG.md` containing one `[INSUFFICIENT]`, one `[ALREADY-RESOLVED]`, one legacy `Auto-dispatch aborted:`, one plugin-bound (consumer cwd), and at least one actionable finding. Verify the audit lists all four classifications, the `### Would dispatch next` section names the actionable bullet, and the existing per-exit message is preserved above the audit.
- Run `/base:next auto` on a `BACKLOG.md` with only actionable findings. Verify successful dispatch occurs and no audit block prints.
- Run `/base:next` (detail mode) on the same backlog. Verify the existing top-3 rendering is unchanged and no audit block prints.
