---
name: bug
description: Fix bugs through a systematic team workflow — reproduction, analysis, minimal fix, verification. ALWAYS use this for ALL bug fixes.
argument-hint: <@bug-report-file> OR <bug-description>
allowed-tools: Task, Read, Write, Edit, Bash, AskUserQuestion, Skill
model: opus
---

# Bug Fix — Agent Team Blueprint

You are the **team lead**. Your job is to coordinate a small team that fixes a bug surgically: minimal changes, root cause focus, regression-tested.

## Retrospective collection (cross-cutting)

This document uses a `retro_bundle` — an in-session scratch object you maintain throughout
the `/bug` run. Capture workflow-friction signals here:

- `retro_bundle.exploration` — array, one per `base:code-explorer` parallel run whose return contains a `RETROSPECTIVE:` block with `skipped: false`.
- `retro_bundle.examiners` — array of `{question_id, flag}` from `base:verification-examiner` returns whose `RETROSPECTIVE:` block has `skipped: false`.
- `retro_bundle.reviewer` — zero or one optional reviewer flag from the review verdict message.
- `retro_bundle.discrepancies` — array of lead-recorded notes when the workflow behaved oddly (for example: remediation happened but both fixer and reviewer retros skipped).

The fixer's retrospective lives in `bug-reports/{slug}-result.json#retrospective`, which is
the canonical doer record. Do not duplicate it into `retro_bundle`.

If a return omits the `RETROSPECTIVE:` block entirely, treat it as skipped. `retro_bundle`
is not written to disk; it is passed to `base:bug-retro-synthesizer` in Step 4.

## Input: $ARGUMENTS

### Non-Interactive Mode Detection

IF $ARGUMENTS ends with the literal token ` auto` (space + "auto", case-sensitive):
    non_interactive = true
    Strip the trailing ` auto` token from $ARGUMENTS before Step 1 processes it.
ELSE:
    non_interactive = false

When `non_interactive = true`, every `AskUserQuestion` call site in this document
has a paired abort branch — see Step 1 (no-argument gather, BACKLOG_PROMOTE slug
conflict and ambiguity) and Step 3 (ESCALATE). At each such site, instead of
invoking `AskUserQuestion`, output `ABORT:UNDERSPECIFIED: <reason>` on stdout and
exit. **Do not write to `BACKLOG.md`.**

The dispatcher (`/base:next` Step 6a) is the sole writer of the deferred-state
bookkeeping artifact: it catches the `ABORT:UNDERSPECIFIED` signal on return and
stamps the original finding it dispatched with `[INSUFFICIENT: <gap>]`. Earlier
versions of this contract had `/base:bug` also append a separate question finding
capturing the gap; that produced duplicate writes and orphan accumulation when
the original was later resolved. The append has been retired. Direct invocations
(no dispatcher in front) still emit the signal on stdout for the human watching.

**Propagation to subagents and teammates.** The `non_interactive` flag does not
stop at the lead. Subagents (`base:code-explorer`, `base:verification-examiner`)
and TeamCreate teammates (`Fixer`, `Reviewer`, `Decider`) each have their own
prompts and can independently invoke `AskUserQuestion` at their own decision
points. When `non_interactive = true`, every site that spawns one of those agents
or defines a teammate role MUST append the following instruction to the briefing:

> **Non-interactive mode:** You are operating without a human in the loop. Do NOT
> invoke `AskUserQuestion` under any circumstances. If you reach a decision point
> that requires human judgment to resolve — a design choice, an ambiguous spec, a
> conflict you cannot settle from available context — output the single line
> `ABORT:UNDERSPECIFIED: <concise description of what needs specifying>` as the
> first line of your response and stop immediately. Do not guess, do not default
> silently, do not proceed with incomplete information.

And after every Agent spawn return or teammate message receive, when
`non_interactive = true`, apply this catch:

```
IF the return/message contains the literal string "ABORT:UNDERSPECIFIED":
    Extract the gap text: everything after the first "ABORT:UNDERSPECIFIED:" on that line, trimmed.
    Output: "ABORT:UNDERSPECIFIED: {gap text}" on stdout and exit the current skill.
    Do NOT write to BACKLOG.md — the dispatcher stamps the original on return.
```

