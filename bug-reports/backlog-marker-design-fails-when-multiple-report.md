# Bug Report: BACKLOG Marker Design — Stale `<marker>` References in format.md

**Slug**: backlog-marker-design-fails-when-multiple  
**Source**: BACKLOG.md finding promoted 2026-05-14

## Description

After the v2 slug-keyed grammar migration (commit `0c2e105`), two stale
`<marker>` / anchor-path references survived in
`plugins/base/skills/backlog/references/format.md` while every execution-path
file (`next.md`, `feature.md`, `bug.md`, `backlog/SKILL.md`) already uses the
canonical `<slug>` vocabulary.

## Expected Behavior

`format.md` is the single source of truth for BACKLOG.md grammar. Every
reference to dispatch arguments should use `<slug>` (kebab-case, no extension)
consistently with the rest of the pipeline. Example dispatch args in the notice-
line grammar section should illustrate slug-style identifiers, not anchor paths.

## Actual Behavior

1. **`format.md:449`** — Fallback-on-inference-failure prose reads
   `Skill("base:feature", args: "backlog:<marker>")`. The word `<marker>` was
   not updated to `<slug>` during the migration.

2. **`format.md:470-473`** — Notice line grammar examples use anchor-path style
   identifiers with `.md` extensions (`backlog:foo.md`, `backlog:bar.md`,
   `baz.md`, `qux.md`). These are the old design where the anchor file path
   was used as the dispatch token. The v2 design uses kebab-case slugs without
   extensions.

## Reproduction Steps

Starting reference: `plugins/base/skills/backlog/references/format.md`

1. `grep -n "backlog:<marker>" plugins/base/skills/backlog/references/format.md`
   → matches line 449
2. `grep -n "foo.md\|bar.md\|baz.md\|qux.md" plugins/base/skills/backlog/references/format.md`
   → matches lines 470-473
3. Compare with `next.md` which uses `backlog:<slug>` throughout (lines 635-643,
   694-696) — the format.md references are inconsistent.

## Impact

An agent reading `format.md` alone (e.g., `base:project-curator` or a future
skill consulting the reference) could derive incorrect dispatch arg shapes:
- It might pass `backlog:<marker>` literally as a template variable name
- It might pass anchor-path strings like `backlog:foo.md` as dispatch args,
  which would not be found by the slug-lookup in `feature.md` or `bug.md`

This is a documentation inconsistency in the reference file, not a logic
error in any currently-executed command file.
