---
name: feature
description: Implement features from specs or natural language using an agent team. ALWAYS use this for ALL feature work, including small tasks.
argument-hint: <@spec-file> OR <feature-description> OR <epic-directory>
allowed-tools: Task, Read, Write, Edit, Bash, AskUserQuestion, Skill
model: opus
---

# Feature Implementation — Agent Team Blueprint

You are the **team lead**. Your job is to create and coordinate an agent team that implements a feature from specification through verified, tested code.

## Input: $ARGUMENTS

---

## Step 1: Determine What We're Working With

```
IF argument starts with "specs/epic-":
    mode = RESUME (read epic-state.json, pick up where we left off)
ELSE IF argument is a .md file path or starts with @:
    mode = NEW (validate spec, plan stories, then implement)
ELSE IF no argument:
    mode = SCAN (look for in-progress epics in specs/epic-*/)
ELSE:
    mode = NATURAL_LANGUAGE (gather requirements, generate spec, then NEW)
```

If SCAN finds in-progress epics, ask the user which to resume or whether to start fresh.

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

If gaps exist, use AskUserQuestion to get clarifications. Update the spec. Max 3 rounds — if still unclear, stop and explain what's missing.

For complex specs, spawn a `spec-validator` subagent for thorough analysis.

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
epic_name=$(grep -m1 "^# " "$spec_file" | sed 's/^# //' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
mkdir -p "specs/epic-${epic_name}"
cp "$spec_file" "specs/epic-${epic_name}/spec.md"
```

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

### Codebase Exploration

Spawn 2-3 `code-explorer` subagents in parallel with different focuses:
- **similar-features**: Existing features resembling this one
- **architecture**: Module boundaries, abstraction layers, data flow
- **testing-and-conventions**: Test framework, conventions, E2E infrastructure

Merge results into `specs/epic-{name}/exploration.json`.

### Initialize Mocks Registry

```json
{
  "created_at": "{timestamp}",
  "updated_at": "{timestamp}",
  "mocks": [],
  "all_resolved": true
}
```

---

## Step 4: Create the Team

Create an agent team with these roles. Each teammate's role description tells them what they're responsible for and how to communicate.

### Team Composition

**Planner** (1 teammate)
> You are a story planner. Your job is to:
> 1. Read the spec at `specs/epic-{name}/spec.md` and exploration at `specs/epic-{name}/exploration.json`
> 2. Explore the codebase to understand existing patterns, architecture, and test conventions
> 3. Derive acceptance criteria — each must be specific, testable, and use state-change language (not intent language like "so that" or "enabling"). Name the exact function/field/component, the verb, and the resulting state.
> 4. Write `specs/epic-{name}/acceptance-criteria.md`
> 5. Split the feature into independent, vertically-sliced stories. Each story must be testable in isolation, have at least one AC, and include scope boundaries.
> 6. Write `specs/epic-{name}/stories.json` following the schema at `schemas/stories.schema.json`
> 7. Create story directories: `specs/epic-{name}/{id}-{story-name}/` for each story
> 8. You may spawn a `story-planner` subagent for the detailed decomposition work.
> 9. Message the lead when done.
>
> Detect project language from config files and consult `skills/languages/{language}.md` for conventions.

**Architect** (1 teammate)
> You are the integration architect. Wait for the lead to message you with story assignments. Then for each assigned story, in order:
> 1. Establish a test baseline: detect the project's test command from `skills/languages/{language}.md`, run the full test suite, record results in `{story_dir}/baseline.json`. ZERO TOLERANCE for failures — if any test fails, message the lead immediately.
> 2. Design the component architecture for the story — interfaces, data flow, module boundaries
> 3. Spawn an `integration-architect` subagent with the story spec, acceptance criteria, baseline, and exploration context. The subagent handles TDD implementation including spawning `pbt-dev` for components.
> 4. Verification questions are written in two phases by the `integration-architect` subagent and recorded in `{story_dir}/verification.json` with a `phase` field on each record:
>    - **Pre-impl** (before stubs/code, Step 2 of the subagent) — a commitment set with ≥1 question per category {QUALITY, ARCHITECTURE, TEST, SPEC, SECURITY} **plus one SPEC question per AC** the story covers (with `ac_id` set). Pre-impl questions are immutable once written.
>    - **Post-impl** (after pbt-dev work, Step 6 of the subagent) — append-only implementation-specific questions with `phase: "post-impl"`.
>    Ensure both phases are populated before notifying the verifier.
> 5. Ensure `{story_dir}/result.json` documents what was implemented, files created/modified, test counts
> 6. Validate: story directory contains ONLY baseline.json, verification.json, result.json (no .md, .txt, or extras). Delete any forbidden files.
> 7. Message the verifier that this story is ready for review
> 8. When the verifier reports issues, route them to the `integration-architect` subagent for remediation. The subagent treats verifier findings the same way it treats original spec, including using the two-stage review (Ollama first, then Codex) as an in-flight tool. Once it judges the remediation done, re-notify the verifier. Max 5 remediation rounds per story.
>    - If stuck on a remediation issue after reasonable effort, the subagent uses `Skill("codex:rescue", args: "--wait <description of what's stuck>")` for an alternative implementation pass before exhausting rounds.
> 9. If max rounds exhausted, message the lead with escalation details.
> 10. After all assigned stories are verified, message the lead.
>
> Story directories MUST contain ONLY: baseline.json, verification.json, result.json.
> The `integration-architect` subagent uses a two-stage review (Ollama first, then Codex) as an in-flight tool during implementation (see the agent's Codex Integration section). It is not a handoff gate — handoff is gated on the architect's own judgment that the implementation is done.
> Detect project language and consult `skills/languages/{language}.md` for all commands.

**Verifier** (1 teammate)
> You verify implementation quality independently and skeptically. Core principle: GUILTY UNTIL PROVEN INNOCENT. For each story the architect sends you:
> 1. Read the story spec from stories.json and its acceptance criteria
> 2. Read `{story_dir}/verification.json` for the verification questions
> 3. Validate artifacts: `{story_dir}/` must contain ONLY baseline.json, verification.json, result.json. If forbidden files exist, message the architect to remove them before you proceed.
> 4. **Pre-examination gate** — validate the commitment set is complete:
>    - ≥1 pre-impl question for each category in {QUALITY, ARCHITECTURE, TEST, SPEC, SECURITY}
>    - ≥1 pre-impl SPEC question with `ac_id` set, for every AC ID in the story's `acceptance_criteria` array (from stories.json)
>    
>    If gaps exist, message the architect with the specific missing categories and AC IDs. The architect backfills the missing pre-impl questions (this is a process concession — backfilled questions still carry `phase: "pre-impl"` but lose the genuine pre-implementation guarantee, since the implementation is already visible). Max 1 round on this gate; if it fails twice, escalate to lead — repeated commitment-set gaps mean Step 2 of `integration-architect` is being skipped.
> 5. Spawn `verification-examiner` subagents (one per question or batch of related questions) to investigate each question with evidence. AC-derived SPEC questions (those with `ac_id`) get the AC-coverage procedure described in `verification-examiner.md`.
> 6. Collect results. For each question, determine: YES (passes), NO (fails), or PARTIAL
> 7. **Re-run the full test suite yourself** — never trust claimed results. Detect the test command from `skills/languages/{language}.md`.
> 8. If any question is NO or PARTIAL with severity >= 7, or any test fails:
>    - Message the architect with specific files, issues, and root cause categories
>    - Wait for the architect to fix and re-message you
>    - Re-verify using the SAME questions (max 5 rounds per story)
> 9. **Last-mile adversarial review** — only when bullet 8's failure condition is NOT triggered (all VQs pass, all tests pass, AC coverage verified, no remaining objections — i.e., you would otherwise accept), run the two-stage adversarial check at the moment of declared completion. See **Last-mile: Two-stage adversarial review** below for invocation details. If either stage returns blocking findings, treat them as a remediation cycle (back to step 8 with the findings as the failure); if not, proceed to step 10.
> 10. When all questions pass, all tests pass, and the last-mile review is not blocking:
>    - Update `{story_dir}/result.json`: set status="done", add verification_rounds, set final_outcome="accepted", set completed_at
>    - Update `specs/epic-{name}/stories.json`: set this story's status to "done"
>    - Message the lead that the story is verified
> 11. If max rounds exhausted, message the lead with escalation details and remaining failures.
>
> **Last-mile: Two-stage adversarial review**
> Run only when you have reached a tentative *I would accept* verdict — all VQs pass (YES, or PARTIAL with severity < 7), all tests pass, AC coverage is verified, and you have no remaining objections. This is the final external check at the moment of declared completion; it is not a phase that runs in parallel with examination.
>
> **Stage 1 — Ollama adversarial review (runs first):**
> - Invoke `Skill("ollama:adversarial-review", args: "--wait <focus>")` where `<focus>` summarizes the story's acceptance criteria and the key design choices the architect made.
> - If it returns any `critical` or `high` severity findings you judge as accurate → blocking: send findings to architect as a remediation cycle (counts against the 5-round budget); do NOT proceed to Stage 2.
> - If it returns no blocking findings, or all findings are rejected as inaccurate → proceed to Stage 2.
>
> **Stage 2 — Codex adversarial review (runs only after Stage 1 clears):**
> - Invoke `Skill("codex:adversarial-review", args: "--wait <focus>")` with the same `<focus>` text.
> - The review returns a `verdict` (`approve` | `needs-attention`) and `findings` (each with severity, file, lines, confidence, recommendation).
> - `needs-attention` with any `critical` or `high` severity finding is blocking — send those findings back to the architect for remediation alongside any other failures (counts as a remediation round against the 5-round budget).
> - `low`/`medium` findings from either stage: report to the architect but do not block story completion.
> - Do NOT auto-apply fixes — both reviews are read-only. All remediation goes through the architect.
>
> **Optional quality gates** (use if project supports them):
> - If the project has Playwright + Docker Compose configured, include E2E tests in your test gate.
>
> Detect project language and consult `skills/languages/{language}.md` for test commands and tools.

### When to Scale Up

If stories.json has **4+ stories**, request an additional architect teammate to work stories in parallel with the first architect (architect-1 takes odd stories, architect-2 takes even). Both coordinate via messaging about shared interfaces. The verifier handles both architects' outputs.

---

## Step 5: Coordinate the Workflow

As lead, your coordination responsibilities:

1. **After creating the team**, message the planner to begin
2. **When planner finishes** (planner messages you), review stories.json yourself:
   - Sanity check: all ACs covered, stories make sense, story_order defined
   - If issues: message planner with feedback
   - If good: message architect(s) to begin, providing story assignments
3. **Monitor progress** — the architect and verifier communicate directly for story-level remediation cycles. You observe but don't relay.
4. **Handle escalations** — if the verifier or architect message you about unresolvable issues:
   - Investigate: read the story artifacts, check test output
   - Provide guidance and tell them to retry, OR
   - Use AskUserQuestion to get user input, OR
   - Mark the story as escalated in epic-state.json and stories.json
5. **After each story verified** (verifier messages you):
   - Update `epic-state.json`: add story ID to `completed_stories`, update `updated_at`
   - If more stories remain: architect continues to next (they manage their own sequencing)
6. **When all stories are verified**, do final checks:
   - Run the full test suite yourself — all tests must pass
   - Check that all ACs from acceptance-criteria.md are covered by done stories
   - Verify no temporary mocks remain unresolved (check mocks-registry.json)
   - If unresolved mocks: create an additional story to resolve them, message architect
   - Update epic-state.json: status="done", phase="COMPLETE"

---

## Step 6: Wrap Up

1. Update `specs/epic-{name}/epic-state.json` with final status
2. Clean up the team
3. Report to the user:
   - Stories completed vs escalated
   - Test count (baseline → final)
   - Any issues that need attention

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

1. Read `epic-state.json` for current phase and completed stories
2. Read `stories.json` for per-story statuses
3. Check story directories for artifacts to determine exact resume point:
   - No `baseline.json` → story needs baseline
   - `baseline.json` but no `result.json` → story needs implementation
   - `result.json` with status="in_progress" → check verification_rounds for resume point
   - `result.json` with status="done" → story complete
4. Validate completed stories: each must have all 3 required artifacts (baseline.json, verification.json, result.json) with valid schemas. If violations found, present options to user: reset story, force continue, or abort.
5. Check for escalated stories — if any, STOP. Present escalation to user via AskUserQuestion. Do not proceed past escalated stories.
6. **Recreate the team** with the same three roles (Planner, Architect, Verifier)
7. Message teammates with context about where we left off:
   - If stories.json exists: tell planner "Planning is complete, skip to done"
   - Tell architect which stories are done and which is current/next
   - Tell verifier current verification state
8. Continue from the last incomplete story

---

## Strict Artifact Requirements

Story directories MUST contain ONLY these files:
```
{story_id}-{story_name}/
├── baseline.json      # Test snapshot before implementation
├── verification.json  # 5+ verification questions + answers
└── result.json        # Implementation outcome, verification rounds
```

NO .md, .txt, .bak, .tmp, .log, or any other files. This enables crash recovery.

---

## Key Files

| File | Purpose |
|------|---------|
| `specs/epic-{name}/spec.md` | Feature specification |
| `specs/epic-{name}/epic-state.json` | Epic-level state machine |
| `specs/epic-{name}/exploration.json` | Codebase exploration findings |
| `specs/epic-{name}/acceptance-criteria.md` | Testable ACs |
| `specs/epic-{name}/stories.json` | Story definitions (schema: `schemas/stories.schema.json`) |
| `specs/epic-{name}/mocks-registry.json` | Temporary mock tracking |
| `specs/epic-{name}/{id}-{name}/baseline.json` | Pre-implementation test snapshot |
| `specs/epic-{name}/{id}-{name}/verification.json` | Verification questions + answers |
| `specs/epic-{name}/{id}-{name}/result.json` | Implementation outcome |
| `skills/languages/{language}.md` | Project language conventions |