`{relevant_path}` references previously used by this catch (bug report path,
result.json path, etc.) are now obsolete: the lead no longer writes a finding,
so no anchor is needed. Subagents that are pure data processors with no
human-judgment decision points (`base:bug-retro-synthesizer`,
`base:project-curator`) are exempt from the instruction injection and the catch.

---

## Step 1: Understand the Bug

### Language Detection

Detect project language from config files (pyproject.toml, package.json, go.mod, Cargo.toml, pom.xml, build.gradle.kts) and consult `skills/languages/{language}.md` for build/test commands throughout.

### Gather Details

```
IF argument is a .md file path or starts with @:
    Read the bug report file
    Validate: has description, expected/actual behavior, reproduction steps, impact
    If gaps: use AskUserQuestion, update file
ELSE IF argument starts with "backlog:":
    mode = BACKLOG_PROMOTE (see ### BACKLOG_PROMOTE mode below)
ELSE:
    Gather details via AskUserQuestion:
    - What is the symptom?
    - Steps to reproduce?
    - Expected vs actual behavior?
    - Any error messages?
    Write bug report to bug-reports/{slug}-report.md

    When `non_interactive = true`, do NOT use `AskUserQuestion`. Output
    `ABORT:UNDERSPECIFIED: auto mode requires a backlog marker or bug report file
    path; cannot gather bug details interactively.` and exit.
```

### BACKLOG_PROMOTE mode

Argument form: `backlog:<finding-marker>` where `<finding-marker>` is a substring that
uniquely identifies one entry in `BACKLOG.md ## Findings`.

```
1. Read BACKLOG.md. If missing, abort with:
   "no BACKLOG.md — run /base:backlog init first."

2. Locate the matching finding bullet under ## Findings. If zero or >1 bullets contain
   the marker (case-sensitive substring match), abort with the candidates listed.

3. Read the matched finding's prose (anchor + text) and decide whether it
   describes a defect: something that fails, crashes, errors, regresses, or
   behaves incorrectly. The format no longer carries a type prefix — this
   classification is by reading, the same call `/base:next` makes when it
   dispatches. If the finding clearly describes feature work, a chore, or an
   observation rather than a defect, abort with:
   "marker matched a non-bug finding; use /base:feature backlog:<marker> instead."
   Do NOT process non-defect findings under the bug workflow. When the
   classification is genuinely ambiguous, proceed — the bug workflow's own
   reproduction step will surface the mismatch.

4. Derive a kebab-case slug from the finding's text (≤40 chars).
   Confirm via AskUserQuestion if ambiguous.
   **When `non_interactive = true`, skip `AskUserQuestion` and derive the slug
   deterministically from the first 8 words of the finding text, kebab-cased.**
   If bug-reports/{slug}-report.md already exists, confirm via AskUserQuestion with a
   numbered-suffix suggestion (e.g. {slug}-2) — do NOT silently overwrite.
   **When `non_interactive = true`, skip `AskUserQuestion` and automatically append
   `-2` (or the next available suffix) to the slug without confirmation.**

5. Write bug-reports/{slug}-report.md with:
   - The finding's text in the description section.
   - The finding's anchor (when non-"-") in the reproduction-steps section as a
     starting reference.
   - A "Source: BACKLOG.md finding promoted YYYY-MM-DD" line.

6. Capture in-session: pending_finding_removal = <marker>
   Do NOT remove the source bullet from BACKLOG.md yet.

7. Set the bug report path to bug-reports/{slug}-report.md and fall through to the
   normal flow (the "IF argument is a .md file path" branch reads it naturally).
```

The source bullet is removed from `BACKLOG.md ## Findings` only after
`bug-reports/{slug}-result.json` is written (see Step 4).

### Explore the Codebase

Use the Agent tool with `subagent_type: base:code-explorer` to launch 2 explorers in parallel (both Agent calls in a single message):
- **Agent 1**: Bug symptoms — error messages, affected components, recent changes
- **Agent 2**: Architecture — dependencies, integration points, similar past bugs

When `non_interactive = true`, append the non-interactive mode instruction (see Non-Interactive Mode Detection block above) to each explorer's prompt.

Read 5-10 key files to understand the affected area.

