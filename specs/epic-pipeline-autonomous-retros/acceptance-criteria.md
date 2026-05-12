# Acceptance Criteria — Pipeline-Autonomous Retros

## AC-CURATOR — Curator refactor

**AC-CURATOR-1**: `plugins/base/agents/project-curator.md` Hard Rule 1 no longer states "you never write files." The rule is replaced with one permitting the curator to write files autonomously when applying decisions (writing `BACKLOG.md` and annotating retro markdown files).

**AC-CURATOR-2**: `plugins/base/agents/project-curator.md` Hard Rule 2 no longer states "you propose; the user disposes." The rule is replaced with one establishing the curator as the sole decision-authority that applies actions directly, without awaiting user adjudication. The rule no longer references `AskUserQuestion`.

**AC-CURATOR-3**: `plugins/base/agents/project-curator.md` Hard Rule 3 (cap-5) is removed. No rule in the file limits the number of actions the curator may take per run.

**AC-CURATOR-4**: `plugins/base/agents/project-curator.md` documents an `annotate_retro` action in its action-schema section. The action schema specifies: a `retro_path` field (path to the source retro file), a `finding_anchor` field (substring or line reference identifying the finding block), and a `disposition` field whose value is one of the following literal strings: `BACKLOG#<marker>`, `DUPLICATE of finding-<marker> (recurrence ×N)`, `ADR-NNN`, `ARCHIVE`, `NO_ACTION <reason>`, `DEFERRED to /base:retros-derive`. The written annotation is the italic line `_Curator: YYYY-MM-DD → <disposition>_` appended under the finding's `**Suggested change**:` line in the retro markdown.

**AC-CURATOR-5**: `plugins/base/agents/project-curator.md` states that the curator skips any finding block whose text already contains a line matching `_Curator: .*_`. This rule is stated as the dedup guard enabling idempotent re-runs.

**AC-CURATOR-6** (plugin-scope exclusion): `plugins/base/agents/project-curator.md` states that when a finding carries `scope: meta` AND its `**Suggested change**:` text contains any of the following tokens — `plugins/base/`, `` `base:` ``, `/base:`, `integration-architect`, `code-explorer`, `story-planner`, `spec-validator`, `verification-examiner`, `pbt-dev`, `retro-synthesizer`, `bug-retro-synthesizer`, `project-curator`, `feature.md`, `bug.md`, `retros-derive`, `result.json`, `epic-state.json`, `stories.json`, `verification.json` — the curator annotates it `DEFERRED to /base:retros-derive` and does not append any finding to the consumer project's `BACKLOG.md`.

**AC-CURATOR-7** (recurrence): `plugins/base/agents/project-curator.md` states that when the curator would file a new finding whose normalized target token matches an existing `## Findings` bullet in `BACKLOG.md`, the curator instead: (a) appends a recurrence line to the existing bullet (e.g. `recurred ×N (date)`), and (b) annotates the retro finding as `DUPLICATE of finding-<marker> (recurrence ×N)`. No new bullet is created.

**AC-CURATOR-8**: `plugins/base/agents/project-curator.md` frontmatter `tools:` field includes `Write` and `Edit` in addition to `Read`, `Grep`, `Glob`, `Bash`.

**AC-CURATOR-9**: `plugins/base/agents/project-curator.md` output schema changes the field name from `proposals` to `decisions`. The `deferred_count` field is retained in the schema for backward compatibility but its description states it is always `0` (the cap is removed; no items are deferred). The `summary` field remains and describes the count of decisions applied.

## AC-FEATURE — feature.md wrap-up

**AC-FEATURE-1**: `plugins/base/commands/feature.md` Step 6.3 does not contain `AskUserQuestion`. The step instructs the lead to read the curator's `decisions` list and apply each action directly, without presenting proposals to the user for adjudication.

**AC-FEATURE-2**: `plugins/base/commands/feature.md` Step 6.3 retains the per-action application rules verbatim (the mechanics for `append_finding`, `append_rejection`, `amend_spec`, `resolve_finding_via_spec`, `resolve_finding_mechanical`, `move_finding_to_archive`, `promote_to_adr`, `promote_rejections_to_adr`, `update_epics_section`). The rules describe what the curator applies directly, not what the lead applies after user approval.

**AC-FEATURE-3**: `plugins/base/commands/feature.md` Step 6.3 `promote_to_adr` application rule passes `proposed` to the `base:adr` skill invocation (i.e. `Skill("base:adr", args: "<title> affects:... proposed")`), so curator-promoted ADRs are scaffolded as `Status: Proposed` rather than `Status: Accepted`.

**AC-FEATURE-4**: `plugins/base/commands/feature.md` Step 6.5 report to the user includes: stories completed vs escalated, test count, path to retro file (or friction-free note), and curator summary as `<N> decisions applied` (not `<N> proposals accepted, <M> declined`). The report does not surface finding text inline.

