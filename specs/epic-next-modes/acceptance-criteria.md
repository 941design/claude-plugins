# /base:next — Detail and Auto Modes — Acceptance Criteria

## Terminology

- **detail mode** — The default invocation mode of `/base:next` (bare invocation, no argument). Renders a prose paragraph per actionable finding candidate before asking the user which to dispatch. Active whenever `mode == detail` in Step 0's output.
- **auto mode** — The opt-in invocation mode of `/base:next auto`. Dispatches the document-order top actionable finding without any prompt or paragraph synthesis. Active whenever `mode == auto` in Step 0's output.
- **actionable finding** — A bullet entry in `BACKLOG.md ## Findings` that is classified as `bug` or `feature-work` (not `question`). The set of actionable findings is determined by Step 3 of `plugins/base/commands/next.md`; document order is preserved.
- **question-halt** — The behavior, unchanged from the pre-existing Step 3, by which a leading `question` finding stops the dispatcher and emits a resolution-paths nudge instead of dispatching. Applies in both modes; neither mode auto-skips a `question` finding.
- **paragraph synthesis** — The inline routine (Step 4a) that reads an anchor file ±10 lines and composes a 3–5 sentence what / where / goal summary for a single finding candidate. Executed by the lead agent; no subagent is spawned.
- **anchor file** — The file referenced in a finding bullet's `path:line` or `path` anchor field. When the anchor is `-` or the file cannot be read for any reason, the paragraph falls back to bullet-text-only composition.
- **`(anchor file missing)`** — The fixed literal string appended to a synthesised paragraph whenever the anchor file read fails for any reason (file not found, directory not found, permission denied, glob characters in path, ambiguous path). The string is verbatim with no variation by failure mode.

---

## Mode Argument Parsing (S1)

**AC-MODE-1** — When `plugins/base/commands/next.md` Step 0 receives an empty `$ARGUMENTS` (bare invocation), Step 0 MUST set `mode = detail` and proceed to Step 1 without exiting.

**AC-MODE-2** — When `plugins/base/commands/next.md` Step 0 receives the single token `auto` (case-sensitive, exact match), Step 0 MUST set `mode = auto` and proceed to Step 1 without exiting.

**AC-MODE-3** — When `plugins/base/commands/next.md` Step 0 receives any token other than `auto` (including whitespace-padded variants, flags such as `--auto`, or unrecognised strings), Step 0 MUST exit immediately with a usage hint that names both valid invocation forms: `/base:next` (detail mode) and `/base:next auto` (auto mode). Step 0 MUST NOT proceed to Step 1 when this branch is taken.

**AC-STRUCT-1** — The YAML frontmatter block of `plugins/base/commands/next.md` MUST contain all of the following after S1 is applied:
- `argument-hint` field set to the value `"(no args = detail) | auto"` (verbatim).
- `description` field whose prose mentions both "detail" and "auto" modes (or an equivalent two-mode phrasing).
- `allowed-tools` value that includes `Grep` in addition to the tools already listed (`Read`, `Edit`, `Bash`, `AskUserQuestion`, `Skill`).

---

## Auto-Mode Silent Dispatch (S2)

**AC-AUTO-1** — When `mode == auto`, `plugins/base/commands/next.md` Step 4 MUST NOT invoke `AskUserQuestion` at any point before falling through to Step 5. No confirmation prompt is presented to the user.

**AC-AUTO-2** — When `mode == auto`, Step 4 MUST print exactly one notice line of the form `Dispatching as <classification>: <truncated-bullet>` before falling through to Step 5, where `<classification>` is `bug` or `feature-work` and `<truncated-bullet>` is a non-empty excerpt of the selected finding's bullet text. The file `plugins/base/commands/next.md` MUST contain a prose or pseudocode clause describing this one-line notice output in the `auto` branch of Step 4.

**AC-AUTO-3** — When `mode == auto`, the candidate selected for dispatch MUST be the first actionable finding in document order from `BACKLOG.md ## Findings` (the same candidate that Step 3 classifies as position 1). `plugins/base/commands/next.md` Step 4's `auto` branch MUST name this selection rule explicitly (e.g. "the first actionable in document order" or equivalent).

---

## Detail-Mode Rendering and Paragraph Synthesis (S3)

**AC-DETAIL-1** — When `mode == detail`, `plugins/base/commands/next.md` Step 4 MUST render up to three actionable findings to the user in the following format (or a structurally equivalent form documented in the step body):

```
## Top 3 actionable findings

**1.** <anchor> → <classification>
      <paragraph>

**2.** <anchor> → <classification>
      <paragraph>

**3.** <anchor> → <classification>
      <paragraph>
```

