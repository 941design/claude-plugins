# Story Planner Mode Prompt / Schema Conformance

## Problem

All three Mode prompts in `plugins/base/agents/story-planner.md` disagree
with their corresponding on-disk schemas or de facto conventions. Each
discrepancy was surfaced independently during `epic-next-modes`, suggesting
the prompt and its downstream schemas were authored without cross-checking.
The practical consequence is that the story-planner produces artifacts that
violate the schemas they are supposed to follow, and downstream agents
(verification-examiner, base:feature crash recovery) may behave incorrectly
when parsing those artifacts.

Three specific mismatches, verified against current state of the files:

1. **Mode 1 — AC-ID uniqueness** (`story-planner.md:163`): Rule 4 states
   "`<N>` is a 1-based integer unique within the AC file" (global uniqueness),
   but the `base:spec-template` amendment of 2026-05-14 established that `<N>`
   is per-tag (counter resets per TAG; two tags may each start at 1). Every
   existing AC file uses the per-tag convention; the story-planner prompt is
   the one outlier and misguides authors who consult it.

2. **Mode 2 — story ID format** (`stories.schema.json:39,79`): The schema
   enforces `^[0-9]{2}$` for both `story.id` and entries in `story_order`
   ("01", "02"), but every on-disk `stories.json` produced by the story-planner
   uses the "S1", "S2" S-prefix format, and downstream files (`verification.json`
   question IDs "VQ-S1-001", spec.md story previews) all follow S-prefix. The
   schema is the outlier and would reject valid artifacts if actually validated.

3. **Mode 3 — `category` field** (`story-planner.md:118`): Earlier versions of
   this prompt used `"type"` for the question-record field; the current prompt
   uses `"category"` and on-disk `verification.json` files also use `"category"`.
   The discrepancy is now self-consistent in the prompt, but no
   `verification.schema.json` exists, so drift could re-occur silently.

Source: BACKLOG.md finding promoted 2026-05-14

## Solution

Reconcile the story-planner prompt's stated conventions with the actual schemas
and de facto conventions, and add a schema-conformance validation note so future
divergence is caught before shipping. Concretely:

- **Fix Mode 1**: Update Rule 4 in story-planner.md to say "unique within its
  tag" (matching spec-template's 2026-05-14 amendment).
- **Fix Mode 2**: Update `stories.schema.json` to accept the S-prefix format
  (`^S[0-9]+$`) for story `id` and `story_order` entries. Do not change the
  planner prose or existing files — schema follows code.
- **Confirm Mode 3**: Verify the `category` field is already consistent; add a
  one-line note in Mode 3 citing the field names as normative. Optionally ship a
  `verification.schema.json` to lock the shape.
- **Add conformance note**: Add a short "Schema conformance" subsection to the
  story-planner's Validation Checks section, citing each schema file by path.

## Scope

### In Scope

- Edit `plugins/base/agents/story-planner.md`: fix Rule 4 uniqueness wording;
  add schema-conformance note to Validation Checks.
- Edit `plugins/base/schemas/stories.schema.json`: update `story.id` and
  `story_order` item patterns from `^[0-9]{2}$` to `^S[0-9]+$`.
- Confirm Mode 3 `category` field consistency; add normative reference in
  Mode 3's "Question record shape" note.
- Optionally ship `plugins/base/schemas/verification.schema.json` to lock the
  `verification.json` shape.

### Out of Scope

- Renaming existing story directories or renumbering story IDs in on-disk
  `stories.json` files — schema follows code; we do not migrate history.
- Changes to any other agent prompts or workflow commands.
- Adding runtime schema validation to `base:feature` or `base:story-planner`
  — the conformance note in the prompt is the deliverable; a full validation
  pass is a separate finding.

## Design Decisions

1. **Schema follows code for Mode 2** — The de facto in every on-disk
   `stories.json` is "S1", "S2". Changing the planner to emit "01", "02" would
   require migrating every verification.json question_id prefix and every
   downstream crash-recovery path. Updating the schema pattern is a one-field
   change with no migration cost. Refs: `plugins/base/schemas/stories.schema.json:39,79`.