**AC-FEATURE-5**: `plugins/base/commands/feature.md` Step 6.3 or Step 6.5 does not reference the cap-5 rule. All existing phrases such as "the curator already deferred lower-signal items per its cap-5 rule" are removed.

**AC-FEATURE-6**: All planning-phase `AskUserQuestion` calls in `plugins/base/commands/feature.md` — spec validation clarifications (Step 2), RECONCILE adjudication (Step 1.5), Mode 3 story-planner questions, and escalation prompts (Step 5) — are present and unchanged.

## AC-BUG — bug.md wrap-up

**AC-BUG-1**: `plugins/base/commands/bug.md` Step 4.2b does not contain `AskUserQuestion` for curator proposal adjudication. The step instructs the lead to apply curator decisions directly and cross-references `base:feature` Step 6.3 for the per-action application rules (which, after AC-FEATURE-1 is satisfied, describe direct application).

**AC-BUG-2**: `plugins/base/commands/bug.md` Step 4.3 report to the user retains: root cause explanation, what was changed, tests added, baseline → final test counts, path to retro file (or friction-free note), and curator summary as `<N> decisions applied` (not `<N> proposals accepted, <M> declined`). The report does not surface finding text inline.

## AC-DERIVE — /base:retros-derive command

**AC-DERIVE-1**: File `plugins/base/commands/retros-derive.md` exists. Its frontmatter or opening section identifies it as a command the lead executes directly without spawning a subagent for the outer loop.

**AC-DERIVE-2**: `plugins/base/commands/retros-derive.md` globs `${CLAUDE_PLUGIN_DATA}/retros/<plugin-slug>/*.md` where `<plugin-slug>` is derived from the plugin's data directory, using the same mechanism as `base:feature` Step 6 uses for writing retro files.

**AC-DERIVE-3**: `plugins/base/commands/retros-derive.md` states that retro files are processed oldest-first, using the `completed:` YAML frontmatter field as the sort key. Retro files without a `completed:` field are processed last.

**AC-DERIVE-4**: `plugins/base/commands/retros-derive.md` states the section-matching priority for extracting meta findings: (1) `## Meta-level findings (raise to user)`, (2) `## Lead's epic-meta findings`, (3) `## Workflow-level findings`, (4) `### Meta-level (raise to user)`, (5) `## Frictions worth recording`, (6) fallback: any paragraph containing `**Suggested change**:` not nested under a `## Project-specific`, `## Routine`, or `## Discrepancies` header.

**AC-DERIVE-5**: `plugins/base/commands/retros-derive.md` states that findings already carrying a `_Curator: .*_` line are skipped before being passed to the curator (same dedup guard as AC-CURATOR-5).

**AC-DERIVE-6**: `plugins/base/commands/retros-derive.md` invokes `base:project-curator` with this repository (`claude-plugins`) as the project context and `BACKLOG.md` as the target backlog. The curator operates in the same autonomous mode established by AC-CURATOR-1 through AC-CURATOR-9.

**AC-DERIVE-7**: `plugins/base/commands/retros-derive.md` does not contain `AskUserQuestion` anywhere in its instruction text.

**AC-DERIVE-8**: `plugins/base/commands/retros-derive.md` states that write failures (I/O errors, missing `BACKLOG.md`, unreadable retro file) are surfaced in the final report. The command continues processing remaining retros after a per-file failure rather than halting.

**AC-DERIVE-9**: `plugins/base/commands/retros-derive.md` final report states: N retros scanned, M findings processed, K findings skipped (already annotated), decisions applied count, and the path list of retro files that were annotated.

## AC-ADR — ADR proposed-status support

**AC-ADR-1**: `plugins/base/skills/adr/SKILL.md` documents a `proposed` argument flag. The argument hint (the line documenting `<title> [affects:...] [supersedes:...]`) is updated to include `[proposed]` as a valid optional argument.

**AC-ADR-2**: `plugins/base/skills/adr/SKILL.md` states that when `proposed` is passed, the scaffolded ADR has `Status: Proposed` instead of `Status: Accepted`. The existing note that users change `Status` manually is removed or updated to reflect that the `proposed` flag handles the non-default case.

**AC-ADR-3**: `plugins/base/skills/adr/ADR-template.md` documents `Status: Proposed` as a valid non-default status value, in a comment, note, or inline alternative on the `**Status**` line.

**AC-ADR-4**: `plugins/base/agents/project-curator.md` documents in the `promote_to_adr` action schema or its operating rules that the curator passes `proposed` to the `base:adr` skill invocation when applying `promote_to_adr` decisions autonomously, so the scaffolded ADR starts as `Status: Proposed` pending user review.
