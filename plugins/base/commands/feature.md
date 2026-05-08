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

For complex specs, use the Agent tool with `subagent_type: base:spec-validator` for thorough analysis. If its return contains a `RETROSPECTIVE:` block with `skipped: false`, capture it into `retro_bundle.spec_validation` (see "Retrospective collection (cross-cutting)" near the top of this file).

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

Merge results into `specs/epic-{name}/exploration.json`. For each explorer return that contains a `RETROSPECTIVE:` block with `skipped: false`, append it to `retro_bundle.exploration` (one entry per non-skipped flag, with the focus name preserved).

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

### Planning Phase

After creating the Decider, run the planning phase. The planner runs in
three modes; spawn it once per mode (fresh subagent each time).

1. Spawn `Agent(subagent_type: base:story-planner)` in **Mode 1** with: spec
   path, exploration.json path, architecture.md path. Output:
   `acceptance-criteria.md`. Wait for completion.
2. Spawn `Agent(subagent_type: base:story-planner)` in **Mode 2** with: spec
   path, acceptance-criteria.md path, architecture.md path. Output:
   `stories.json`. Wait for completion.
3. Read `stories.json` directly. Sanity check: all ACs covered,
   `story_order` defined, no duplicate story IDs.
   - If issues are minor and unambiguous (typos, missing scope boundary,
     missing AC reference): re-spawn Mode 2 with targeted corrections.
   - If issues require judgment (AC interpretation, story split
     disagreement, scope ambiguity): `SendMessage(Decider)` with the gap
     and the specific question. Apply the Decider's response before
     proceeding.
