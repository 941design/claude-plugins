# Lean Lead + Decider: Cost-Efficient Feature Workflow

## Problem

The `base:feature` skill creates a persistent three-teammate team (Planner,
Architect, Verifier) per epic and routes all stories through them via
`SendMessage`. Context accumulates in the Architect and Verifier teammates
across every story they process: by story N, both teammates have seen N
complete story cycles. The team lead runs on Opus (`model: opus`) with the
same unbounded growth. For epics with 5+ stories, per-epic cost grows
super-linearly.

Two compounding issues confirmed in production retrospectives:

1. **Broken delegation graph** — Teammates do not have the Agent tool exposed
   (only the top-level lead does). The Architect cannot spawn
   `base:integration-architect`; the Verifier cannot spawn
   `base:verification-examiner`. Both fall back to in-process Read/Grep,
   losing the "fresh-context examiner" quality model the protocol prescribes.
   The three-teammate design adds TeamCreate overhead while delivering no
   functional delegation.

2. **Misaligned model** — The lead runs on Opus. Every coordination step —
   state file updates, message routing, artifact reads — pays Opus prices over
   a context window that grows with each story.

## Solution

Replace the three-teammate team with a two-tier model:

- **Lead (Sonnet)** — thin coordinator. Spawns subagents, reads artifacts,
  updates state files, applies fast-path decision rules. Does not make
  judgment calls.
- **Decider (Opus teammate)** — decision authority. Consulted only for
  non-trivial decisions: escalations after max remediation rounds, ambiguous
  PARTIAL verdicts, spec interpretation conflicts, architecture seam disputes.
  Context grows intentionally and sparsely.

All implementation and verification work is done by fresh subagents spawned
by the lead per story:

- `base:story-planner` — spawned once for the planning phase
- `base:integration-architect` — spawned once per story for implementation
- `base:verification-examiner` — spawned per question (or related batch) for
  verification

No agent accumulates cross-story context.

## Scope

### In Scope

- Change lead model from `opus` to `sonnet` in `feature.md` frontmatter
- Remove Planner, Architect, Verifier teammates from team composition
- Add Decider teammate (Opus) with defined decision authority and routing rules
- Lead spawns `base:story-planner` directly for planning phase
- Lead spawns `base:integration-architect` per story for implementation
- Lead spawns `base:verification-examiner` per story for verification
- Define fast-path rules (lead handles autonomously) and escalation triggers
  (Decider consulted)
- Update Step 5 coordination logic to reflect the new flow
- Update crash recovery to reflect the removed teammates

### Out of Scope

- Fixing `base:integration-architect`'s internal delegation to `base:pbt-dev`
  (same tool access constraint; separate concern)
- Changes to `implement-full.md`
- Changes to `verification-examiner.md` or `integration-architect.md` agent
  definitions
- Parallel story execution (lead could spawn multiple integration-architects
  concurrently; deferred)

## Design Decisions

1. **Lead model → `sonnet`** — The lead's role is mechanical coordination:
   spawning subagents, reading JSON, routing messages, updating state. Sonnet
   handles this well and costs a fraction of Opus per token. Cost of unbounded
   context growth = `context_size × sonnet_price` vs. current
   `context_size × opus_price`. Haiku is a valid further reduction but may
   struggle with complex spec reading and artifact synthesis in edge cases.

2. **Remove all three teammates** — All three suffer the same tool access gap.
   None can spawn the subagents their role descriptions prescribe. Removing
   them and having the lead spawn subagents directly is architecturally honest
   and eliminates TeamCreate overhead with no functional regression.

3. **Add Decider teammate (Opus)** — The Sonnet lead must not make judgment
   calls on verification quality or escalation disposition. A persistent Opus
   teammate serves as the decision layer. Its context grows only on escalation
   events — sparse and load-bearing.

4. **Decision routing: non-trivial only** — Lead handles autonomously: story
   passed → update state + proceed; first retry on a clear, unambiguous
   failure. Decider handles: escalations after max remediation rounds, PARTIAL
   verdicts with severity ≥ 7, spec interpretation conflicts, architecture
   seam disputes. The fast path prevents paying Opus rates for every routine
   coordination hop.

5. **Planner as one-shot subagent** — `base:story-planner` is a bounded,
   one-shot operation: read spec, produce stories.json, done. No reason to
   maintain a long-lived teammate context for it. Lead spawns it, waits for
   completion, reads the result.

## Technical Approach

### `plugins/base/commands/feature.md`

**Frontmatter** (line 7): `model: opus` → `model: sonnet`.

**Step 4 — Create the Team**: Replace the three-role TeamCreate block with a
single Decider teammate:

```
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
```

**Step 4 — Planning phase** (replaces Planner teammate block):

