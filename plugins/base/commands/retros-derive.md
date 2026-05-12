---
name: retros-derive
description: >-
  Walks the plugin's back-catalogue of retros at ${CLAUDE_PLUGIN_DATA}/retros/<plugin-slug>/
  and derives pipeline-improvement backlog items for the plugin-development repo.
  Invokes base:project-curator autonomously. Fully non-interactive.
argument-hint: (no arguments)
allowed-tools: Read, Glob, Bash, Agent, Write, Edit
---

# /base:retros-derive — Pipeline Retro Backlog Derivation

You are the **lead**. This command is executed directly by you; no outer-loop subagent is spawned. Work through the steps below sequentially, produce the final report, and — when warranted — emit a meta-retro (see Step 7).

---

## Operating constraints (read first)

- **Fully non-interactive.** Do not call `AskUserQuestion` at any step, and do not spawn subagents that have it in `allowed-tools`. The only Agent spawn here is `base:project-curator`, whose tool list already excludes it. If a sub-step encounters ambiguity that would normally prompt the user (unrecognised heading, ambiguous slug, malformed retro file, duplicate anchor), pick the documented safe default *and record both the ambiguity and the default chosen as a meta-finding in the meta-retro at Step 7*. Headless invocations cannot answer prompts, so silent defaults must become visible findings.
- **Retros are not aimed at humans alone.** Workflow retros (`/base:feature`, `/base:bug`) are machine-readable artifacts consumed by Steps 1–6 of this command. This command also emits its *own* retro at Step 7 — the **meta-retro** — parked in a sibling directory and deliberately **not** routed back through the workflow retro pipeline. A separate meta-retro processor will handle those findings when one is designed; until then, meta-retros are durable write-only artifacts.

---

## Step 1: Identify the Plugin Slug

Read `${CLAUDE_PLUGIN_DATA}` from the environment (same env var that `base:feature` Step 6 uses when writing retro files). List the directories under `${CLAUDE_PLUGIN_DATA}/retros/` with:

```bash
ls "${CLAUDE_PLUGIN_DATA}/retros/"
```

The plugin slug is the name of the directory under `retros/` that corresponds to this plugin. For this repo the slug is `base-941design`. Confirm by checking whether `${CLAUDE_PLUGIN_DATA}/retros/base-941design/` exists.

Set `RETRO_DIR="${CLAUDE_PLUGIN_DATA}/retros/base-941design"`.

---

## Step 2: Discover Retro Files

Glob all markdown files in the retro directory:

```
${CLAUDE_PLUGIN_DATA}/retros/<plugin-slug>/*.md
```

List every matching path. If no files are found, output:

```
No retros found at <RETRO_DIR>. Exiting.
```

and stop.

---

## Step 3: Sort Oldest-First

For each retro file, read its YAML frontmatter (the `---` block at the top of the file). Extract the `completed:` field value (format `YYYY-MM-DD`).

Sort the files ascending by `completed:` date — oldest first. This ensures the first occurrence of any finding becomes the canonical backlog bullet; subsequent identical findings are marked as recurrences.

Files that have no `completed:` field receive a synthetic sort key of `9999-12-31` so they sort after all dated files. Within the undated group, sort alphabetically by filename as the secondary key.

---

## Step 4: Extract Meta-Level Findings (Per File)

Iterate over the sorted file list. For each retro file:

**4a. Skip check (fully annotated file)**

If EVERY finding block in the file already contains a line matching `_Curator: .*_`, note the file as "fully annotated" in the running tally and skip to the next file.

**4b. Locate meta-level sections**

Apply the following section-matching priority in order. Use the first level that yields at least one section:

1. `## Meta-level findings (raise to user)` — primary (modern retro format)
2. `## Lead's epic-meta findings` — secondary (older feature retros)
3. `## Workflow-level findings` — tertiary (meta-audit format)
4. `### Meta-level (raise to user)` — level-3 heading variant
5. `## Frictions worth recording` — shophop format
6. **Fallback**: any paragraph containing `**Suggested change**:` that is NOT nested under a `## Project-specific`, `## Routine — skipped retros`, or `## Discrepancies` header.

For each file that contributes findings, record the matched level in the running tally — Step 7's meta-retro treats levels 5 and 6 as **heuristic-drift signals** worth surfacing as meta-findings (the section-matching priority is falling behind the corpus and may need a new entry).

If none of the six levels match, the file contributes zero findings. Record it as "0 findings" in the tally and continue. If that same file *does* contain `**Suggested change**:` text anywhere — but only outside the recognised sections — also flag it for Step 7 as an **empty-but-suspect** file (likely a new retro template not yet handled).

**4c. Identify finding blocks**

Within the matched section(s), a **finding block** is:

- A `###` or `####` heading plus all content under it up to the next heading of equal or higher level, OR
- For the fallback (level 6 only): a paragraph that contains `**Suggested change**:`.

