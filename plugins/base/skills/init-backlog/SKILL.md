---
name: init-backlog
description: >-
  Scaffolds a project's `BACKLOG.md` (the project-level meta-state file consumed
  by `/base:orient` and `base:project-curator`) and adds a one-line pointer to
  the project's `CLAUDE.md` so the file is discoverable in every session. Use
  when a repository has no `BACKLOG.md` yet, when `/base:orient` reports the
  pointer is missing, or when first adopting the base plugin's project-wide
  coordination conventions on an existing repo.
user-invocable: true
argument-hint: "(no arguments)"
allowed-tools: Read, Write, Edit, Bash
---

## Purpose

Bootstraps two artifacts:

1. **`BACKLOG.md`** at the repository root — the project-level coordination
   surface. See the template at `${CLAUDE_SKILL_DIR}/BACKLOG-template.md` for
   the canonical format and the four-artifact taxonomy
   (`Epics` / `Findings` / `Archive`, plus `docs/adr/`).

2. **A one-line pointer in `CLAUDE.md`** so any session has the file's
   existence loaded into context without bloating `CLAUDE.md` itself.

The `BACKLOG.md` template is intentionally near-empty. This skill does not
generate any project-specific content — it only puts the right structure in
place.

## Operation

This skill is **idempotent** — running it on an already-initialised repo
is safe. Each substep checks its own precondition independently so the
skill can repair partial state (e.g. BACKLOG.md present but the
CLAUDE.md pointer missing, or vice versa).

```
1. Detect repo root (`git rev-parse --show-toplevel`). Refuse outside a git
   repo — BACKLOG.md is project state and belongs in version control.

2. Scaffold BACKLOG.md if missing.
     - If `<root>/BACKLOG.md` does NOT exist:
         a. Copy `${CLAUDE_SKILL_DIR}/BACKLOG-template.md` to `<root>/BACKLOG.md`.
         b. Run the one-shot seeding pass below (substep 3).
     - If it exists: do not overwrite. Skip 3a/3b but continue to 4.

3. Seed `## Epics` from existing `specs/epic-*/` directories
   (one-shot, only when this skill just created BACKLOG.md in step 2):
     - Find every `specs/epic-*/` directory.
     - For each, read `epic-state.json` and emit one bullet under
       `## Epics`:
         `- specs/epic-<slug>/ — <STATUS> — seeded by /base:init-backlog YYYY-MM-DD`
       where `<STATUS>` derives from `epic-state.json#status`:
       `planning|in_progress` → `IN_PROGRESS`; `done` → `DONE`;
       `escalated` → `ESCALATED`. If `epic-state.json` is missing or
       malformed, write `UNKNOWN` and surface the dir in the final
       report so the user can investigate.
     - Replace the template's `_no epics yet_` line with the seeded
       bullets. If no spec dirs exist, leave the placeholder as-is.

4. Add the CLAUDE.md pointer if missing.
     - Read `<root>/CLAUDE.md` (create if missing — start with a minimal stub).
     - If the literal string `BACKLOG.md` is NOT already present in the
       file (cheap grep), append the pointer line below to the end:

           ## Project state
           Project orientation lives in `BACKLOG.md`. On a fresh session — or when
           resuming work after idle time — run `/base:orient` to get a 3-line
           "you are here" plus ranked next moves. Do not inline backlog content
           into this file.

     - If `BACKLOG.md` already appears anywhere in CLAUDE.md, leave it
       alone. (Do NOT verify the surrounding prose — the user may have
       customised the wording, which is fine.)

5. Report what was done in 1–3 lines, distinguishing the four idempotent
   outcomes:
     - "Initialized: created BACKLOG.md (seeded N epics) + CLAUDE.md pointer."
     - "Repaired: BACKLOG.md was present; added missing CLAUDE.md pointer."
     - "Repaired: CLAUDE.md pointer was present; created BACKLOG.md (seeded N epics)."
     - "Already initialised: nothing to do."
   When epics were seeded, end with: "Run `/base:orient` to triage."
```

## Why a skill, not a one-shot bash script

The pointer line in `CLAUDE.md` is load-bearing for the discoverability of
the entire project-state mechanism. Putting the scaffolding in a skill keeps
the convention single-sourced: when the pointer wording changes, this skill
is the authority.

## Non-goals

- Does not migrate existing backlog-shaped files (`TODO.md`, `TODO.org`,
  `BACKLOG.txt`, etc.). If one exists, surface it and let the user decide.
- Does not populate `## Findings` or `## Archive`. Those sections start
  empty; the curator and the user populate them as work proceeds. (The
  one-shot `## Epics` seeding pass in step 3 above is the *only*
  content-generation behaviour, and only because existing
  `specs/epic-*/` dirs are facts on disk, not invented material.)
- Does not create `docs/adr/`. The first ADR (whether via `/base:adr` or
  `base:arch-debate`) creates that directory.