When `non_interactive = true`, apply the ABORT:UNDERSPECIFIED catch (see Non-Interactive Mode Detection block above) to each explorer return before merging. Use the bug report path (`bug-reports/{slug}-report.md`) as `{relevant_path}`.

For each explorer return that contains a `RETROSPECTIVE:` block with `skipped: false`,
append it to `retro_bundle.exploration`.

### Generate Verification Questions

Based on bug complexity, generate an **immutable verification set** for this run:
- **LOW** (single component, clear fix): 4-5 questions
- **MEDIUM** (multiple components, some ambiguity): 6-8 questions
- **HIGH** (cross-cutting, multiple root causes possible): 8-12 questions

The set must cover:
- reproduction fidelity
- root-cause correctness
- minimality and scope control
- regression safety
- architecture and security impact when relevant

Each question gets a stable ID and category (`TEST`, `SPEC`, `QUALITY`, `ARCHITECTURE`,
`SECURITY`). Once created, the fixer may answer them with evidence, but may not rewrite
them. The lead and reviewer use the same set for independent verification.

### Create State File

Write `bug-reports/{slug}-state.json`:
```json
{
  "bug_name": "{slug}",
  "bug_report_file": "bug-reports/{slug}-report.md",
  "created_at": "{timestamp}",
  "updated_at": "{timestamp}",
  "phase": "INITIALIZED",
  "complexity": "{low|medium|high}",
  "verification_questions": [...],
  "baseline": null,
  "fix": null,
  "review_rounds": [],
  "remediation_round": 0,
  "phase_history": [
    {"phase": "INITIALIZED", "timestamp": "{timestamp}", "trigger": "workflow_start"}
  ]
}
```

---

## Step 2: Create the Team

Create an agent team with three roles. The lead does the orchestration, examiner spawning,
artifact reads, and state updates. The teammates do the implementation, independent review,
and judgment calls.

**Fixer** (1 teammate)
> You fix bugs surgically: minimal changes, root cause focus, regression-tested. Your workflow:
> 1. Read the bug report the lead sends you.
> 2. Detect project language from config files, consult `skills/languages/{language}.md` for test commands.
> 3. Establish baseline: run the full test suite, record pass/fail counts.
> 4. Write a reproduction test that FAILS — demonstrates the bug exists.
> 5. Confirm the test fails for the right reason (not a syntax error or wrong assertion).
> 6. Analyze root cause — trace from symptom to cause, don't just fix symptoms.
> 7. Write fix contract to `bug-reports/{name}-contract.json`: scope of allowed changes, files to modify, constraints, and explicitly named non-goals.
> 8. Implement the minimal fix — change only what's necessary.
> 9. Verify locally: reproduction test now PASSES, full test suite has no regressions.
> 10. Answer the lead's immutable verification questions with evidence in `bug-reports/{name}-result.json`, but do not change the questions themselves.
> 11. If stuck during analysis or fix (3+ debug cycles on the same issue), delegate to Codex:
>     - Use `Skill("codex:rescue", args: "--wait <root cause hypothesis, what you've tried, error details>")` for a second implementation pass.
>     - If Codex resolves it, verify the fix passes all tests before proceeding.
> 12. `Skill("codex:review", args: "--wait --scope working-tree")` is available as an in-flight tool during fix work. Treat findings as input to your judgment, not as the acceptance gate.
> 13. Write `bug-reports/{name}-result.json` with: root cause description, fix description, files changed, tests added, baseline vs final test counts, verification-question answers, and:
>     ```json
>     "retrospective": {
>       "skipped": true|false,
>       "reason": "<required if skipped>",
>       "scope": "project_specific|meta",
>       "harder_than_needed": "<if not skipped, one concrete friction>",
>       "surprised_by": "<optional if not skipped>",
>       "absorbed_from": [],
>       "lead_clarifications": []
>     }
>     ```
> 14. Message the lead that the fix is ready. Do not self-accept. Do not message the reviewer directly unless the lead explicitly asks.
>
> Consult `skills/languages/{language}.md` for language-specific testing and debugging conventions.

When `non_interactive = true`, append the non-interactive mode instruction (see Non-Interactive Mode Detection block above) to the Fixer's role definition as a safeguard — step 1 (validate/read bug report with gaps) and the "If stuck" codex delegation do not use `AskUserQuestion` directly, but the propagation guarantees consistent behavior if the fixer reaches any decision point requiring human judgment.

