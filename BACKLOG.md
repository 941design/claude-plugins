# Project Backlog

## Epics

- specs/epic-base-next/ — DONE — seeded by /base:backlog init 2026-05-12
- specs/epic-lean-lead-decider/ — DONE — seeded by /base:backlog init 2026-05-12
- specs/epic-pipeline-autonomous-retros/ — DONE — completed 2026-05-12
- specs/epic-next-modes/ — DONE — completed 2026-05-12

---

## Findings

- `plugins/base/skills/adr/SKILL.md:65-69` — `proposed+supersedes` composability is undocumented: when both flags are passed together, it is unspecified whether the superseded ADR's `Superseded by:` line should be updated immediately (when the new ADR is still Status: Proposed) or deferred until the user accepts the ADR — surfaced as VQ-S4-009 PARTIAL, pipeline-autonomous-retros S4 (2026-05-12)
- `plugins/base/skills/spec-template/SKILL.md:244` — AC-ID uniqueness rule in spec-template says `<N>` is unique within the AC file (so AC-STRUCT-7 and AC-DEP-7 cannot coexist), but every existing AC file uses per-tag resetting (AC-NEXT-1, AC-BUG-1, AC-ORIENT-1 coexist in epic-base-next); the de facto convention disagrees with the format authority — surfaced during epic-next-modes planning (2026-05-12)
- `-` — No `skills/languages/markdown.md` exists; the verification-examiner's AC-derived SPEC protocol requires "(b) tests at file:line" and "(c) confirmation tests are not pure mock-spy proxies", written for executable code — epics whose stories edit only Markdown files have no matching language skill, causing examiners to improvise — surfaced during epic-next-modes (2026-05-12)
- `plugins/base/schemas/stories.schema.json:39` — `story_order` array items and story `id` fields require pattern `^[0-9]{2}$` (e.g. "01", "02"), but spec prose and `spec.md ## Stories` sections universally use prose IDs `S1`/`S2`/`S3`; the mismatch is invisible until schema validation runs — surfaced during epic-next-modes planning (2026-05-12)
- `plugins/base/agents/story-planner.md:58` — Mode-3 question record shape example uses field name `"category"` for the question type, but every `verification.json` file in the repo uses field name `"type"` for the same field; either the schema example or the codebase convention needs alignment — surfaced during epic-next-modes Mode-3 planning (2026-05-12)

---

## Archive

- _no rejections yet_
