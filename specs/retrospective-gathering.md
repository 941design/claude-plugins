# /base:feature retrospective gathering — improvement proposals

Addressed to: maintainers of the `base:feature` skill, the
`base:retro-synthesizer` agent, and the four phase agents that emit
`RETROSPECTIVE:` blocks (`integration-architect`, `code-explorer`,
`story-planner`, `spec-validator`, `verification-examiner`, `pbt-dev`).

Source: the four retros currently on disk under
`~/.claude/plugins/data/base-941design/retros/`:

- `nomage/serpapi-brave-refactor-2026-05-09.md` — synthesizer output.
- `quizzl/feature-spec-unified-mls-application-rumor-dispatch-2026-05-08.md`
  — synthesizer output.
- `quizzl/meta-audit-2026-05-08-spec-trustworthiness-and-test-layering.md`
  — off-pattern, lead-curated.
- `shophop/feature-request-npub-display-in-settings-with-copy-qr-2026-05-08.md`
  — off-pattern, lead-curated.

Scope: this proposal addresses the **gathering layer** only (what
upstream agents emit, what the synthesizer renders). The `/feature`
workflow itself, the `retro_bundle` capture sites in `commands/feature.md`,
and the `result.json` schema are out of scope. Workflow-level findings
that *appeared inside* the four retros (epic-state.json trust, fast-path
artifact loss, e2e-tester stale paths, etc.) belong in a separate
proposal, not this one.

---

## 1. Per-story retros are populated even when there was no friction

**What happened.** Three of the four retros surface per-story entries
that recount implementation work without naming any actual friction:

- nomage S2: *"All acceptance criteria met. The `count_sentences` heuristic correctly handles 'Dr.' and 'vs.'…"*
- nomage S3: *"V2 migration adds three nullable TEXT columns… Existing tests updated to reflect new column counts. No regressions."*
- nomage S6: a paragraph listing files touched and what each architect already covered.

