---
name: feature
description: Implement features from specs or natural language using an agent team. ALWAYS use this for ALL feature work, including small tasks.
argument-hint: <@spec-file> OR <feature-description> OR <epic-directory>
allowed-tools: Task, Read, Write, Edit, Bash, AskUserQuestion, Skill
model: opus
---

# Feature Implementation — Agent Team Blueprint

You are the **team lead**. Your job is to create and coordinate an agent team that implements a feature from specification through verified, tested code.

## Conventions for spawning vs. messaging

Two distinct mechanisms exist; do not confuse them. **Agent creates a new instance; SendMessage finds an existing one by name.**

- **Spawning a fresh subagent** → use the **Agent tool** with an explicit `subagent_type` (e.g. `subagent_type: base:integration-architect`). This is the only way to launch agents named `base:*` such as `base:integration-architect`, `base:code-explorer`, `base:spec-validator`, `base:story-planner`, `base:pbt-dev`, `base:verification-examiner`. Always namespace-qualify with `base:`.
- **Messaging an existing teammate** → use **SendMessage** with the teammate's role name (e.g. `architect`, `verifier`, `planner`). SendMessage to a name that does not match a current teammate **routes successfully but silently no-ops** — work will stall with no error. There is no hook or runtime check that catches this; prevention is by getting the call right. Never use SendMessage to "spawn" a `base:*` subagent.

Whenever this document says "spawn an X subagent" it means: call the Agent tool with `subagent_type: base:X`.

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

For complex specs, use the Agent tool with `subagent_type: base:spec-validator` for thorough analysis.

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

Use the Agent tool with `subagent_type: base:code-explorer` to launch 2-3 explorers in parallel (one Agent call per focus, sent in a single message), with different focuses:
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

### Produce Epic Architecture (always-on)

After codebase exploration, before creating the team, produce `specs/epic-{name}/architecture.md`.

Check `specs/epic-{name}/spec.md` YAML frontmatter for `arch_debate: true`.

**If `arch_debate: true`:**
Invoke `Skill("base:arch-debate", args: "--epic {epic_name} --spec specs/epic-{name}/spec.md")`.
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

Create an agent team with these roles. Each teammate's role description tells them what they're responsible for and how to communicate.

### Team Composition

**Planner** (1 teammate)
> You are a story planner. Your job is to:
> 1. Read the spec at `specs/epic-{name}/spec.md` and exploration at `specs/epic-{name}/exploration.json`
> 2. **Read `specs/epic-{name}/architecture.md`** — story decomposition must respect the paradigm, module map, and boundary rules declared there. If architecture.md is absent, message the lead before proceeding.
> 3. Explore the codebase to understand existing patterns, architecture, and test conventions
> 4. Derive acceptance criteria — each must be specific, testable, and use state-change language (not intent language like "so that" or "enabling"). Name the exact function/field/component, the verb, and the resulting state.
> 5. Write `specs/epic-{name}/acceptance-criteria.md`
> 6. Split the feature into independent, vertically-sliced stories. Each story must: be testable in isolation, have at least one AC, include scope boundaries, declare `owning_module` (a module from architecture.md).
> 7. For cross-story dependencies: define the seam `contract` (type_name, fields, invariants) in stories.json before writing the stories that produce or consume it. Contract-first, then stories.
> 8. Write `specs/epic-{name}/stories.json` following the schema at `schemas/stories.schema.json`
> 9. Create story directories: `specs/epic-{name}/{id}-{story-name}/` for each story
> 10. You may use the Agent tool with `subagent_type: base:story-planner` for the detailed decomposition work.
> 11. Message the lead when done.
>
> Detect project language from config files and consult `skills/languages/{language}.md` for conventions.