4. Spawn `Agent(subagent_type: base:story-planner)` in **Mode 3** with:
   stories.json path, acceptance-criteria.md path, architecture.md path.
   Output: one `{story_dir}/verification.json` per story containing the
   pre-impl commitment set. The planner creates the story directories.
   Wait for completion. Sanity check: every story listed in
   `stories.json` has a `verification.json` with at least 5 pre-impl
   records plus one SPEC record per AC in its `acceptance_criteria`.
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

  2. Spawn Agent(subagent_type: base:integration-architect) with:
       - the story spec (the relevant entry from stories.json)
       - acceptance criteria (acceptance-criteria.md, filtered to this story's ACs)
       - exploration.json (path)
       - architecture.md (path)
       - {story_dir}/verification.json (path) — pre-authored by the
         story-planner in Mode 3; pre-impl questions are immutable, the
         architect appends post-impl records only.
     Context MUST NOT include result.json or artifacts from prior stories — every story gets a fresh subagent with a clean context window. **Capture the architect's agentId** (returned by the Agent tool) and keep it for this story so Step 5 (the optional retro probe) can re-engage the same architect by agentId. Wait for the subagent to write {story_dir}/result.json.

     If {story_dir}/verification.json is missing for this story, the
     planner did not complete Mode 3 — re-spawn `base:story-planner` in
     Mode 3 for this story before spawning the architect.

  3. Read {story_dir}/verification.json.
     Spawn Agent(subagent_type: base:verification-examiner) for each verification question, or each batch of related questions. Independent batches MUST be sent in parallel — single message, multiple Agent tool calls. Each examiner returns YES, NO, or PARTIAL with severity and evidence.
     Collect all results. For each examiner return that contains a `RETROSPECTIVE:` block with `skipped: false`, append `{story_id, flag}` to `retro_bundle.examiners` (see "Retrospective collection (cross-cutting)" near the top of this file).

  4. Apply decision rules:

     FAST PATH — pass:
       All questions YES, or PARTIAL with severity < 4 AND confidence ≥ 0.7. All tests pass. No examiner reports a stub-scan hit or a missing-test downgrade. No `root_cause_category` of `security_gap`, `arch_violation`, or `missing_contract` on any PARTIAL.
       → Update {story_dir}/result.json: status=done, final_outcome=accepted, completed_at.
       → Update stories.json: this story's status → done.
       → Update epic-state.json: append story ID to completed_stories.
       → Continue to next story. (No Decider consult.)

     FAST PATH — first retry:
       One or more questions NO, or PARTIAL with severity 4–6. remediation_round = 0. Root cause is clear and unambiguous in the examiner output (single named file, single named defect) AND `root_cause_category` is one of {missing_test, impl_bug, dead_code, duplication, documentation}.
       → Spawn a fresh Agent(subagent_type: base:integration-architect) with the examiner findings as the remediation brief.
       → Re-run step 3 (spawn fresh examiners). If the result is now FAST PATH — pass, advance. Otherwise → ESCALATE.

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
       → Execute the Decider's response:
           RETRY    → spawn a fresh Agent(subagent_type: base:integration-architect) with the Decider's remediation prompt; re-run step 3.
           ESCALATE → mark the story escalated in stories.json and epic-state.json; surface to the user via AskUserQuestion.
           ACCEPT   → update result.json with the Decider's caveats; mark done.
           REJECT   → treat as a remediation round; re-run step 2 with the Decider's failure list.

  5. **Optional retro probe** (per story, end-of-iteration). After bullet 4 has reached a terminal state for this story (FAST PATH pass, FAST PATH retry-then-pass, or post-Decider RETRY/ACCEPT/REJECT settled), read `{story_dir}/result.json.retrospective`.
       - If `retrospective.skipped: true` AND `result.json.remediation_rounds > 0`, append a discrepancy note to `retro_bundle.discrepancies` (e.g. `"S{id} retro skipped despite N remediation rounds"`). Do NOT probe — that punishes skip-allowed.
       - Else if `retrospective.skipped: false` AND a field is unclear or incomplete in a way that would materially improve the meta-retro at Step 6, you MAY probe the architect via `SendMessage(to: <architect_agentId>, message: <one specific question>)`. Use the agentId you captured in bullet 2 above. This is agentId-based addressing — see "Conventions for spawning vs. messaging" — NOT role-name SendMessage. Cap: 3 follow-ups per architect.
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

2. **Synthesize and persist the retrospective.** This substep runs for every `/feature` invocation that reaches Step 6, regardless of story count (single-story, multi-story, or natural-language-derived):

   - Spawn `Agent(subagent_type: base:retro-synthesizer)` with the input bundle:
     - Paths to all `{story_dir}/result.json` files (architect retros, including absorbed pbt-dev/codex/ollama POV).
     - The lead's `retro_bundle` (in-session object): `spec_validation`, `exploration`, `planning`, `examiners`, `discrepancies`.
     - Paths to `stories.json`, `epic-state.json`, and per-story `verification.json` summaries (worst severity per story, examiner verdicts).
     - Project provenance JSON: `project_slug` (= `basename "$(git rev-parse --show-toplevel)"` lowercased and sanitized), `project_path`, `git_remote` (or `"none"`), `commit_at_start` (epic's earliest baseline commit), `commit_at_end` (current HEAD), `started_date`, `completed_date`, `stories_total`, `stories_done`, `stories_escalated`.
   - The synthesizer returns either the literal string `STATUS: NO_RETRO` (strict floor: every subagent retro skipped AND zero remediations AND zero escalations AND zero discrepancies) or a markdown body.
   - If `STATUS: NO_RETRO`, write nothing.
   - Otherwise the lead writes the markdown body to:
     ```
     ${CLAUDE_PLUGIN_DATA}/retros/<project-slug>/<epic-name>-<YYYY-MM-DD>.md
     ```
     where `<epic-name>` is `epic_name` from `epic-state.json` and `<YYYY-MM-DD>` is the completion date. Create the directory tree if missing (`mkdir -p`).
   - The synthesizer never touches the filesystem; only the lead writes the file.

3. Clean up the team.

4. Report to the user:
   - Stories completed vs escalated.
   - Test count (baseline → final).
   - Path to the retrospective file (if one was written), or note that the run was friction-free and no retro was emitted.
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
| `${CLAUDE_PLUGIN_DATA}/retros/{project-slug}/{epic-name}-{date}.md` | Cross-epic factory retrospective (plugin-scoped, written by Step 6, survives project deletion) |
| `plugins/base/schemas/result.schema.json` | Authoritative `result.json` schema (includes the `retrospective` field) |
