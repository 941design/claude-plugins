# Mode-1 Story-Planner Should Require Reconciliation Against Exploration Findings

## Problem

Mode-1 story-planner finalizes ACs without verifying that the artifacts those ACs reference actually exist in the codebase. In epic-base-next, AC-MANIFEST-1 pointed at commands listings in `plugin.json` and `marketplace.json` that were already flagged as absent by the codebase explorer — but the AC was not updated before implementation began, causing downstream confusion.

Source: BACKLOG.md finding promoted 2026-05-14

## Solution

<!--
What we are going to do, at the level of intent. Not implementation
detail — that lives in `## Technical Approach` below.
-->

## Scope

### In Scope

- <!-- bullet list of work items this epic will deliver -->

### Out of Scope

- <!-- items deferred to other epics; distinct from Non-Goals below -->

## Design Decisions

<!--
Numbered list. State each decision and its rationale, with file:line
refs where useful.
-->

1. **<Decision>** — <rationale>. Refs: `path/to/file:NN`.

## Technical Approach

### `plugins/base/agents/story-planner.md`

Add a Mode-1 reconciliation step that cross-checks every AC's referenced artifact (file paths, manifest keys, config entries) against the findings in `exploration.json`, flagging any AC that references an artifact the explorer identified as absent or non-existent.

## Stories

- **S1 — <name>** — <one-line description>. Covers AC-<TAG>-N, …

## Acceptance Criteria

See [`acceptance-criteria.md`](./acceptance-criteria.md).

## Relationship to Other Epics

- <!-- epic-<slug> — one sentence on how the two relate -->

## Non-Goals

- <!-- bullet -->