**Reviewer** (1 teammate)
> You verify bug fixes independently and skeptically. When the lead messages you:
> 1. Read the bug report, `bug-reports/{name}-result.json`, and `bug-reports/{name}-contract.json`.
> 2. Check: does the fix address root cause or just symptoms?
> 3. Check: are changes minimal and scoped to the contract?
> 4. Re-run the full test suite yourself — confirm all tests pass. Detect test command from `skills/languages/{language}.md`.
> 5. Re-run or inspect the reproduction test — confirm it actually proves the reported bug and now passes for the right reason.
> 6. Review the lead's verification-question set and the examiner results. Treat the examiner outputs as independent evidence, not as a substitute for your own judgment.
> 7. Look for regressions or side effects in modified files.
> 8. If issues remain, return a structured verdict to the lead with ACCEPT / REJECT plus exact files, lines, and what must change. Do not message the fixer directly unless the lead explicitly asks.
> 9. Last-mile: Codex adversarial review — only when you would otherwise accept:
>    - Run `Skill("codex:adversarial-review", args: "--wait <focus on the bug fix approach, root cause analysis, and whether the fix is minimal and correct>")`
>    - `needs-attention` with any `critical` or `high` severity finding is blocking
>    - `low`/`medium` findings are reported but do not block acceptance
> 10. Include an optional retrospective flag in your verdict when the review workflow itself was harder than it needed to be:
>     ```
>     RETROSPECTIVE:
>       skipped: <true|false>
>       flag: "<if not skipped, one sentence>"
>       scope: "<project_specific|meta>"
>     ```
> 11. When satisfied, message the lead with `ACCEPTED`, verification summary, final test counts, and any non-blocking caveats.
> 12. If not fixable after repeated rounds, message the lead with `REJECTED` and the blocking reasons.

When `non_interactive = true`, append the non-interactive mode instruction (see Non-Interactive Mode Detection block above) to the Reviewer's role definition.

**Decider** (1 teammate, model: opus)
> You are the decision authority for this bug fix. You are consulted only when the lead escalates a non-trivial judgment call. Routine outcomes (pass, first retry on a clear implementation miss) are handled by the lead.
>
> When the lead messages you, it will provide: the bug report, fix contract, fixer result, examiner results, reviewer verdict, remediation history, and a specific question. Respond with one of:
>   RETRY — restate the remediation as a concrete prompt for the fixer. Include exact files, lines, and what must change.
>   ESCALATE — the bug cannot be resolved automatically. Provide the reason and what the user must decide.
>   ACCEPT — the outcome is acceptable despite partial findings. State any caveats to record in `bug-reports/{name}-result.json`.
>   REJECT — enumerate the specific failures that block acceptance.
>
> You do not spawn subagents. You do not manage state files. You do not write files.

When `non_interactive = true`, append the non-interactive mode instruction (see Non-Interactive Mode Detection block above) to the Decider's role definition. Additionally, because the Decider's `ESCALATE` response routes back to `AskUserQuestion` in the lead, append: "When `non_interactive = true`, if you would respond `ESCALATE`, respond `ABORT:UNDERSPECIFIED: <reason>` instead — the lead will catch this and emit `ABORT:UNDERSPECIFIED` on stdout (the dispatcher then stamps the original finding) rather than asking the user."

---

## Step 3: Coordinate the Workflow

As lead, you drive the bug-fix loop directly. There is no direct fixer-reviewer cycle unless
you explicitly choose one for a targeted clarification. You own examiner spawning, decision
rules, and state transitions.

### Implementation loop

