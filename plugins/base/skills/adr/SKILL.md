---
name: adr
description: >-
  Scaffolds a lightweight Architecture Decision Record at `docs/adr/ADR-NNN-<slug>.md`
  using the next available ADR number. Use for cross-spec decisions, supersession events,
  or codifying a cluster of related rejections from `BACKLOG.json#archive[]` (the
  project-curator and `/base:orient` may propose this). For heavyweight architecture
  work that warrants a structured Proposer↔Codex debate, use `base:arch-debate` instead —
  it produces an ADR of `Type: Debated` plus an `architecture.md`.
user-invocable: true
argument-hint: "<title> [affects:<comma-separated-paths>] [supersedes:ADR-NNN] [from-archive:<comma-separated-archive-markers>] [proposed]"
allowed-tools: Read, Write, Edit, Bash
---

## Purpose

ADRs and specs answer different questions:

| Artifact | Reader question | Lifecycle |
|---|---|---|
| `specs/epic-*/` | "What does this do?" | Living, amended |
| `docs/adr/` | "Why this shape?" | Immutable once Accepted; superseded, never rewritten |

Decisions go inline in a spec when they are local to one epic. Decisions
go in an ADR when they (a) span multiple specs, (b) supersede a prior
decision, or (c) codify a pattern of repeated rejections worth
enshrining. The threshold test: **does this decision belong to "the
system" or to "this feature"?** System → ADR. Feature → spec.

This skill is the **lightweight** path: no debate, no orchestration —
just the scaffold + the right number + a stub the user fills in.

## Operation

```
1. Detect repo root. Refuse outside a git repo (ADRs are project state).

2. Determine N: count existing files matching `docs/adr/ADR-*.md`,
   then N = count + 1. Format as 3-digit zero-padded (e.g. ADR-007).
   Create `docs/adr/` if it does not exist.

3. Parse $ARGUMENTS:
     - Required: <title>. Used to derive `<slug>` (kebab-case,
       lowercase, alphanumeric + hyphens only).
     - Optional `affects:<comma-separated-paths>` — pre-fills the
       `Affects:` header and triggers spec cross-reference propagation
       (Step 6 below). Each path may be a spec dir
       (`specs/epic-foo/`), a single spec file
       (`specs/epic-foo/spec.md`), or the literal string
       `project-wide`.
     - Optional `supersedes:ADR-NNN` — populates `Supersedes:` header
       and adds a `References` line.
     - Optional `from-archive:<marker>[,<marker>,...]` — one or more
       comma-separated substrings, each identifying one or more
       `BACKLOG.json#archive[]` entries (the multi-marker form is what
       `base:project-curator`'s `promote_rejections_to_adr` proposal
       passes — every marker in the cluster the curator identified must
       be applied so the ADR's evidence base is complete). Read
       BACKLOG.json, match each marker independently against `## Archive`
       entries, embed every matched entry verbatim under `## Context`
       (deduplicated if the same entry matches multiple markers),
       and stage a follow-up note to the user: after the ADR is
       Accepted, those archive lines should get a `[→ ADR-NNN]` pointer
       (the user does this; this skill does not edit BACKLOG.json).
     - Optional `proposed` — when present, the scaffolded ADR is written
       with `Status: Proposed` instead of `Status: Accepted`. Use this
       when the curator applies a `promote_to_adr` decision autonomously;
       the user reviews the scaffolded ADR and changes `Status` to
       `Accepted` when they agree with the decision.

4. Copy `${CLAUDE_SKILL_DIR}/ADR-template.md` to
   `docs/adr/ADR-{NNN}-{slug}.md`. Substitute:
     - `ADR-NNN` → `ADR-{NNN}` (header + filename)
     - `<Title>` → the title argument
     - `YYYY-MM-DD` → today
     - `Status:` line → `Accepted` by default, or `Proposed` when the
       `proposed` argument flag was supplied.
     - `Affects:` line → the comma-separated affects argument or
       `<comma-separated paths or 'project-wide'>` placeholder when not
       supplied
     - `Supersedes:` line → the argument value or `none`
     - `Origin:` line → `direct via /base:adr` (default), or
       `curator-promoted from archive: <marker>` when from-archive was
       supplied
     - Embed archive entries (when from-archive was supplied) verbatim
       under `## Context` with their dates preserved.

5. If `Supersedes: ADR-NNN` was provided, also UPDATE the superseded
   ADR's `Superseded by:` line. This is the only edit this skill makes
   to existing ADRs — supersession is bidirectional by design.

6. **Spec cross-reference propagation** (when `affects:` was supplied):
   For each path in the affects list that resolves to a spec
   (`specs/epic-*/spec.md` directly, or `<path>/spec.md` for a directory
   form, or every spec under the dir for `specs/epic-*/` glob),
   append a pointer line to the spec's `## Constrained by ADRs`
   section. Skip any spec that already references this ADR (grep for
   `ADR-{NNN}`). For specs that do NOT yet have a `## Constrained by ADRs`
   section, create one immediately after `## Design Decisions` (or, if
   that section is missing, immediately before `## Technical Approach`,
   or — last resort — append to end of file).

   Pointer line format:
   ```
   - **ADR-{NNN}** — <one-line ADR title>.
   ```

   Skip silently for `affects: project-wide` (no specific spec to
   update) and for paths that do not resolve to a spec file. Report the
   list of specs touched in the final summary so the user can verify.

7. Report the path written, the list of specs cross-referenced (if
   any), and any follow-up actions:
     - If from-archive was used, remind the user to add `[→ ADR-{NNN}]`
       to the matched lines in BACKLOG.json#archive[] (this skill never
       touches BACKLOG.json).
     - If affects was supplied with `project-wide`, remind the user
       that no spec cross-references were written.
```

## What this skill does NOT do

- **No debate.** Use `base:arch-debate` for that. The two skills produce
  ADRs in compatible formats — `base:arch-debate` writes
  `Type: Debated` + a `## Debate Summary` section; this skill writes
  `Type: Lightweight`.
- **No content generation.** The body is a stub. The user fills in
  Context, Decision, Alternatives, Consequences. The from-archive
  argument seeds Context with the rejection text; everything else is
  the author's job.
- **No automatic acceptance.** ADRs are written with `Status: Accepted`
  by default for the lightweight path (no debate to gate on). For
  proposed-but-not-yet-decided decisions (e.g. when the curator applies
  a `promote_to_adr` decision autonomously), pass the `proposed` flag —
  the skill scaffolds with `Status: Proposed` directly. The user reviews
  and changes to `Accepted` when ready. Manual editing is still valid
  when the flag is not passed.
- **No edits to BACKLOG.json.** Promotion of archive entries to an ADR
  pointer is the user's call (or the curator's proposal at the next
  `/feature` retro).
- **No edits to specs beyond the `## Constrained by ADRs` pointer line.**
  When `affects:` is supplied, the skill writes one pointer per affected
  spec — it does not modify ACs, design decisions, or any other section.
  Decisions about what the spec means now that the ADR exists are the
  user's.

## Numbering compatibility with `base:arch-debate`

Both skills count `ls docs/adr/*.md | wc -l` and assign N+1. They
share the numbering pool. Numbers are unique per repo regardless of
which skill produced the ADR. If a race occurs (two skills compute the
same N), the second writer detects the collision (`Write` will fail if
the file exists) and re-numbers.

## Citation conventions

A spec that is constrained by an ADR cites it in the spec's `## Design
Decisions` section:

> **Auth flow** — uses bunker-only signing, per ADR-007. Refs: …

An ADR that affects specific specs lists them under `Affects:`:

> **Affects**: specs/epic-auth, specs/epic-billing