Each candidate entry MUST include the anchor reference, the classification label (`bug` or `feature-work`), and the synthesised paragraph. `plugins/base/commands/next.md` MUST contain a prose or pseudocode rendering template for this structure within the `detail` branch of Step 4.

**AC-DETAIL-2** — When `mode == detail`, Step 4 MUST invoke `AskUserQuestion` with options that include:
- `Dispatch #1` (always present when at least one actionable finding exists).
- `Dispatch #2` (present only when a second actionable finding exists).
- `Dispatch #3` (present only when a third actionable finding exists).
- `Abort` (always present).

`plugins/base/commands/next.md` MUST document the conditional inclusion rule for options 2 and 3 (i.e. "only when #2 exists", "only when #3 exists") within the `detail` branch of Step 4.

**AC-DETAIL-3** — When `mode == detail` and exactly one actionable finding exists, Step 4 MUST still synthesise a paragraph for that finding and present the `AskUserQuestion` confirmation prompt (containing at minimum `Dispatch #1` and `Abort`) before dispatching. `plugins/base/commands/next.md` MUST NOT contain a special-case branch that skips synthesis or the prompt for the single-finding scenario within `detail` mode.

**AC-PARA-1** — `plugins/base/commands/next.md` Step 4a MUST specify the anchor-file read window using the explicit arithmetic `offset = max(1, line - 10)`, `limit = 21` for the `path:line` anchor form. Both the `max(1, line - 10)` expression and the value `21` MUST appear verbatim (or as equivalent unambiguous arithmetic) in the Step 4a prose or pseudocode.

**AC-PARA-2** — When the anchor file read in Step 4a fails for any reason (file not found, directory not found, permission denied, anchor path containing glob characters, ambiguous path), Step 4a MUST fall back to bullet-text-only paragraph composition and MUST append the literal string `(anchor file missing)` to the resulting paragraph. The string `(anchor file missing)` MUST appear verbatim in `plugins/base/commands/next.md` Step 4a as the designated fallback note text.

**AC-PARA-3** — `plugins/base/commands/next.md` Step 4a MUST specify that the synthesised paragraph covers three topics: (a) what the issue or opportunity is, (b) where the relevant code lives (named file, section, or function), and (c) what goal resolving the finding accomplishes for the user or system. Step 4a MUST specify that the paragraph is 3–5 sentences in length. Both the three-topic requirement and the sentence-count bound MUST appear in the Step 4a prose.

---

## Amend epic-base-next (S4)

**AC-AMEND-1** — `specs/epic-base-next/acceptance-criteria.md` MUST contain the following three AC patches applied verbatim (or in a form that preserves the exact meaning of each clause):

1. AC-NEXT-2 MUST include: "MUST accept either no argument (interpreted as `detail` mode) or the literal token `auto` (interpreted as `auto` mode). MUST exit with a usage hint on any other argument. The `argument-hint` frontmatter field MUST be updated to reflect this two-mode grammar."
2. AC-NEXT-9 MUST be mode-conditional: in `auto` mode the silent-dispatch rule applies for any actionable count; in `detail` mode the dispatcher MUST render a paragraph and confirm regardless of count.
3. AC-NEXT-10 MUST be split into AC-NEXT-10a (detail-mode rendering contract: top-3 paragraphs, classification labels, three conditional choice options) and AC-NEXT-10b (auto-mode dispatch contract: skip prompt entirely, fall through to Step 5 with the document-order top candidate).

**AC-AMEND-2** — `specs/epic-base-next/spec.md` MUST contain a `## Amendments` section with an entry dated `2026-05-12` that references this epic (`epic-next-modes`), names AC-NEXT-2, AC-NEXT-9, and AC-NEXT-10 as the amended ACs, and cites the source finding at `plugins/base/commands/next.md:93-115`.

---

## Cross-Cutting Invariants

**AC-INV-1** — In both `detail` mode and `auto` mode, when the first actionable candidate returned by Step 3 is classified as `question`, `plugins/base/commands/next.md` MUST halt the dispatcher and emit the resolution-paths nudge without dispatching. Neither `detail` mode nor `auto` mode MUST auto-skip a leading `question` finding. `plugins/base/commands/next.md` MUST preserve the question-halt logic at or before the Step 4 branching point, so that it applies regardless of which mode branch executes.

---

## Manual Validation

- **Paragraph prose quality** — After implementation, a human reviewer MUST read at least two synthesised paragraphs (one with a reachable anchor file, one with a missing anchor file) and confirm that each paragraph is coherent, self-contained (understandable without the raw bullet), and covers what / where / goal. This is not assertable by Read-based textual inspection; it requires a human evaluator or a live invocation of `/base:next`.