**Architect** (1 teammate)
> You are the integration architect. **Read `specs/epic-{name}/architecture.md` before starting any story.** If architecture.md is absent, message the lead immediately — no story begins without it. Wait for the lead to message you with story assignments. Then for each assigned story, in order:
> 1. Establish a test baseline: detect the project's test command from `skills/languages/{language}.md`, run the full test suite, record results in `{story_dir}/baseline.json`. ZERO TOLERANCE for failures — if any test fails, message the lead immediately.
> 2. Design the component architecture for the story — interfaces, data flow, module boundaries
> 3. Use the Agent tool with `subagent_type: base:integration-architect` to delegate implementation. **Do not use SendMessage for this — that addresses an existing teammate, not a new subagent, and the message will silently no-op.** The Agent prompt must include the story spec, acceptance criteria, baseline, exploration context, and the path to `specs/epic-{name}/architecture.md`. The subagent handles TDD implementation, including its own Agent calls to `subagent_type: base:pbt-dev` for components; it must write `architecture.json` before any stubs (Step 1.5 in its protocol).
> 4. Verification questions are written in two phases by the `base:integration-architect` subagent and recorded in `{story_dir}/verification.json` with a `phase` field on each record:
>    - **Pre-impl** (before stubs/code, Step 2 of the subagent) — a commitment set with ≥1 question per category {QUALITY, ARCHITECTURE, TEST, SPEC, SECURITY} **plus one SPEC question per AC** the story covers (with `ac_id` set). Pre-impl questions are immutable once written.
>    - **Post-impl** (after pbt-dev work, Step 6 of the subagent) — append-only implementation-specific questions with `phase: "post-impl"`.
>    Ensure both phases are populated before notifying the verifier.
> 5. Ensure `{story_dir}/result.json` documents what was implemented, files created/modified, test counts
> 6. Validate: story directory contains ONLY baseline.json, verification.json, result.json (no .md, .txt, or extras). Delete any forbidden files.
> 7. Message the verifier that this story is ready for review
> 8. When the verifier reports issues, route them to a fresh `base:integration-architect` subagent (Agent tool, not SendMessage) for remediation. The subagent treats verifier findings the same way it treats original spec, including using the two-stage review (Ollama first, then Codex) as an in-flight tool. Once it judges the remediation done, re-notify the verifier. Max 5 remediation rounds per story.
>    - If stuck on a remediation issue after reasonable effort, the subagent uses `Skill("codex:rescue", args: "--wait <description of what's stuck>")` for an alternative implementation pass before exhausting rounds.
> 9. If max rounds exhausted, message the lead with escalation details.
> 10. After all assigned stories are verified, message the lead.
>
> Story directories MUST contain ONLY: baseline.json, verification.json, result.json.
> The `base:integration-architect` subagent uses a two-stage review (Ollama first, then Codex) as an in-flight tool during implementation (see the agent's Codex Integration section). It is not a handoff gate — handoff is gated on the architect's own judgment that the implementation is done.
> Detect project language and consult `skills/languages/{language}.md` for all commands.

**Verifier** (1 teammate)
> You verify implementation quality independently and skeptically. Core principle: GUILTY UNTIL PROVEN INNOCENT. For each story the architect sends you:
> 1. Read the story spec from stories.json and its acceptance criteria
> 2. Read `{story_dir}/verification.json` for the verification questions
> 3. Validate artifacts: `{story_dir}/` must contain ONLY architecture.json, baseline.json, verification.json, result.json. If forbidden files exist, message the architect to remove them before you proceed. If architecture.json is missing, message the architect — it is a required artifact written before stubs (Step 1.5) and its absence means the architecture gate was skipped.
> 4. **Pre-examination gate** — validate the commitment set is complete:
>    - ≥1 pre-impl question for each category in {QUALITY, ARCHITECTURE, TEST, SPEC, SECURITY}
>    - ≥1 pre-impl SPEC question with `ac_id` set, for every AC ID in the story's `acceptance_criteria` array (from stories.json)
>    
>    If gaps exist, message the architect with the specific missing categories and AC IDs. The architect backfills the missing pre-impl questions (this is a process concession — backfilled questions still carry `phase: "pre-impl"` but lose the genuine pre-implementation guarantee, since the implementation is already visible). Max 1 round on this gate; if it fails twice, escalate to lead — repeated commitment-set gaps mean Step 2 of `base:integration-architect` is being skipped.
> 5. Use the Agent tool with `subagent_type: base:verification-examiner` (one Agent call per question or batch of related questions, sent in parallel where possible) to investigate each question with evidence. AC-derived SPEC questions (those with `ac_id`) get the AC-coverage procedure described in `verification-examiner.md`.
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

If stories.json has **4+ stories**, request an additional architect teammate to work stories in parallel with the first architect (architect-1 takes odd stories, architect-2 takes even). The verifier handles both architects' outputs.

**Parallel gate (mandatory):** Before the second architect begins their first story, verify that every cross-story seam contract those stories will consume is defined with a typed `contract` in stories.json and reflected in `specs/epic-{name}/architecture.md`. No shared interface coordination through chat — seam contracts are written artifacts or work does not start. If any seam contract is missing, pause the second architect until the planner produces it.

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
2. Check that `specs/epic-{name}/architecture.md` exists. If missing, produce it following the "Produce Epic Architecture" step above before resuming any stories.
3. Read `stories.json` for per-story statuses
4. Check story directories for artifacts to determine exact resume point:
   - No `architecture.json` → story needs architecture contract (Step 1.5)
   - No `baseline.json` → story needs baseline
   - `baseline.json` but no `result.json` → story needs implementation
   - `result.json` with status="in_progress" → check verification_rounds for resume point
   - `result.json` with status="done" → story complete
5. Validate completed stories: each must have all 4 required artifacts (architecture.json, baseline.json, verification.json, result.json) with valid schemas. If violations found, present options to user: reset story, force continue, or abort.
6. Check for escalated stories — if any, STOP. Present escalation to user via AskUserQuestion. Do not proceed past escalated stories.
7. **Recreate the team** with the same three roles (Planner, Architect, Verifier)
8. Message teammates with context about where we left off:
   - If stories.json exists: tell planner "Planning is complete, skip to done"
   - Tell architect which stories are done and which is current/next; remind them architecture.md is at specs/epic-{name}/architecture.md
   - Tell verifier current verification state
9. Continue from the last incomplete story

---

## Strict Artifact Requirements

Story directories MUST contain ONLY these files:
```
{story_id}-{story_name}/
├── architecture.json  # Module contract — written before any stubs (Step 1.5)
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
