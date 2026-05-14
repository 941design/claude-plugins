# Architecture: story-planner-schema-conformance

## Paradigm

Agent-prompt documentation monorepo with JSON Schema contracts. No runtime
code — all "modules" are Markdown agent prompts and JSON Schema files. The
pipeline is: spec.md → story-planner → stories.json + verification.json →
integration-architect → result.json.

## Module Map

| Module | Purpose | Location | Owned Data |
|---|---|---|---|
| `story-planner` | Derives ACs, splits stories, authors verification commitments | `plugins/base/agents/story-planner.md` | `acceptance-criteria.md`, `stories.json`, `{story_dir}/verification.json` |
| `stories-schema` | Enforces structure of stories.json | `plugins/base/schemas/stories.schema.json` | JSON Schema contract for story IDs, AC IDs, story_order |
| `verification-schema` | (new) Enforces structure of verification.json | `plugins/base/schemas/verification.schema.json` | JSON Schema contract for question records |
| `spec-template` | Authoritative format reference for spec.md and acceptance-criteria.md | `plugins/base/skills/spec-template/SKILL.md` | AC-ID uniqueness rule (source of truth) |

## Boundary Rules

- No direct imports across module boundaries. This is a documentation system;
  "cross-module access" means agent prompts citing schema files by path.
- `story-planner.md` is the only agent that WRITES `stories.json` and
  `verification.json`. All other agents are read-only consumers.
- Schema files are constraints, not implementations — they describe the shape of
  artifacts, not how to produce them.

## Seams

None required — this is a single-story epic with no cross-story dependencies.

## Implementation Constraints

1. **Scope guard**: changes are limited to `plugins/base/agents/story-planner.md`,
   `plugins/base/schemas/stories.schema.json`, and optionally
   `plugins/base/schemas/verification.schema.json`. No other files are in scope.
2. **Schema follows code**: the `^S[0-9]+$` pattern update aligns schema to
   de facto; no migration of on-disk stories.json files is needed.
3. **Rule 4 wording**: must match spec-template/SKILL.md:243 exactly in spirit —
   "unique within its tag (not globally across the file)".
4. **No downstream prose changes**: feature.md, verification-examiner.md, and
   integration-architect.md already handle S-prefix IDs; they must not be
   touched by this epic.
5. **verification.schema.json optional**: if drafted, it must use JSON Schema
   Draft 2020-12 and must not make `ac_id` required (it is optional on non-SPEC
   questions).
