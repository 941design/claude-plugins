---
name: cross-environment
description: >-
  Diagnose and resolve issues when a single project tree is developed from two
  architectures at once (e.g. macOS host + Linux VM/container sharing a mounted
  directory). Covers native node_modules bindings, Playwright browser caches,
  and Claude Code session environment variables. Trigger on cross-platform
  install errors ("Cannot find module @next/swc-...", "Cannot find module
  @rollup/rollup-..."), Playwright "Executable doesn't exist at
  chrome-headless-shell-..." errors, ENOENT errors against CLAUDE_PLUGIN_DATA,
  questions about platform stamps in Makefiles, PLAYWRIGHT_BROWSERS_PATH, and
  any "after switching from mac to linux..." troubleshooting.
user-invocable: true
argument-hint: "[symptom, error message, or question — empty for the switching-environments checklist]"
allowed-tools: Read, Grep, Glob, Bash
---

## Reference Document

The authoritative reference for this skill lives at
`${CLAUDE_SKILL_DIR}/cross-environment-development.md`. Read it before
answering. It covers:

- The shared-tree topology and why platform-specific state must be partitioned
- Native Node bindings: the `node_modules/.platform` stamp + Makefile pattern
- Playwright browser binaries: per-OS default cache vs. the
  `PLAYWRIGHT_BROWSERS_PATH=0` anti-pattern
- Claude Code session env vars: why `$HOME`-derived paths get stuck and how
  restarting the CLI fixes them
- Symptom → recovery mappings for each failure mode
- A switching-environments checklist
- A "what you should never do" list

## User Request

$ARGUMENTS

## Response Guidelines

- **Diagnose first, recover second.** When the user reports a symptom,
  identify which of the three classes it belongs to (native bindings,
  Playwright browsers, Claude Code session env) before suggesting fixes.
  The reference doc has explicit symptom lists for each.
- **Prefer the documented recovery commands verbatim.** They are tuned to
  avoid making things worse — for example, deleting only
  `node_modules/.platform` (not the whole tree) when the stamp mismatches.
- **Never propose `PLAYWRIGHT_BROWSERS_PATH=0`.** It is the anti-pattern
  that motivates this skill. If the user already has it set, recommend
  removing it and falling back to the per-OS default cache.
- **For Claude Code env-var issues, the only fix is restarting the CLI
  session.** Workarounds with inline `VAR=value` overrides are single-shot
  only.
- **No arguments → walk the checklist.** If `$ARGUMENTS` is empty, present
  the "Quick checklist when switching environments" from the reference doc
  and ask which step the user is stuck on.
- **Detect, don't assume.** If the project does not have a Makefile with a
  platform stamp, mention that the pattern would need to be added; do not
  assume it is already in place.
- **Stay grounded in the doc.** This is a stable reference skill — the
  underlying mechanics rarely change. Do not invent new recovery procedures
  that aren't documented.
