# Fast Track Routing — Acceptance Criteria

## Terminology

- **scale axis** — A second classification dimension orthogonal to the existing `kind ∈ {bug, feature-work, question}` axis in `/base:next` Step 3. Values: `full`, `amendment`, `mechanical`.
- **lighter_path** — A boolean property on a story in `stories.json` indicating that `/base:feature` Step 5 should skip the integration-architect spawn for this story; the lead implements directly via `Edit` calls.
- **markdown-class extension** — File extension in `{.md, .json, .yaml, .yml, .toml, .txt}`. These are formats whose changes never benefit from module-boundary design analysis.
- **routing matrix** — The two-dimensional dispatch table in `/base:next` Step 6 keyed by `(kind, scale)` whose cells name a Skill invocation.
- **inferred spec path** — For an `amendment`-class finding, the spec file that should receive the AC patch. Inference rule: walk upward from the anchor path until a `specs/epic-*/` directory is found; or, for anchors under `plugins/base/skills/<name>/`, the anchored file itself is treated as the spec target.

## Scale Axis in `/base:next` (S1)

**AC-NEXT-1** — `plugins/base/commands/next.md` Step 3 MUST classify each non-`insufficient`, non-`already-resolved` finding bullet on two axes: `kind ∈ {bug, feature-work, question}` AND `scale ∈ {full, amendment, mechanical}`. The two classifications MUST be independent — a single finding produces exactly one (kind, scale) pair.

**AC-NEXT-2** — When `(kind, scale) == (feature-work, mechanical)` OR `(kind, scale) == (bug, mechanical)`, `/base:next` Step 6 MUST dispatch via `Skill("base:backlog", args: "resolve <marker> done-mechanical")` and MUST NOT dispatch via `/base:feature` or `/base:bug`.

**AC-NEXT-3** — When `(kind, scale) == (feature-work, amendment)`, `/base:next` Step 6 MUST attempt to infer a `<spec-path>` from the finding's anchor per the inferred-spec-path rule. If inference succeeds, dispatch MUST invoke `Skill("base:backlog", args: "resolve <marker> done→spec:<spec-path>")`. If inference fails, the bullet MUST be reclassified `scale = full` and dispatched to `/base:feature backlog:<marker>` as today.

**AC-NEXT-4** — When `(kind, scale) == (bug, amendment)`, `/base:next` Step 6 MUST dispatch to `/base:bug backlog:<marker>` unchanged from today's behavior — bugs with amendment-shape framing still warrant the bug workflow because behavior is broken. The `amendment` scale value is recorded but does not alter routing for the bug kind.

**AC-NEXT-5** — `/base:next` MUST surface the (kind, scale) tuple in every dispatch notice line, in both detail mode and auto mode. The notice format MUST be: `Dispatching as <kind>/<scale>: <truncated-bullet>` (auto) OR include `<kind>/<scale>` in the rendered candidate line (detail). Users can override the classification in detail mode via the existing AskUserQuestion path.

## `lighter_path` Flag (S2)

**AC-STORY-1** — `plugins/base/schemas/stories.schema.json` MUST include a `lighter_path` property at the story-object level with `type: "boolean"` and `default: false`. The property MUST NOT be required (default applies).

**AC-STORY-2** — `base:story-planner` Mode 2 MUST emit `lighter_path: true` on a story IFF all three conditions hold: (a) every file target in `story.files` has an extension in the markdown-class extension set; (b) every AC referenced in `story.acceptance_criteria` is fully specified per the `ac_complete` predicate (exists in `acceptance-criteria.md`, contains no `<placeholder>` or `…` or trailing `?`, uses MUST/MUST NOT normative form); (c) the story does not introduce a new file (`create new file` is not in the story's scope words).

**AC-STORY-3** — When any of the three conditions in AC-STORY-2 cannot be deterministically verified from the planner's inputs (`stories.json`, `acceptance-criteria.md`, file-target list), `base:story-planner` MUST emit `lighter_path: false`. The conservative default applies.

## Lighter-Path Execution (S3)

**AC-FEATURE-1** — In `/base:feature` Step 5, when the current story's `lighter_path == true`, the lead MUST NOT invoke `Agent(subagent_type: base:integration-architect)` for this story. The lead MUST write the implementation directly via `Edit` calls on the story's file targets.

**AC-FEATURE-2** — When `lighter_path == true`, the lead MUST write three minimal artifacts before marking the story `done` to preserve the four-artifact crash-recovery invariant: `architecture.json` containing `{"decision": "lighter_path", "architect_skipped": true, "reason": <one-line summary>}`; `baseline.json` containing `{"test_snapshot": "skipped", "reason": "markdown-class-no-test-baseline"}`; `result.json` containing `{"status": "done", "architect_skipped": true, "files_modified": [...]}`. The `verification.json` artifact is already written by `base:story-planner` Mode 3 and is untouched by this branch.

**AC-FEATURE-3** — When `lighter_path == true`, `Agent(subagent_type: base:verification-examiner)` MUST still be spawned per the existing flow in `/base:feature` Step 5 bullet 3. The examiner spawn is unconditional on `lighter_path`; only the architect is skipped.

**AC-FEATURE-4** — If a `lighter_path == true` story fails examiner verification (any NO verdict, or any PARTIAL with severity ≥ 4), the remediation path MUST fall back to the full architect-driven flow: remediation round 1 spawns `Agent(subagent_type: base:integration-architect)` with the examiner findings as remediation brief. The lead MUST NOT attempt a second lead-written implementation on the same story.

## Cross-Cutting Invariants (S4)

**AC-OBS-1** — Every dispatch decision in `/base:next` Step 6 MUST emit a single notice line to stdout containing both the (kind, scale) tuple and the target Skill invocation. The line MUST be greppable for routing audits (canonical token: `Dispatching as <kind>/<scale>:`).

**AC-OBS-2** — For any story where the lead skipped the architect spawn (`lighter_path == true` path), the persisted `result.json` MUST include `"architect_skipped": true` as a top-level boolean field. This field MUST be queryable from retros and audit scripts to track lighter-path adoption rates.

**AC-DOC-1** — `plugins/base/skills/backlog/references/format.md` MUST describe the scale axis: the three values, the routing matrix, and the keyword/extension heuristics used by the classifier. The description MUST be authoritative — every other skill or doc that references scale-axis classification MUST cite `references/format.md` rather than restating the rules.

## Manual Validation

- After S1 lands, manually exercise `/base:next` against a hand-crafted BACKLOG.md containing one finding per (kind, scale) cell of the routing matrix. Confirm each routes to the expected destination and the notice line carries the expected `<kind>/<scale>` token. (Cannot be automated without a fake BACKLOG.md fixture and a Skill-call interceptor.)

- After S3 lands, manually run `/base:feature` on an epic whose `stories.json` has one `lighter_path: true` story and one `lighter_path: false` story. Confirm the architect spawn occurs only for the latter and `result.json` carries `architect_skipped: true` only for the former.