```
1. Message the fixer with:
   - bug report details and affected files from exploration
   - the immutable verification-question set
   - fix constraints (if any from the user)

2. Wait for the fixer to write:
   - bug-reports/{slug}-contract.json
   - bug-reports/{slug}-result.json
   Update state file phase to FIX_READY.
   When `non_interactive = true`, apply the ABORT:UNDERSPECIFIED catch (see Non-Interactive Mode Detection block above) to the fixer's message before proceeding. Use `bug-reports/{slug}-result.json` as `{relevant_path}`.

3. Read bug-reports/{slug}-result.json.
   Spawn Agent(subagent_type: base:verification-examiner) for each verification question, or each batch of related questions. Independent batches MUST be sent in parallel — single message, multiple Agent tool calls. When `non_interactive = true`, include the non-interactive mode instruction (see Non-Interactive Mode Detection block above) in each examiner's spawn prompt.
   Collect all results. When `non_interactive = true`, apply the ABORT:UNDERSPECIFIED catch to each examiner return before tallying. Use `bug-reports/{slug}-result.json` as `{relevant_path}`. For each examiner return that contains a `RETROSPECTIVE:` block with `skipped: false`, append `{question_id, flag}` to `retro_bundle.examiners`.

4. Message the reviewer with:
   - bug report path
   - contract path
   - result path
   - examiner results
   - remediation history so far
   When `non_interactive = true`, apply the ABORT:UNDERSPECIFIED catch (see Non-Interactive Mode Detection block above) to the reviewer's verdict message before acting on it. Use `bug-reports/{slug}-result.json` as `{relevant_path}`.
   If the reviewer returns a `RETROSPECTIVE:` block with `skipped: false`, store it in `retro_bundle.reviewer`.

5. Apply decision rules:

   FAST PATH — pass:
     Reviewer returns ACCEPTED.
     All verification questions are YES, or PARTIAL with severity < 4 AND confidence ≥ 0.7.
     The fixer and reviewer both report the full suite passing.
     The reproduction test demonstrably failed before the fix and passes after the fix.
     No examiner reports a stub-scan hit or a missing-test downgrade.
     No examiner reports `root_cause_category` in {security_gap, arch_violation, missing_contract, spec_gap}.
     → Run the full test suite yourself as final confirmation.
     → Update state file phase to ACCEPTED.
     → Proceed to Step 4.

   FAST PATH — first retry:
     Reviewer returns REJECTED, OR one or more examiner answers are NO/PARTIAL with severity 4-6.
     remediation_round = 0.
     Root cause is clear and unambiguous in the combined reviewer/examiner output
     (single named file, single named defect) AND the root-cause category is one of
     {missing_test, impl_bug, dead_code, duplication, documentation}.
     → Increment remediation_round.
     → Update state file phase to REMEDIATING.
     → Message the fixer with the remediation brief.
     → Re-run steps 2-4.
     → If the result is now FAST PATH — pass, advance. Otherwise → ESCALATE.

   ESCALATE:
     Triggered by any of:
       - remediation_round ≥ 1 and still failing
       - any PARTIAL with severity ≥ 7
       - any PARTIAL with `root_cause_category` ∈ {security_gap, arch_violation, missing_contract, spec_gap}
       - severity 4-6 findings with ambiguous root cause
       - any examiner confidence < 0.7 on a non-YES verdict
       - examiner results contradict each other
       - reviewer and examiner evidence materially disagree
       - bug fix has hit max remediation rounds (3)
     → SendMessage(Decider) with: bug name, bug report summary, fix contract, fixer result, examiner results, reviewer verdict, remediation history, and a specific question.
     → When `non_interactive = true`, apply the ABORT:UNDERSPECIFIED catch (see Non-Interactive Mode Detection block above) to the Decider's message before acting on it. If the message contains `ABORT:UNDERSPECIFIED`, the lead emits `ABORT:UNDERSPECIFIED: <gap>` on stdout and exits — the dispatcher stamps the original finding on return; do not also fall through to the ESCALATE branch.
     → Execute the Decider's response:
         RETRY    → increment remediation_round; update state file phase to REMEDIATING; message the fixer with the Decider's remediation prompt; re-run steps 2-4.
         ESCALATE → update state file as escalated; surface to the user via AskUserQuestion.
         ACCEPT   → record the caveats in bug-reports/{slug}-result.json; proceed to Step 4.
         REJECT   → treat as a remediation round; message the fixer with the Decider's failure list; re-run steps 2-4.

   **Non-interactive abort.** When `non_interactive = true`, do NOT invoke `AskUserQuestion` and do NOT write to `BACKLOG.md`. Output `ABORT:UNDERSPECIFIED: bug fix for {slug} escalated — {reason}` on stdout and exit. The dispatcher (`/base:next`) stamps the original finding with `[INSUFFICIENT]` on return.

6. Retrospective discrepancy check:
   - If bug-reports/{slug}-result.json has `retrospective.skipped: true` AND remediation_round > 0, append a discrepancy note to `retro_bundle.discrepancies`.
   - If the reviewer omitted a RETROSPECTIVE block despite non-trivial remediation or contradictory evidence, append a discrepancy note.
```

