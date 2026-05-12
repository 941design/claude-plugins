# Architecture — Pipeline-Autonomous Retros

## Paradigm

Modular markdown prompt editing. All "code" is markdown files containing agent/command/skill instructions. No compiled artifacts, no test suite in the traditional sense. Verification is observational: read the edited prompts and confirm the specified behaviors are expressed correctly, unambiguously, and without contradicting other rules.

## Module Map

| Module | Purpose | Files |
|---|---|---|
| Curator agent | Decision-making at run wrap-up; writes BACKLOG.md and retro annotations | `plugins/base/agents/project-curator.md` |
| Feature command | Lead instructions for /feature runs including wrap-up | `plugins/base/commands/feature.md` |
| Bug command | Lead instructions for /bug runs including wrap-up | `plugins/base/commands/bug.md` |
| Retros-derive command | Meta-cycle command for deriving plugin-repo backlog items from pipeline retros | `plugins/base/commands/retros-derive.md` (new) |
| ADR skill | Scaffolds ADRs; needs `proposed` flag | `plugins/base/skills/adr/SKILL.md`, `plugins/base/skills/adr/ADR-template.md` |

## Boundary Rules

- Curator is the sole writer of BACKLOG.md and retro annotations within a pipeline run.
- Feature/bug commands invoke curator and apply its output; they do not write to BACKLOG.md themselves (except the unconditional epic-bullet lifecycle flip at Step 6.1, which is the lead's own bookkeeping).
- Retros-derive command invokes curator against the plugin repo — same curator, different context.
- Synthesizers are pure functions (no file writes); this does not change.

## Critical Dependency

**bug.md Step 4 cross-references feature.md Step 6.3 for all per-action application rules.** When feature.md Step 6.3 changes from "adjudicate via AskUserQuestion" to "apply curator decisions", bug.md Step 4 must also update OR be re-written to replicate the apply-decisions rules inline (since its current cross-reference points to now-changed content).

Given that bug.md already cross-references feature.md, the cleanest approach: update feature.md Step 6.3 text to be the authoritative "apply decisions" description, and update bug.md Step 4 to cross-reference the updated step. The shared application rules live in feature.md only.

## Seams

### Curator → BACKLOG.md
Output: curator applies `append_finding`, `append_rejection`, etc. directly. No intermediary.

### Curator → Retro files (new)
Output: curator uses `annotate_retro` action. Writes `_Curator: YYYY-MM-DD → <disposition>_` line in source markdown.

### Retros-derive → Curator
Input: synthetic retro_bundle-shaped data from parsed retro markdown. Same curator contract; different invocation source.

### Curator → ADR skill
Curator invokes `Skill("base:adr", args: "... proposed")` when promoting decisions to ADR. ADR skill must accept `proposed` flag.

## Implementation Constraints

- Preserve ALL planning-phase `AskUserQuestion` calls in feature.md and bug.md.
- The per-action application rules (append_finding mechanics, promote_to_adr mechanics, etc.) must be preserved verbatim in feature.md Step 6 — they move from "what to do with accepted proposals" to "what the curator applies directly."
- `deferred_count` field: remove or set to `null`/`0` always (cap-5 removed); keep the field for backwards-compat if other consumers parse the JSON structure, but note it is always 0.
- `annotate_retro` must be idempotent (dedup guard on `_Curator: .*_` suffix prevents double annotation).
- Retros-derive oldest-first sorting uses `completed:` YAML frontmatter field from retro files.
