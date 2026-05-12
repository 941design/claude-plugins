# Pipeline-Autonomous Retros

## Problem

The base plugin's `/feature` and `/bug` wrap-up workflows present curator proposals to the user via interactive `AskUserQuestion` prompts, requiring manual adjudication of every finding, rejection, and amendment before the conversation ends. This defeats the purpose of an autonomous pipeline: the user must be present and attentive at wrap-up time, decisions are lost if the session ends before adjudication, and pipeline-level findings (targeting base plugin agents/skills) get filed into the *consumer project's* backlog instead of this repo's backlog.

No mechanism exists to process the historical back-catalogue of pipeline retros stored at `${CLAUDE_PLUGIN_DATA}/retros/<plugin>/` and derive action items from them into this repo's `BACKLOG.md`. Retro files have no record of what happened to their findings after synthesis.

## Solution

1. **Curator autonomous mode** — the curator writes decisions directly (no `AskUserQuestion`). It gains an `annotate_retro` action that marks each finding with its disposition in the source retro markdown, enabling dedup on subsequent runs. Plugin-scope findings (targeting `plugins/base/`, `base:*`, `/base:*` paths) are deferred to `retros-derive` rather than filed in the consumer project's backlog. The cap-5 proposal limit is removed.

2. **Command wrap-up edits** — `commands/feature.md` Step 6.3 and `commands/bug.md` Step 4 replace interactive adjudication with direct decision application. The report step shrinks to file-path + counts only.

3. **`/base:retros-derive` command** — walks `${CLAUDE_PLUGIN_DATA}/retros/<plugin>/*.md`, extracts un-annotated meta-level findings, and runs the autonomous curator against this repo's `BACKLOG.md`. Retro files are annotated in place. Oldest-first processing so canonical bullets land before recurrence markers.

4. **ADR `Status: Proposed`** — the `base:adr` skill gains a `proposed` argument flag so the autonomous curator can scaffold ADRs without immediately marking them `Accepted`.

## Pre-implementation note

The retro-synthesizer's Meta-vs-Project partition (proposal #3 from `specs/retrospective-gathering.md`) is **already implemented** in `plugins/base/agents/retro-synthesizer.md` Hard Rules 4-5 and the output template. No synthesizer changes are needed.

## In Scope

- `plugins/base/agents/project-curator.md` — full refactor
- `plugins/base/commands/feature.md` — Step 6.3 and Step 6.5
- `plugins/base/commands/bug.md` — Step 4 curator section
- `plugins/base/commands/retros-derive.md` — new file (~60 lines)
- `plugins/base/skills/adr/SKILL.md` — add `proposed` flag
- `plugins/base/skills/adr/ADR-template.md` — document `Proposed` status variant

## Out of Scope

- `~/.claude/CLAUDE.md` (user adds the override clause themselves)
- `retro-synthesizer.md` / `bug-retro-synthesizer.md` (already correct)
- Version bumps
- Ledger files, JSON sidecars, schema changes
- Scheduling or cron setup

## Technical Approach

### Annotation format

A single italic line appended under the finding's `**Suggested change**:` line:

```
_Curator: YYYY-MM-DD → BACKLOG#finding-marker_
_Curator: YYYY-MM-DD → DUPLICATE of finding-2026-04-15-examiner-scope (recurrence ×3)_
_Curator: YYYY-MM-DD → DEFERRED to /base:retros-derive_
_Curator: YYYY-MM-DD → NO_ACTION (no concrete suggested change after demotion)_
_Curator: YYYY-MM-DD → ADR-007_
_Curator: YYYY-MM-DD → ARCHIVE_
```

Any line matching `_Curator: .*_` is the dedup guard: the curator skips findings with such a line present.

### Plugin-scope exclusion heuristic

A finding is plugin-scoped when `scope: meta` AND the `**Suggested change**:` text contains any of: `plugins/base/`, `` `base: ``, `/base:`, or agent/skill/command names from the base plugin vocabulary (`integration-architect`, `code-explorer`, `story-planner`, `spec-validator`, `verification-examiner`, `pbt-dev`, `retro-synthesizer`, `bug-retro-synthesizer`, `project-curator`, `feature.md`, `bug.md`, `retros-derive`, `result.json`, `epic-state.json`, `stories.json`, `verification.json`).

### Recurrence tracking

When the curator would file a finding that duplicates an existing `BACKLOG.md ## Findings` bullet (same normalized target token), it instead: (a) appends a recurrence line to the existing bullet (e.g. `recurred ×3 (2026-04-15, 2026-05-01, 2026-05-12)`), and (b) annotates the retro as DUPLICATE. Oldest-first processing in `retros-derive` ensures the first-seen occurrence becomes canonical.

### retros-derive section-matching priority

1. `## Meta-level findings (raise to user)`
2. `## Lead's epic-meta findings`
3. `## Workflow-level findings`
4. `### Meta-level (raise to user)`
5. `## Frictions worth recording`
6. Fallback: any paragraph containing `**Suggested change**:` not already under a `## Project-specific` or `## Routine` header

## Design Decisions

No interactive prompts in the retro gather path — user intent flows through `BACKLOG.md`. Planning-phase interactions (`AskUserQuestion` in Step 1/2/4 and Mode 3 story-planner questions, escalation prompts) are explicitly preserved; only the wrap-up curator path and the derive skill are autonomous.

## Amendments
