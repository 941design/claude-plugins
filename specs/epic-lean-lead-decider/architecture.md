# Architecture — lean-lead-decider

## Paradigm

Prompt/skill-as-document. One Markdown file owns one orchestration contract. No
runtime code; no test suite. Edits are textual.

## Module map

| Module | Path | Role |
|--------|------|------|
| feature-skill | `plugins/base/commands/feature.md` | The team-lead orchestration contract for `/base:feature`. Sole edit target of this epic. |

## Boundary rules

- No edits to `plugins/base/commands/implement-full.md` (consumes `/feature` as a black box).
- No edits to `plugins/base/commands/bug.md`.
- No edits to any `plugins/base/agents/*.md` (subagent contracts unchanged).
- The "Conventions for spawning vs. messaging" preamble in `feature.md` is preserved verbatim — it is the load-bearing safety reminder that prevents the very class of bug being fixed.
- The "Strict Artifact Requirements" section listing the per-story artifact set (`architecture.json`, `baseline.json`, `verification.json`, `result.json`) is preserved.

## Seams

None. Single file, sequential textual edits.

## Implementation constraints

- Frontmatter `model:` value must be `sonnet` after S1.
- Step 4 must declare exactly one teammate (Decider) with response types {RETRY, ESCALATE, ACCEPT, REJECT}.
- Step 5 must spawn `base:story-planner`, `base:integration-architect`, and `base:verification-examiner` via the Agent tool from the lead.
- Step 5 must contain no SendMessage to `architect`, `verifier`, or `planner` role names.
- Crash Recovery must instruct Decider-only teammate recreation.

## Stories

| ID | Scope | Owns lines (approximate, in current file) |
|----|-------|-------------------------------------------|
| S1 | Frontmatter model + Step 4 Decider | 6, 145–230 |
| S2 | Planning phase rewrite | 244 (planner-message line); planner role block already removed by S1 |
| S3 | Step 5 implementation loop (spawn integration-architect per story) | 240–263 |
| S4 | Step 5 verification block (spawn verification-examiner per question) | 240–263 (bundled with S3) |
| S5 | Decision routing + Crash Recovery | 240–263 (decision routing) + 294–314 |

S1's Step-4 rewrite removes the persistent role blocks; S2–S5 then populate Step 5 and Crash Recovery with the new lead-direct flow. Intermediate states between stories are intentionally incoherent — final coherence is validated in Phase E.