The architect prompt (`integration-architect.md` lines 138–168) cites
the global retro protocol verbatim ("Surface what made the work harder
than it needed to be… skip for routine or seamless tasks") and offers
three skip reasons (`routine`, `clean_run`, `trivial_change`). Despite
this, architects populate `harder_than_needed` because:

- The schema's `retrospective_populated` form requires `harder_than_needed` as `minLength: 1`. Once any field other than `skipped: true` is being written, this field must contain prose.
- The prompt does not name **negative examples** of what *not* to populate. It says "skip for routine," but the doer agent is in the middle of a multi-step task and tends to write *something* if the field is required.

The `surprised_by` field has the inverse problem — it is rendered
verbatim by the synthesizer even when the content is positive ("no
regressions," "all 7 verification questions resolved YES"). Positive
outcomes are not retro material.

**Proposed fixes (in priority order):**

1. *Tighten the architect prompt with negative examples.*
   In `plugins/base/agents/integration-architect.md` Step 7 (lines
   138–168), add:
   - Skip when: every AC passed first try, no remediation, no spec
     ambiguity, no surprises.
   - Skip when: the only thing you would write is "I edited the files
     the spec named."
   - Do **not** populate just to summarise what you did.
     `harder_than_needed` requires actual friction, not a recap.
   - `surprised_by` is for **negative or divergent** surprise only.
     Strip "no regressions," "clean solution," "all questions YES."

2. *Mirror the same tightening into `pbt-dev.md` (lines 70–76).*
   The architect absorbs pbt-dev retros, so the same skip threshold has
   to hold at the pbt-dev side or the architect inherits low-signal
   content via `absorbed_from`.

3. *Render `surprised_by` conditionally in the synthesizer template.*
   In `plugins/base/agents/retro-synthesizer.md` (lines 95–102 of the
   output template), drop the "What surprised" line entirely when
   `surprised_by` is empty, missing, or evaluates as positive (a small
   keyword filter is sufficient: "no regressions," "all YES," "clean,"
   "no friction").

---

## 2. The "Pre-implementation phase findings" section reproduces factual outputs as friction signals

**What happened.** The synthesizer's `## Pre-implementation phase
findings` section (template lines 109–119) renders verbatim flags from
`code-explorer`, `story-planner`, and `spec-validator`. In the actual
corpus those agents flag *factual exploration outputs*, not friction:

- nomage code-explorer (focus: architecture):
  *"build_system_prompt does NOT exist; SYSTEM loaded via include_str!;
  module boundaries clean; tool dispatch at harness.rs:189-237; DB row
  structs store JSON-serialized strings."*
- nomage story-planner Mode 3:
  *"42 total questions (21 SPEC + 13 BEHAVIORAL + 4 CONTRACT + 2
  EDGE_CASE); S6 spec-amendment questions treated as BEHAVIORAL not
  SPEC."*

These are descriptions of what the agent *produced*, not signals about
what was hard. They belong in `exploration.json`, the planner's normal
return, or `verification.json` — not in the retrospective.

The corresponding flags in `quizzl/dispatch` are higher-quality
because they describe **mismatches** ("the ChatStoreContext comment is
factually wrong per the marmot-ts source"). The agent prompts do not
distinguish these two shapes.

**Proposed fix.** In each of the four phase-agent prompts, add a
negative-example list and tighten the trigger:

- `plugins/base/agents/code-explorer.md` lines 58–73
- `plugins/base/agents/story-planner.md` lines 153–157
- `plugins/base/agents/spec-validator.md` lines 83–90
- `plugins/base/agents/verification-examiner.md` lines 117–123

Per agent, add:

> Do **not** flag to report what you found, what you produced, or how
> you classified your output. Those go in your normal return payload
> (`exploration.json`, `architecture.md`, `verification.json`, the
> stories.json deliverable).
>
> Flag only when:
> - The spec, code, or third-party library *disagreed with itself* in a
>   way that downstream stories will inherit.
> - The *process* of doing this phase hit friction the synthesizer
>   should know about (e.g. ambiguous AC wording forced a clarification
>   round; the schema you were asked to fill is missing a field; a
>   third-party API behaves differently from how the spec describes
>   it).
>
> Positive examples (good flags):
> - code-explorer: *"The spec says marmot-ts re-delivers own-send events;
>   reading the library source shows they are silently dropped at
>   `#sentEventIds`. Downstream stories that defend against own-echo
>   will be dead code."*
> - story-planner: *"AC-AR-3 spans two stories; the story schema cannot
>   express partial satisfaction natively, forcing duplicate AC IDs."*
> - spec-validator: *"§7 says X; §12 says X-modulo-Y. I picked X but
>   that is a guess."*
> - verification-examiner: *"VQ-S2-005 asks 'is X covered?' but X has
>   two valid implementations and the AC names neither — verifying
>   either reading is equally defensible."*

---

## 3. Synthesizer output does not partition Meta-level vs Project-specific findings

**What happened.** Every retro shape in the gathering pipeline already
carries a `scope: project_specific | meta` field — present on every
non-architect agent's `RETROSPECTIVE:` block, and on the architect's
populated retro form. The synthesizer template (lines 76–145) does
**not** route on this field; it groups by *source phase* instead
(per-story / pre-impl / verification / epic-meta).

This conflicts with the user-level global retro guideline (in
`~/.claude/CLAUDE.md`), which directs:

> Project-specific findings → save to project memory or add a code
> comment. Don't ask first.
> Meta-level findings (pipeline, agent design, global setup, tooling)
> → always raise to me. These are the ones I act on.

The off-pattern retros (`shophop`, `quizzl/meta-audit`) honour this
split explicitly — `shophop` has a top-level "Meta-level (raise to
user)" section and a "Project-specific (saved to memory)" section. The
synthesized retros do not.

**Proposed fix.** In `plugins/base/agents/retro-synthesizer.md` output
template, replace the four phase-grouped sections with a Meta-vs-Project
partition:

```
## Meta-level findings (raise to user)
### Per-story
### Pre-implementation phase
### Verification phase
### Lead's epic-meta

## Project-specific findings (route to project memory)
### Per-story
### Pre-implementation phase
### Verification phase
### Lead's epic-meta
```

Source `scope` field drives placement. Within each partition, sub-sections
that have no content are omitted (the existing "section omission, not
empty headers" rule at lines 149–151 is preserved).

---

## 4. Meta-level findings without a concrete suggested change clutter the output

**What happened.** The current synthesizer prompt (lines 137–139, 155–157)
makes the "Suggested harness change" optional and explicitly bars filler
("'Consider improving X' is not a suggestion; it is filler. Skip it
rather than write it"). This is correct in spirit but produces an
asymmetric outcome: a Meta finding without a suggestion still surfaces
to the user, but the user has no concrete edit to act on.

The off-pattern retros invert this. `shophop` and `quizzl/meta-audit`
both pair every Meta finding with a "Pipeline implication" or
"Suggested harness change" — and both produce findings the user can act
on without further triage.

**Proposed fix.** In `retro-synthesizer.md`:

> A Meta-level finding **must** include a concrete suggested change
> (specific prompt edit, schema field, workflow step, or invariant).
> If you cannot name one, demote the finding to Project-specific.
> The synthesizer is allowed to demote unilaterally; it does not need
> the doer's permission to recategorise.

This makes the Meta partition an "actionable items" list and routes
non-actionable observations to the Project partition (where they
become memory notes, not user asks).

---

## 5. Synthesizer has no way to capture validated approaches ("what worked")

**What happened.** The `shophop` retro begins with a `## What worked`
section (spec quality, parallel-safe story split, pattern reuse). The
global retro guideline directs that successes should be recorded
alongside frictions — *"Record from failure AND success: if you only
save corrections, you will avoid past mistakes but drift away from
approaches the user has already validated"*. The synthesizer template
has no equivalent section.

**Proposed fix.** Add an opt-in `## What worked` section to the
synthesizer template, populated only when at least one source retro
(architect `surprised_by` field, code-explorer flag, lead epic-meta
notes) contains explicit positive workflow feedback. Verbatim,
attributed. The strict NO_RETRO floor at lines 32–41 still skips the
entire document for friction-free runs; this section is for runs that
have both friction and validated approaches worth keeping.

---

## 6. Discrepancy detection works but is structurally invisible

**What happened.** The `nomage` synthesized retro correctly surfaces
the S4 discrepancy (architect emitted `verification.json` but no
`result.json`, so no doer prose retro exists for the largest story).
The lead's discrepancy detection in `commands/feature.md` line 298
catches the inverse case (`skipped: true` + `remediation_rounds > 0`)
but not the "no `result.json` at all" case.

**Proposed fix.** Out of scope for this proposal — extending the
discrepancy check is workflow-layer, not gathering-layer. Recorded here
for the next round.

---

## Summary of proposed changes

| #  | Change                                                                  | Location                                            | Effort |
|----|-------------------------------------------------------------------------|-----------------------------------------------------|--------|
| 1a | Add negative examples to architect skip threshold                       | `agents/integration-architect.md` lines 138–168     | Low    |
| 1b | Mirror skip tightening into pbt-dev                                     | `agents/pbt-dev.md` lines 70–76                     | Low    |
| 1c | Conditionally drop empty/positive `surprised_by` lines                  | `agents/retro-synthesizer.md` template              | Low    |
| 2  | Tighten phase-agent flag prompts with negative + positive examples      | `code-explorer.md`, `story-planner.md`, `spec-validator.md`, `verification-examiner.md` | Low |
| 3  | Partition synthesizer output into Meta-level vs Project-specific        | `agents/retro-synthesizer.md` output template       | Low    |
| 4  | Require concrete suggested change for Meta-level findings; demote else  | `agents/retro-synthesizer.md` hard rules            | Low    |
| 5  | Optional `## What worked` section in synthesizer template               | `agents/retro-synthesizer.md` output template       | Low    |
| 6  | (Deferred — workflow-layer)                                             | `commands/feature.md`                               | —      |

All changes are prompt-text edits to existing files. No schema changes,
no workflow changes, no new files, no version bumps.

## Verification

This is a prompt-quality change; verification is observational.

1. *Static read-through.* After edits, re-read each modified prompt and
   confirm: (a) at least one negative example is named, (b) at least
   one positive example is named, (c) the existing `RETROSPECTIVE:`
   block / `result.json#retrospective` contract is intact (every
   previously valid emission shape is still valid).

2. *Replay against existing retros.* Walk through each of the four
   on-disk retros and predict the output under the new template:
   - **nomage**: S2 and S3 per-story entries drop entirely. The two
     epic-meta themes survive in the Meta partition (both have concrete
     suggested changes). The current "Pre-implementation phase
     findings" header disappears; the story-planner Mode 3 line is
     filtered out as a factual output and never makes it into the retro
     under the new explorer/planner prompts. The S4 discrepancy
     survives.
   - **quizzl/dispatch**: S1 per-story entry survives but the
     vi.mock+dynamic-import paragraph is trimmed to the friction core
     ("test framework execution semantics diverge from production"). All
     three Lead epic-meta findings survive in the Meta partition (each
     already has a concrete suggested change). The explorer flag about
     `ChatStoreContext` is recategorised under Meta.
   - **shophop** and **quizzl/meta-audit**: untouched (off-pattern,
     not synthesizer output).

3. *Live trial.* On the next `/feature` run, compare the new
   synthesizer output against the prior shape. Acceptance criteria:
   - Zero "all ACs met" / "no regressions" filler in per-story entries.
   - Every finding under `## Meta-level findings (raise to user)` has a
     concrete `Suggested change` line.
   - Phase findings that are factual exploration outputs (not
     friction) do not appear at all.
   - Discrepancy section behaviour is unchanged.

If a real run produces a Meta-level finding that legitimately lacks a
suggested change and was demoted to Project-specific, that is a signal
to revisit proposal 4 (the demote-on-no-suggestion rule may be too
strict).