---

## Step 4: Wrap Up

1. Update `bug-reports/{slug}-state.json` with final phase, outcome, remediation history, and final test counts.

   **Consume `pending_finding_removal` (BACKLOG_PROMOTE mode only).** After the state
   file write succeeds and only if `pending_finding_removal` is set, perform a single
   read-modify-write on `BACKLOG.md`: read the file, remove the source bullet from
   `## Findings` whose text contains the marker (case-sensitive), write back. Skip
   silently if `BACKLOG.md` does not exist. If this bug run aborted before reaching
   Step 4, the source bullet remains intact — the half-scaffolded
   `bug-reports/{slug}-report.md` is left for `/base:orient` to surface as drift.

2. **Synthesize the retrospective AND curate project-state proposals in parallel.** Spawn both in a single message (one Agent call each):

   **2a. `base:bug-retro-synthesizer`** — input bundle:
   - bug report path
   - contract path
   - result path
   - state file path
   - examiner results
   - `retro_bundle` (`exploration`, `examiners`, `reviewer`, `discrepancies`)
   - project provenance JSON: `project_slug`, `project_path`, `git_remote` (or `"none"`), `commit_at_start`, `commit_at_end`, `started_date`, `completed_date`, `remediation_rounds`

   The synthesizer returns either the literal string `STATUS: NO_RETRO` (strict floor: fixer retro skipped, reviewer retro skipped or absent, all explorer/examiner retros skipped or absent, zero remediation rounds, zero discrepancies, zero escalation) or a markdown body. If `STATUS: NO_RETRO`, write nothing. Otherwise write the body to:
   ```
   ${CLAUDE_PLUGIN_DATA}/retros/<project-slug>/<bug-name>-<YYYY-MM-DD>.md
   ```
   where `<bug-name>` is `bug_name` from the state file and `<YYYY-MM-DD>` is the completion date. Create the directory tree if missing (`mkdir -p`). This is the same retro home `base:feature` writes to — bug and feature retros co-locate per project so cross-run pattern learning sees both. The synthesizer never touches the filesystem; only the lead writes the file.

   **2b. `base:project-curator`** — input bundle:
   - the bug report path and `bug-reports/{slug}-result.json`
   - path to `BACKLOG.md` at the repo root if it exists
   - `docs/adr/` listing — `ls docs/adr/*.md 2>/dev/null` (titles only)
   - project provenance JSON: `project_slug`, `project_path`, `commit_at_start`, `commit_at_end`

   The curator returns a JSON object inside `---CURATOR_OUTPUT---` / `---END_CURATOR_OUTPUT---` markers. If `decisions` is empty, continue. Otherwise apply each decision directly — see `base:feature` Step 6.3 for the per-action application rules.

3. Report to the user:
   - root cause explanation
   - what was changed (files, lines)
   - tests added (reproduction test + any others)
   - baseline → final test counts
   - path to the retrospective file (if one was written), or note that the run was friction-free and no retro was emitted
   - curator summary: `<N> decisions applied` (omit if zero)

---

## Crash Recovery

If a bug-state.json exists for this bug:
1. Read it to determine current phase and remediation round.
2. Recreate the team.
3. Validate that `bug-reports/{slug}-contract.json` and `bug-reports/{slug}-result.json` exist before resuming review or adjudication.
4. Continue from the mapped resume point below.

Phase → Resume Point:
| Phase | Resume |
|-------|--------|
| INITIALIZED | Step 2 (create team, start fixer) |
| FIX_READY | Step 3.3 (spawn examiners) |
| REVIEWING | Step 3.4 (message reviewer) |
| REMEDIATING | Step 3.1 (message fixer with remediation brief) |
| ACCEPTED | Step 4 (wrap up) |
| ESCALATED | Report to user |