**4d. Dedup guard**

For each finding block, check whether the block already contains a line matching `_Curator: .*_`. If yes, mark the finding as "skipped (already annotated)" in the tally and do not pass it to the curator.

Collect all remaining (un-annotated) finding blocks as the **findings bundle** for this file, preserving the file path and a brief anchor (the heading text or first 80 characters of a fallback paragraph).

---

## Step 5: Invoke base:project-curator

Aggregate the findings bundles from all files (already sorted oldest-first by the Step 3 ordering) into a single structured input. Spawn the curator via the Agent tool:

```
subagent_type: base:project-curator
```

Pass in the spawn prompt:

- **Project context**: this repository (`claude-plugins`), git root at `$(git rev-parse --show-toplevel)`
- **BACKLOG.md path**: `BACKLOG.md` at the repo root (absolute path)
- **Findings bundle**: the aggregated un-annotated findings, inline in the prompt as structured text. Include for each finding: the source retro file path, the finding anchor text, and the full finding block content.
- **Processing order**: oldest-first (the bundle is already sorted)
- **Instruction**: the curator operates in its standard autonomous mode — it writes `BACKLOG.md` updates directly and uses its `annotate_retro` action to mark each processed finding in the source retro file. Do not override or supplement the curator's Hard Rules.

The curator's `decisions` output field (not `proposals`) describes what was applied. Wait for the curator to complete before proceeding.

---

## Step 6: Error Handling

After the curator completes, check its report for errors:

- If the curator reports that a write to `BACKLOG.md` failed (I/O error, file not found), record the error in the running tally and continue.
- If the curator reports that annotating a specific retro file failed (unreadable file, I/O error, finding anchor not located), record the error per file in the running tally and continue.
- Do NOT halt the entire command on a per-file failure. Process all findings and surface all errors in both the final report (Step 8) and — if any errors occurred — the meta-retro (Step 7).

---

## Step 7: Emit a meta-retro (when non-trivial)

`/base:retros-derive` is itself a non-trivial workflow. Surface its own friction as a durable, machine-readable artifact for future inspection. The meta-retro is **isolated from the workflow retro pipeline**: it lives in a sibling directory (`${CLAUDE_PLUGIN_DATA}/meta-retros/`), so Steps 1–6 never glob, parse, or otherwise touch it. A separate meta-retro processor will route these findings into `BACKLOG.md` when designed; until then the meta-retro is a write-only log.

**7a. Strict skip floor.** Write **no** meta-retro file when ALL of the following hold:

- N ≥ 1 (Step 2 did not take the early-exit branch — that case already prints "No retros found" and stops)
- Zero per-file errors recorded in Step 6
- Zero heuristic-drift signals (every contributing file matched Step 4b level 1–4; no level 5 or 6 hits)
- Zero empty-but-suspect files flagged in Step 4b
- Zero "default chosen in lieu of asking" events during this run
- Curator behaved unremarkably (returned a non-empty `decisions` array when M ≥ 1, OR returned the empty-decisions sentinel when M = 0; reported no internal anomalies)

If any of the above is violated, write the meta-retro. Empty is the strong default — most healthy runs should skip.

