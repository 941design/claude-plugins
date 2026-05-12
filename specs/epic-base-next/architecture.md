# Architecture: /base:next — Backlog Auto-Dispatch

## Paradigm

This epic makes changes exclusively to markdown plugin definition files (`.md`).
There is no compiled code, no runtime binary, and no test suite. "Implementation"
means: write the correct markdown text in the correct file. Verification means:
grep for required sections, validate YAML frontmatter field presence, and confirm
prose matches the spec's step outline.

The repo uses a flat-file command discovery model: any `.md` file placed in
`plugins/base/commands/` with valid YAML frontmatter is auto-registered as
`/base:<name>`. No manifest registration is required.

## Module Map

| Module | Purpose | Location |
|--------|---------|---------|
| `next.md` | New dispatcher command | `plugins/base/commands/next.md` |
| `bug.md` | Existing bug-fix command; gains `backlog:<marker>` mode | `plugins/base/commands/bug.md` |
| `orient SKILL.md` | Existing orient skill; gains `/base:next` cross-reference | `plugins/base/skills/orient/SKILL.md` |

No new directories, no new agents, no manifest changes are required for this epic.

## Boundary Rules

Each module is a self-contained markdown file. Changes are additive or insertional:
- `next.md` — created from scratch; no other file imports or depends on it at write time.
- `bug.md` — two insertion points: (1) new `ELSE IF` branch in Step 1 input-mode
  detection; (2) deferred bullet-removal block after Step 4's state-file write.
  All other sections unchanged.
- `orient SKILL.md` — one insertion point: append a `/base:next` suggestion line to
  the Rule 8 findings-ready-to-promote block. All other sections unchanged.

## Seams

No cross-story dependencies. Each story touches a single file. Stories can be
implemented and verified independently.

## Implementation Constraints

- **Frontmatter**: `next.md` MUST declare all five fields: `name: next`,
  `description`, `argument-hint: (no arguments)`, `allowed-tools` (must include
  `Read`, `Edit`, `Bash`, `AskUserQuestion`, `Skill`), `model: sonnet`.
- **Model choice for next.md**: `sonnet` (orchestration/dispatch, not
  diagnosis; consistent with feature.md and implement-full.md).
- **No version bumps**: CLAUDE.md forbids manual version bumps. The release script
  handles this separately.
- **Deferred removal atomicity**: The BACKLOG_PROMOTE mode in `bug.md` MUST NOT
  remove the source bullet until after `bug-reports/{slug}-result.json` is written.
  This mirrors `feature.md:75` and `feature.md:248-262`.
- **in-session variable naming**: `pending_finding_removal` (matches feature.md
  convention); do NOT rename.
- **Orient cross-reference is additive only**: The Rule 8 block may only gain a
  new line; existing Rule 8 prose must not change.
- **No new bug-report directory layout**: `bug.md`'s BACKLOG_PROMOTE mode writes
  `bug-reports/{slug}-report.md` using the same path convention as the
  existing free-text mode.

## Step-Outline Reference for `next.md`

Authoritative step outline is at `specs/epic-base-next/spec.md` Technical Approach
section (`next.md` step outline). Summary for implementer convenience:

1. Read `BACKLOG.md`; exit with hint if missing.
2. Parse `## Findings`; exit with hint if empty/absent/placeholder.
3. Filter and pick: document-order walk; halt on leading `[question]`; abort on
   non-canonical type; select first actionable (`bug|chore|observation`).
4. Confirmation gate: show top-3 via AskUserQuestion if ≥2 actionable; skip if exactly 1.
5. Derive unique marker: prefer anchor path; fall back to first 4-6 text words; extend until unique.
6. Dispatch: `[bug]` → `Skill("base:bug", args: "backlog:<marker>")`; `[chore]|[observation]` → `Skill("base:feature", args: "backlog:<marker>")`.
7. Return after target Skill completes.

## BACKLOG_PROMOTE Insertion Points in `bug.md`

See `exploration.json` focus: similar-features.

- **Branch insertion**: after line 45 of bug.md (before existing `ELSE` at line 46)
- **Deferred removal insertion**: after line 265 of bug.md (after state-file update,
  before parallel synthesizer/curator spawn)

These line numbers reflect the file at the time of exploration (2026-05-12).
The implementer must read the file first to confirm exact insertion points.