2. **Verification schema is optional but strongly recommended** — A
   `verification.schema.json` makes Mode 3 drift detectable at write time. If
   the schema is straightforward from the prompt's `verification.json` shape
   (it is), ship it. If any field is genuinely ambiguous (e.g. `ac_id` optional
   presence rule), skip and note the gap. Refs: `plugins/base/agents/story-planner.md:117-125`.

3. **Mode 1 fix is a single-sentence edit** — Rule 4 says "unique within the
   AC file"; replacing "within the AC file" with "within its tag" aligns with
   the spec-template source of truth without touching any other logic. Refs:
   `plugins/base/agents/story-planner.md:163`.

## Technical Approach

### `plugins/base/agents/story-planner.md`

**Rule 4 (line 163):** Replace
> `<N>` is a 1-based integer unique within the AC file.

with:
> `<N>` is a 1-based integer **unique within its tag** (counter resets per TAG;
> IDs are unique within a tag, not globally across the file). See `base:spec-template`
> for the authoritative description.

**Mode 3 Question record shape (lines 117–125):** After the JSON example, add:

> Field `"category"` (not `"type"`) is normative. Omit `"ac_id"` on non-SPEC
> questions.

**Validation Checks (after the existing bullet list):** Add:

> **Schema conformance.** For each Mode, the output artifact MUST conform to the
> corresponding schema:
> - Mode 2 → `plugins/base/schemas/stories.schema.json`
> - Mode 3 → `plugins/base/schemas/verification.schema.json` (if present)
> Validate examples in this prompt against those schemas before shipping any update.

### `plugins/base/schemas/stories.schema.json`

Update two patterns from `^[0-9]{2}$` to `^S[0-9]+$`:
- `story.id` (line 79 `pattern`)
- `story_order` array item (line 39 `pattern`)

Update the `description` strings to match:
- `story.id`: `"Story identifier (S1, S2, …)"`
- `story_order`: `"Ordered list of story IDs (S1, S2, …)"`

### `plugins/base/schemas/verification.schema.json` (new, optional)

Derive from the Mode 3 question record shape in story-planner.md:
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "verification.schema.json",
  "title": "Verification Commitment Set Schema",
  "type": "object",
  "required": ["story_id", "authored_by", "authored_at", "questions"],
  "properties": {
    "story_id": { "type": "string" },
    "authored_by": { "type": "string" },
    "authored_at": { "type": "string", "format": "date-time" },
    "questions": {
      "type": "array",
      "items": { "$ref": "#/$defs/question" },
      "minItems": 1
    }
  },
  "$defs": {
    "question": {
      "type": "object",
      "required": ["question_id", "phase", "category", "question"],
      "properties": {
        "question_id": { "type": "string", "pattern": "^VQ-[A-Z0-9]+-[0-9]{3}$" },
        "phase": { "type": "string", "enum": ["pre-impl", "post-impl"] },
        "category": { "type": "string", "enum": ["QUALITY", "ARCHITECTURE", "TEST", "SPEC", "SECURITY", "BEST_PRACTICES"] },
        "ac_id": { "type": "string", "pattern": "^AC-[A-Z]+-[0-9]+$" },
        "question": { "type": "string" }
      }
    }
  }
}
```

## Stories

- **S1 — reconcile-mode-prompts-and-schemas** — Fix Mode 1 uniqueness wording, update Mode 2 schema patterns, confirm Mode 3 field name, add conformance note to story-planner, and ship verification.schema.json. Covers AC-STRUCT-1, AC-STRUCT-2, AC-STRUCT-3, AC-STRUCT-4, AC-STRUCT-5.

## Acceptance Criteria

See [`acceptance-criteria.md`](./acceptance-criteria.md).

## Relationship to Other Epics

- **epic-next-modes** — The three discrepancies were each surfaced during this epic's pre-implementation phase; this epic closes the loop.
- **epic-mode-3-verification-question-schema** (deferred) — That epic proposes renaming fields and aligning `verification.json` vocabulary more broadly; this epic only confirms Mode 3 consistency and ships the schema to lock the current shape.

## Non-Goals

- Runtime schema validation inside `base:feature` or `base:story-planner` — the conformance note in the prompt is sufficient for the near term.
- Migrating existing on-disk `stories.json` or `verification.json` files to any new format.
- Changing story ID format from S-prefix to numeric (schema follows code).
