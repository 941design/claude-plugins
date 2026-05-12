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

You are the **lead**. This command is executed directly by you; no outer-loop subagent is spawned. Work through the steps below sequentially and produce the final report.

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

If none of the six levels match, the file contributes zero findings. Record it as "0 findings" in the tally and continue.

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

- If the curator reports that a write to `BACKLOG.md` failed (I/O error, file not found), record the error in the final report and continue.
- If the curator reports that annotating a specific retro file failed (unreadable file, I/O error, finding anchor not located), record the error per file in the final report and continue.
- Do NOT halt the entire command on a per-file failure. Process all findings and surface all errors in the final report.

---

## Step 7: Final Report

Output to the user in this exact structure:

```
Retros scanned: N
Findings processed: M  (un-annotated, passed to curator)
Findings skipped: K  (already annotated)
Decisions applied: <count and summary from curator>
Annotated retro files: <list of absolute paths that the curator annotated>
[Errors: <list of per-file errors, if any>]
```

- **N** = total number of `.md` files discovered in Step 2.
- **M** = total un-annotated finding blocks passed to the curator.
- **K** = total finding blocks skipped because they carried a `_Curator: .*_` line.
- **Decisions applied** = the `decisions` summary returned by the curator.
- **Annotated retro files** = paths the curator's `annotate_retro` action successfully wrote to.
- The **Errors** line is omitted entirely when there are no errors.