**7b. File path.** Derive the consumer slug from the current git root — do **not** reuse `${RETRO_DIR}` from Step 1 (that variable still carries Step 1's value and addresses the workflow retro tree):

```
CONSUMER_SLUG=$(basename "$(git rev-parse --show-toplevel)")
META_RETRO_DIR="${CLAUDE_PLUGIN_DATA}/meta-retros/${CONSUMER_SLUG}"
```

then write the meta-retro to:

```
${META_RETRO_DIR}/retros-derive-<YYYY-MM-DD>-<HHMM>.md
```

The timestamp uses the lead's current wall-clock time — date as ISO 8601 (`date +%Y-%m-%d`), `HHMM` as a 4-digit 24-hour clock (`date +%H%M`). The `HHMM` suffix prevents collisions when retros-derive runs more than once on a single day. Create the directory with `mkdir -p "$META_RETRO_DIR"` if missing.

`meta-retros/` is a **sibling** of `retros/` under `${CLAUDE_PLUGIN_DATA}`, deliberately outside the workflow retro tree. Steps 1–6 do not glob this path, so the workflow retro pipeline is structurally incapable of being perturbed by meta-retros — no defensive filter required.

The per-consumer subdir (`<consumer-slug>/`) keys meta-retros by which project emitted them. A future meta-retro processor running in the plugin-development repo can glob `${CLAUDE_PLUGIN_DATA}/meta-retros/*/*.md` to collect meta-retros from every consumer that has ever run a base command — matching the cross-project collection model that workflow retros need from `${CLAUDE_PLUGIN_DATA}/retros/`. Today retros-derive is the only emitter and runs only in the plugin-dev repo, so in practice you'll see a single subdir; the layout is forward-compatible.

**7c. Content schema.** Use the layout below verbatim. Frontmatter `completed:` is required (a future meta-retro processor will sort by it the same way Step 3 does for workflow retros). Heading levels mirror the workflow retro format so the same parser can be reused if/when one is built.

```markdown
---
completed: YYYY-MM-DD
source_command: /base:retros-derive
retros_scanned: <N>
findings_processed: <M>
findings_skipped: <K>
decisions_applied: <curator summary, one line>
---

# /base:retros-derive meta-retro — YYYY-MM-DD HHMM

## Tally
- Retros scanned: <N>
- Findings processed (un-annotated, passed to curator): <M>
- Findings skipped (already annotated): <K>
- Decisions applied by curator: <one-line summary>
- Annotated retro files: <count>

## Errors
<one bullet per per-file error from Step 6; omit this entire section if zero errors>

## Meta-level findings (route to plugin memory)

### <short headline for the finding>
**Suggested change**: <one concrete pipeline change in the base plugin: commands, agents, schemas, curator rules, prompt text>

<one short paragraph: what was observed, where, why it matters>

## Project-specific findings (route to project memory)

### <short headline for the finding>
**Suggested change**: <one concrete change to the project where retros-derive ran — local infra, tooling, paths, env, project-specific config>

<one short paragraph: what was observed, where, why it matters>
```

**7d. Partitioning findings into the two sections.** The rule is: friction about the **base plugin's design** (commands, agents, schemas, curator rules, prompt text) → `## Meta-level findings (route to plugin memory)`. Friction about the **environment this run actually executed in** (local filesystem, project tree, local tooling, project-specific paths and env) → `## Project-specific findings (route to project memory)`. When in doubt, ask whether the same friction would affect a different consumer running the same command — if yes, it's meta; if no, it's project-specific.

Emit one `###` block per event when it occurred during this run. If a section has no entries, emit a single `### No findings` placeholder so the section always carries at least one block (keeps any future meta-retro parser from edge-casing on empty sections).

Goes in `## Meta-level findings (route to plugin memory)`:

- **Heuristic drift.** A contributing file's findings came only from Step 4b level 5 or 6. Suggested change: add a new entry to the section-matching priority list naming the heading the retro author used.
- **Empty-but-suspect file.** A file flagged in Step 4b as containing `**Suggested change**:` text outside the recognised sections. Suggested change: inspect the file's structure and either extend the level list or correct the retro template.
- **Default chosen in lieu of asking.** Any place the lead or curator would have prompted the user but chose a documented default. Record the ambiguity, the default chosen, and where it appeared.
- **Curator anomaly.** Curator returned 0 decisions despite ≥10 processed findings, or reported write errors, or its `summary` line conflicted with the `decisions` array length. Surface the specific anomaly and a suggested investigation path.
- **Corpus-shape per-file error.** A per-file error that reveals a class of malformed retros (e.g. an entire batch with missing frontmatter, suggesting the synthesizer is emitting a new format). The friction is about synthesizer behavior, not this environment.

Goes in `## Project-specific findings (route to project memory)`:

- **Environment-rooted per-file error.** Per-file errors from Step 6 that are about local filesystem state (unreadable file, missing path, permission issue) — they affect this run's environment, not the base plugin's design. Each gets a `###` block with a suggested local-investigation step.
- **Anything else specific to this run's project tree.** Local tooling glitches, mis-set env vars, project-specific path assumptions that broke. If the same input would behave differently in a different consumer, the finding is project-specific.

**7e. Do not annotate yourself.** Do not pre-fill any `_Curator: ..._` line on the meta-retro's findings. Findings must arrive un-annotated so that a future meta-retro processor (whether a new command, a new step here, or an `/base:orient` hook) can adopt the same dedup convention as Step 4d to track which entries it has already routed. Until that processor exists, meta-retros are write-only artifacts; the un-annotated form keeps the future option open.

---

## Step 8: Final Report

Output to the user in this exact structure:

```
Retros scanned: N
Findings processed: M  (un-annotated, passed to curator)
Findings skipped: K  (already annotated)
Decisions applied: <count and summary from curator>
Annotated retro files: <list of absolute paths that the curator annotated>
Meta-retro: <absolute path written>  OR  skipped (strict floor satisfied)
[Errors: <list of per-file errors, if any>]
```

- **N** = total number of `.md` files discovered in Step 2.
- **M** = total un-annotated finding blocks passed to the curator.
- **K** = total finding blocks skipped because they carried a `_Curator: .*_` line.
- **Decisions applied** = the `decisions` summary returned by the curator.
- **Annotated retro files** = paths the curator's `annotate_retro` action successfully wrote to.
- **Meta-retro** = the absolute path written in Step 7, or the literal `skipped (strict floor satisfied)` when Step 7a's floor was met.
- The **Errors** line is omitted entirely when there are no errors.
