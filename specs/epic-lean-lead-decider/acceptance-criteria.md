# Lean Lead + Decider — Acceptance Criteria

## Terminology

- **Lead** — the main session running the `base:feature` skill.
- **Decider** — the single Opus teammate created via TeamCreate.
- **Fast path** — outcomes the lead resolves autonomously without consulting
  the Decider.
- **Escalation trigger** — a condition that causes the lead to SendMessage the
  Decider before proceeding.
- **Story worker** — a fresh `base:integration-architect` or
  `base:verification-examiner` subagent spawned per story by the lead.

## Lead Model + Decider Role (S1)

**AC-COORD-1** — `plugins/base/commands/feature.md` MUST declare
`model: sonnet` in its YAML frontmatter. `model: opus` MUST NOT appear in
the frontmatter.

**AC-COORD-2** — Step 4 of `feature.md` MUST define exactly one teammate
role: the Decider. The role description MUST specify Opus as the model and
enumerate the four response types (RETRY, ESCALATE, ACCEPT, REJECT). The
Planner, Architect, and Verifier role blocks MUST NOT appear in Step 4.

## Planning Phase (S2)

**AC-PLAN-1** — The planning phase MUST spawn `base:story-planner` via the
Agent tool (not via TeamCreate or SendMessage). The spawn MUST pass the spec
path, exploration.json path, and architecture.md path as context.

**AC-PLAN-2** — After the planner subagent completes, the lead MUST read
`stories.json` directly and validate it. If gaps require judgment, the lead
MUST consult the Decider via SendMessage — not spawn a second Planner
teammate.

## Per-Story Implementation (S3)

**AC-IMPL-1** — For each story, the lead MUST spawn a fresh
`base:integration-architect` subagent via the Agent tool. The spawn context
MUST NOT include result.json or artifacts from prior stories.

**AC-IMPL-2** — `feature.md` MUST NOT maintain a persistent Architect
teammate across stories. No SendMessage to an `architect` role MUST appear
in Step 5.

## Per-Story Verification (S4)

**AC-VER-1** — After each `base:integration-architect` completes, the lead
MUST spawn `base:verification-examiner` subagents for the verification
questions in `{story_dir}/verification.json`. Independent questions or
batches MUST be sent in parallel (single message, multiple Agent calls).

**AC-VER-2** — `feature.md` MUST NOT maintain a persistent Verifier teammate
across stories. No SendMessage to a `verifier` role MUST appear in Step 5.

## Decision Routing (S5)

**AC-COORD-3** — Step 5 MUST define a fast path that the lead executes
autonomously (without consulting the Decider) for at least: (a) all
verification questions pass → proceed to next story; (b) first remediation
round with a clear, unambiguous root cause.

**AC-COORD-4** — Step 5 MUST define escalation triggers that cause the lead
to SendMessage the Decider before proceeding. Triggers MUST include at
minimum: remediation round ≥ 1 still failing; PARTIAL verdict with
severity ≥ 7 and ambiguous root cause; story escalated after max rounds.

## Crash Recovery (S5)

**AC-CRASH-1** — The crash recovery section of `feature.md` MUST NOT
instruct recreation of Planner, Architect, or Verifier teammates. It MUST
instruct recreation of the Decider teammate only, followed by resumption of
the lead's implementation loop from the first incomplete story.

## Cross-Cutting Invariants

**AC-COORD-5** — Every Agent tool call in Step 5 that spawns
`base:integration-architect` or `base:verification-examiner` MUST originate
from the lead, not from a teammate or a previously spawned subagent.