```
After creating the Decider, run the planning phase:
1. Spawn Agent(subagent_type: base:story-planner) with: spec path,
   exploration.json path, architecture.md path. Wait for completion.
2. Read stories.json.
3. Sanity check: all ACs covered, story_order defined, no duplicate IDs.
   - If issues are minor and unambiguous: spawn a second base:story-planner
     with targeted corrections.
   - If issues require judgment: SendMessage(Decider) with the gap and ask
     for a decision before proceeding.
4. When stories.json is valid, proceed to the implementation loop.
```

**Step 5 — Implementation loop** (replaces three-role coordination section):

```
FOR each story in stories.json ordered by story_order WHERE status=pending:

  1. Update stories.json: story status → in_progress.
     Update epic-state.json: updated_at.

  2. Spawn Agent(subagent_type: base:integration-architect) with:
     - story spec (from stories.json entry)
     - acceptance criteria (acceptance-criteria.md, filtered to story ACs)
     - exploration.json
     - architecture.md path
     Context MUST NOT include result.json or artifacts from prior stories.
     Wait for result.json to be written.

  3. Read {story_dir}/verification.json.
     Spawn Agent(subagent_type: base:verification-examiner) for each
     question or batch of related questions. Send independent batches in
     parallel (single message, multiple Agent calls).
     Collect all results.

  4. Apply decision rules:

     FAST PATH — pass:
       All questions YES (or PARTIAL with severity < 7), all tests pass.
       → Update result.json: status=done, final_outcome=accepted, completed_at.
       → Update stories.json: story status → done.
       → Update epic-state.json: add to completed_stories.
       → Continue to next story.

     FAST PATH — first retry:
       One or more questions NO or PARTIAL ≥ 7, remediation_round = 0,
       root cause is clear and unambiguous in the examiner output.
       → Spawn fresh Agent(subagent_type: base:integration-architect) with
         the examiner findings as the remediation brief.
       → Re-run verification (step 3). If passes → FAST PATH pass.
       → If fails again → ESCALATE path.

     ESCALATE:
       Triggered by any of:
       - remediation_round ≥ 1 and still failing
       - PARTIAL with severity ≥ 7 and ambiguous root cause
       - Examiner results contradict each other
       - Spec interpretation conflict surfaced during implementation
       - Architecture seam dispute
       → SendMessage(Decider) with: story ID, verification.json summary,
         examiner results, remediation history, specific question.
       → Execute Decider's decision:
           RETRY    → spawn fresh base:integration-architect with Decider's prompt
           ESCALATE → mark story escalated in stories.json and epic-state.json
           ACCEPT   → update result.json with caveats; mark done
           REJECT   → treat as remediation round; re-run from step 2

  5. After all stories done or escalated, lead runs full test suite directly.
     If failures: SendMessage(Decider) before declaring epic done.
```

**Crash recovery** — Remove "Recreate the team with Planner, Architect,
Verifier" step. Replace with:

```
7. Recreate only the Decider teammate (single TeamCreate call, one role).
8. Resume the implementation loop from the first story with
   status ≠ done/escalated. Pass Decider context: which stories are done,
   current story, remediation history if mid-round.
```

## Stories

- **S1 — Lead model + Decider role** — Change frontmatter model; replace
  Step 4 team composition with Decider role definition. Covers AC-COORD-1,
  AC-COORD-2.

- **S2 — Planning via direct subagent** — Remove Planner teammate; rewrite
  planning phase so lead spawns `base:story-planner` directly and reviews
  the result per the new rules. Covers AC-PLAN-1, AC-PLAN-2.

- **S3 — Per-story implementation subagent** — Remove Architect teammate;
  rewrite Step 5 so lead spawns `base:integration-architect` per story with
  no cross-story context. Covers AC-IMPL-1, AC-IMPL-2.

- **S4 — Per-story verification subagents** — Remove Verifier teammate;
  rewrite verification step so lead spawns `base:verification-examiner` per
  question, collects results, applies decision rules. Covers AC-VER-1,
  AC-VER-2.

- **S5 — Decision routing + crash recovery** — Write fast-path and escalation
  rules into Step 5; update crash recovery to remove teammate recreation.
  Covers AC-COORD-3, AC-COORD-4, AC-CRASH-1.

## Acceptance Criteria

See [`acceptance-criteria.md`](./acceptance-criteria.md).

## Relationship to Other Epics

- No active dependencies. This epic modifies `plugins/base/commands/feature.md`
  only; `implement-full.md` is unaffected.

## Non-Goals

- Fixing nested subagent delegation within `base:integration-architect`
  (the pbt-dev spawning constraint is a separate system-level issue).
- Parallel story execution.
- Changing `verification-examiner.md` or `integration-architect.md` agent
  protocols.
