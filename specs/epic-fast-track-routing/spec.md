# Fast Track Routing

Source: BACKLOG.md findings promoted 2026-05-13 (`plugins/base/commands/next.md:47-91` and `plugins/base/commands/feature.md`).

## Problem

Two complementary findings on `BACKLOG.md` describe the same root cause from different angles. They have been unified into this epic:

> `plugins/base/commands/next.md:47-91` — Step 3 classifies findings on a single axis (`bug` / `question` / `feature-work`) and routes the latter unconditionally to `/base:feature`, with no scale or work-type detection; a finding whose actual disposition is a spec amendment (the BACKLOG bullet literally says "AC-X needs amendment in specs/epic-Y") gets the full 4-story `/base:feature` pipeline (architect+examiner per story, ~17 subagent spawns) when `/base:backlog resolve done→spec` would suffice — add a routing axis or heuristic so amendment-class / mechanical-class findings flow to a lighter workflow.

> `plugins/base/commands/feature.md` — for markdown-only stories where spec content is fully specified, the integration-architect subagent adds latency with no value (it reads the same spec the lead already has, then writes it); `base:integration-architect` timed out after 351s/6 tool calls during epic-base-next S1; add a "markdown-only, fully-specified" heuristic to story-planner output or `/base:feature` Step N to flag these for direct lead implementation, skipping architect dispatch.

Combined effect: small, mechanical, or amendment-class findings pay the full pipeline cost. Empirical evidence the detector is out of band: epic-next-modes (a markdown-only spec amendment) ran the full pipeline with 100% YES on every check, 0 retros, 0 escalations. The pipeline produced no useful signal because nothing about the work warranted architect-level inspection.

The cost is not theoretical: every full-pipeline dispatch spawns ~17 subagents (2-3 explorers, 3 story-planner modes, 1 architect per story, 1+ examiners per story, plus optional spec-validator and decider). For markdown-only AC-amendment work, the architect's value-add (module-boundary design, seam contracts, cross-file dependency analysis) is zero; the examiner's value-add (verifying the change addresses the AC) remains useful.

## Solution

Two complementary changes, one upstream and one inside `/base:feature`:

1. **Upstream — `/base:next` scale axis.** Step 3 of `/base:next` gains a second classification axis orthogonal to the existing `kind`: `scale ∈ {full, amendment, mechanical}`. The routing matrix dispatches `mechanical` to `/base:backlog resolve done-mechanical`, `amendment` to `/base:backlog resolve done→spec:<inferred-path>`, and `full` to the existing `/base:feature` or `/base:bug` flow. The user is informed of the scale classification in detail mode and can override; auto mode acts silently.

2. **Inside — `/base:feature` `lighter_path` story flag.** `base:story-planner` Mode 2 emits a `lighter_path: boolean` flag per story (default `false`). A story qualifies for `lighter_path: true` IFF every file target has a markdown-class extension AND every AC in scope is fully specified per a deterministic check. When the implementation loop sees `lighter_path: true`, it skips the integration-architect spawn — the lead writes the implementation directly via `Edit` calls. The verification-examiner still runs.

The two changes are complementary, not redundant: `/base:next`'s axis catches findings that should never have entered `/base:feature` in the first place; the `lighter_path` flag catches stories within an epic that genuinely belong in `/base:feature` but happen to be markdown-only.

## Scope

### In Scope

- New `scale` axis in `/base:next` Step 3 classifier, orthogonal to the existing `kind` axis.
- Heuristic for scale detection from finding prose and anchor file extension (keyword lookups + extension patterns; no ML).
- New dispatch branches in `/base:next` Step 6 routing matrix for `mechanical` and `amendment` scales.
- `lighter_path` field in `plugins/base/schemas/stories.schema.json` (boolean, default `false`).
- `base:story-planner` Mode 2 logic that emits the flag based on file-extension + AC-specification checks.
- `/base:feature` Step 5 branch on `lighter_path` that skips the integration-architect spawn while preserving the examiner spawn and the four-artifact crash-recovery invariant.
- Updates to `plugins/base/skills/backlog/references/format.md` documenting the scale axis.

