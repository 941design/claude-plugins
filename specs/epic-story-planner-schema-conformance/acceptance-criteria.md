# Story Planner Mode Prompt / Schema Conformance — Acceptance Criteria

## Terminology

- **Rule 4** — the AC-ID uniqueness rule in `plugins/base/agents/story-planner.md ## AC Precision Rules`.
- **story.id** — the `id` field on each entry in `stories.json#stories[]`.
- **story_order** — the top-level `story_order` array in `stories.json`.
- **question record** — one entry in `verification.json#questions[]`.

## Reconcile Mode Prompts and Schemas (S1)

**AC-STRUCT-1** — `plugins/base/agents/story-planner.md` Rule 4 MUST state
that `<N>` is unique **within its tag** (not "within the AC file"); the phrase
"within the AC file" MUST NOT appear in Rule 4, and the phrase "within its tag"
MUST appear in Rule 4. Verified by two commands both returning the expected
result:
`grep -n "within the AC file" plugins/base/agents/story-planner.md` returning
empty; and
`grep -n "within its tag" plugins/base/agents/story-planner.md` returning at
least one match.

**AC-STRUCT-2** — `plugins/base/schemas/stories.schema.json` `story.id.pattern`
MUST be `^S[0-9]+$` (accepting "S1", "S2", etc.) and MUST NOT be `^[0-9]{2}$`.
Verified by:
`grep -Fc '"^S[0-9]+$"' plugins/base/schemas/stories.schema.json` returning a
count of at least 1 for the `story.id` pattern occurrence, and
`grep -Fc '"^[0-9]{2}$"' plugins/base/schemas/stories.schema.json` returning 0
after all pattern updates are applied.

**AC-STRUCT-3** — `plugins/base/schemas/stories.schema.json` `story_order`
array item pattern MUST be `^S[0-9]+$` and MUST NOT be `^[0-9]{2}$`. Verified
by the same commands as AC-STRUCT-2: after updating both occurrences (story.id
and story_order item), `grep -Fc '"^[0-9]{2}$"' plugins/base/schemas/stories.schema.json`
MUST return 0 (both old patterns replaced), and
`grep -Fc '"^S[0-9]+$"' plugins/base/schemas/stories.schema.json` MUST return
a count of at least 2 (one for story.id, one for story_order item).

**AC-STRUCT-4** — `plugins/base/agents/story-planner.md` Mode 3 "Question
record shape" section MUST contain a normative note stating that the field is
named `"category"` (not `"type"`); the note MUST NOT appear before the Mode 3
section. Verified by:
`grep -n 'not.*"type"' plugins/base/agents/story-planner.md` returning at least
one match whose line number falls after the line containing `"### Mode 3"`.

**AC-STRUCT-5** — `plugins/base/agents/story-planner.md` Validation Checks
section MUST contain a "Schema conformance" item that cites
`plugins/base/schemas/stories.schema.json` by path and the item MUST appear
after the line containing `## Validation Checks`. Verified by:
`grep -n "stories.schema.json" plugins/base/agents/story-planner.md` returning
at least one hit whose line number is greater than the line number of
`## Validation Checks`.

## Cross-Cutting Invariants

**AC-STRUCT-6** — `plugins/base/schemas/stories.schema.json` MUST remain valid
JSON after all edits. Verified by:
`python3 -m json.tool plugins/base/schemas/stories.schema.json > /dev/null`
returning exit code 0.

**AC-STRUCT-7** — If `plugins/base/schemas/verification.schema.json` is
created, it MUST be valid JSON, MUST require fields `question_id`, `phase`,
`category`, and `question` on each question record, and MUST NOT require
`ac_id` (it is optional on non-SPEC questions). Verified by:
`python3 -m json.tool plugins/base/schemas/verification.schema.json > /dev/null`
returning exit code 0; and `python3 -c "import json; s=json.load(open('plugins/base/schemas/verification.schema.json')); q=s['\$defs']['question']; assert 'ac_id' not in q['required'], 'ac_id must not be required'"` returning exit code 0.