### Out of Scope

- ML-based or LLM-call-based scale classification — heuristics only this epic.
- Lighter-path execution inside `/base:bug` — separate epic if surfaced.
- Cross-feature dependency analysis to detect when a "mechanical" finding actually has hidden behavior implications — out-of-band heuristics, deferred.
- Auto-promotion of `mechanical` findings without any user notice — every dispatch (auto or detail) emits a notice line citing the (kind, scale) classification.

## Design Decisions

1. **Scale axis is orthogonal to kind axis.** Refs: `plugins/base/commands/next.md:104-137`. Folding scale into the existing kind classification would couple two independent dimensions and force ambiguous tags (e.g. is a markdown-only bug-fix `mechanical` or `bug`? Both.). Keeping them orthogonal makes the routing matrix explicit.
2. **Routing decision lives in `/base:next` Step 3+6, not inside `/base:feature`.** Refs: `plugins/base/commands/next.md:474-543`. The dispatcher is the right place to detect scale because rerouting from `/base:feature` mid-flight (after Step 1 has already scaffolded a spec stub via BACKLOG_PROMOTE) would orphan the stub.
3. **Heuristic over ML.** False negatives are cheap (work falls through to full pipeline); false positives are costly (user has to revert and re-dispatch). Conservative keyword + extension matching errs toward `full`.
4. **`lighter_path` is per-story, not per-epic.** An epic with one markdown-only story and one code story can mix paths. The heuristic decides per story at planning time.
5. **Lighter path keeps the examiner.** The architect's value is module-boundary design (irrelevant for markdown); the examiner's value is verifying the change addresses the AC (still relevant for markdown). Skipping the architect alone gives most of the latency win without sacrificing verification.
6. **Lighter-path remediation falls back to full path.** If an examiner finds a defect in lead-written markdown, remediation round 1 re-spawns the architect with the examiner's findings as brief. The lead does not get a second attempt; the architect is the escalation. This preserves the existing fast-path-retry mechanism for non-lighter-path stories without introducing a new lighter-path retry contract.
7. **Four-artifact invariant preserved.** Even on `lighter_path`, the lead writes minimal `architecture.json` (records the lighter-path decision), `baseline.json` (records no test snapshot needed), and `result.json` stubs. Crash recovery's per-story artifact check (see `/base:feature` Step 5.4 / Crash Recovery step 4) continues to find what it expects.

## Technical Approach

### `plugins/base/commands/next.md`

Step 3 gains a scale-classification subsection invoked after the existing kind classification:

```
For each bullet whose kind ∈ {bug, feature-work}, classify scale:

  - `mechanical` IF the bullet text contains any of {"typo", "rename",
    "dead code", "formatting", "lint", "whitespace"} OR the anchor file
    extension is in {.json, .yaml, .yml, .toml, .lock, .gitignore} AND
    the bullet text contains no behavior-change verb {"fails", "crashes",
    "returns wrong", "leaks", "drops", "blocks"}.

  - `amendment` IF the bullet text contains any of {"AC ", "AC-", "spec",
    "amendment", "amends", "AC ID", "rule", "convention"} AND the anchor
    points at a file under `specs/` OR `plugins/base/skills/`.

  - `full` otherwise (default).
```

Step 6 routing matrix:

| kind | scale=full | scale=amendment | scale=mechanical |
|---|---|---|---|
| `bug` | `/base:bug backlog:<m>` | `/base:bug backlog:<m>` | `/base:backlog resolve <m> done-mechanical` |
| `feature-work` | `/base:feature backlog:<m>` | `/base:backlog resolve <m> done→spec:<inferred>` | `/base:backlog resolve <m> done-mechanical` |

Inference of `<spec-path>` for `done→spec`: anchor path component, walked upward until a `specs/epic-*/` directory is found, OR (when anchor is under `plugins/base/skills/`) treated as the spec itself.

### `plugins/base/agents/story-planner.md`

Mode 2 (the story-decomposition mode) gains a final step before emitting `stories.json`:

```
For each story:
  files_md   = every file target in story.files whose extension is in
               {.md, .json, .yaml, .toml, .txt}.
  files_code = every other file target.

  ac_complete = every AC referenced by the story's acceptance_criteria
                exists in acceptance-criteria.md, has no `<placeholder>`
                token, no `…`, and no trailing `?`, AND its text is in
                MUST / MUST NOT form (no "may", "could", "should").

  lighter_path = (files_code is empty) AND ac_complete AND
                 (story.kind != "create new file").

  story.lighter_path = lighter_path.
```

### `plugins/base/schemas/stories.schema.json`

Add at the story-object level:

```json
"lighter_path": {
  "type": "boolean",
  "default": false,
  "description": "When true, /base:feature Step 5 skips the integration-architect spawn for this story; lead implements directly via Edit. Examiner still runs."
}
```

### `plugins/base/commands/feature.md`

Step 5 implementation loop gains a `lighter_path` branch:

```
FOR each story:
  IF story.lighter_path == true:
    - Write minimal architecture.json with {decision: "lighter_path",
      reason: "<heuristic match summary>", architect_skipped: true}.
    - Write minimal baseline.json with {test_snapshot: "skipped",
      reason: "markdown-only-no-test-baseline"}.
    - Lead implements the story directly via Edit calls on the file
      targets, citing the story's ACs inline.
    - Write result.json with status=done, architect_skipped: true,
      and the list of files modified.
    - Continue to bullet 3 (examiner spawn) — examiner still runs.
  ELSE:
    - Existing flow (spawn architect, then examiner).
```

### `plugins/base/skills/backlog/references/format.md`

Add a brief note after the existing `## Findings` grammar describing the scale axis: how `/base:next` classifies findings on two axes now, and what each scale value implies for routing.

## Stories

- **S1 — `/base:next` scale axis** — Add the scale classifier to Step 3 of `/base:next` and extend the Step 6 routing matrix to dispatch `mechanical` to `done-mechanical` and `amendment` to `done→spec:<inferred>`. Update detail-mode rendering to surface the (kind, scale) tuple. Update auto-mode notice line. Covers AC-NEXT-1, AC-NEXT-2, AC-NEXT-3, AC-NEXT-4, AC-NEXT-5.

- **S2 — `lighter_path` flag in story-planner + schema** — Extend `plugins/base/schemas/stories.schema.json` with the `lighter_path` boolean (default `false`). Extend `base:story-planner` Mode 2 with the deterministic flag-emission logic. Covers AC-STORY-1, AC-STORY-2, AC-STORY-3.

- **S3 — `/base:feature` lighter-path execution** — Extend Step 5 of `/base:feature` with the `lighter_path == true` branch: skip the integration-architect spawn, lead implements directly, write minimal architecture.json / baseline.json / result.json stubs, examiner still runs. Document the remediation fallback (round 1 re-spawns the architect). Covers AC-FEATURE-1, AC-FEATURE-2, AC-FEATURE-3, AC-FEATURE-4.

- **S4 — Cross-cutting docs and observability** — Update `plugins/base/skills/backlog/references/format.md` to document the scale axis. Ensure dispatch notices and `result.json` carry the observability fields documented in AC-OBS-1 and AC-OBS-2. Covers AC-OBS-1, AC-OBS-2.

## Acceptance Criteria

See [`acceptance-criteria.md`](./acceptance-criteria.md).

## Relationship to Other Epics

- **epic-next-modes** (DONE) — built `/base:next auto` and `<hint>` modes. This epic adds the scale axis as a second dimension to Step 3's classifier, building on the same dispatch infrastructure.
- **epic-lean-lead-decider** (DONE) — applied the lean-lead + Decider pattern to `/base:bug`. This epic extends the spirit by routing some work away from the lead-decider workflow entirely, when the lead-decider machinery is overhead for the work.

## Non-Goals

- ML-based or LLM-call-based scale classification — the project's direction is deterministic, auditable heuristics for routing decisions.
- Replacing `/base:feature` for non-trivial work — the full pipeline remains the default. Lighter path is opt-in via heuristic, never the default.
- Cross-feature dependency analysis for scale detection — out of band; the heuristic stays local to each finding.
