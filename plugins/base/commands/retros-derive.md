---
name: retros-derive
description: >-
  Aggregates plugin-bound findings from workflow retros + meta-retros under
  ${CLAUDE_PLUGIN_DATA} and lands them in the base plugin's own BACKLOG.json.
  Two modes: consumer-mode (no-op for plugin-bound findings — they sit until
  plugin-dev-mode harvests) and plugin-dev-mode (cross-consumer harvest into
  the plugin source repo's BACKLOG.json). Mode is auto-detected from the cwd.
  Invokes base:project-curator autonomously. Fully non-interactive.
argument-hint: (no arguments)
allowed-tools: Read, Glob, Bash, Agent, Write, Edit
---

# /base:retros-derive — Plugin-Bound Findings Aggregator

You are the **lead**. This command is executed directly by you; no outer-loop subagent is spawned. Work through the steps below sequentially, produce the final report, and — when warranted — emit a meta-retro (see Step 7).

---

## Operating constraints (read first)

- **Fully non-interactive.** Do not call `AskUserQuestion` at any step, and do not spawn subagents that have it in `allowed-tools`. The only Agent spawn here is `base:project-curator`, whose tool list already excludes it. If a sub-step encounters ambiguity that would normally prompt the user (unrecognised heading, ambiguous path, malformed retro file, duplicate anchor), pick the documented safe default *and record both the ambiguity and the default chosen as a meta-finding in the meta-retro at Step 7*. Headless invocations cannot answer prompts, so silent defaults must become visible findings.
- **Two-mode operation, deterministic routing.** The classifier deciding whether a finding is plugin-bound or consumer-bound is mechanical (Step 4 of this command and the retro-synthesizer's pre-routing). The curator never decides destination; it only writes to whichever target the lead's mode dispatch supplies. The disposition string `DEFERRED to /base:retros-derive` is forbidden — kill it on sight if you see one in an existing annotation.
- **Workflow retros are machine-readable.** Workflow retros (`/base:feature`, `/base:bug`) emit retros into `${CLAUDE_PLUGIN_DATA}/retros/<consumer-slug>/`. Each retro has multiple top-level sections by destination — including `## Plugin-bound findings (route to plugin BACKLOG)`, which is the canonical home for findings whose `Suggested change:` text targets the base plugin's own design (`plugins/base/<X>`, `base:<cmd>`, or `/base:<cmd>`). This command's plugin-dev mode harvests that section across every consumer.

---

## Step 1: Determine mode

Two modes are supported:

- **consumer-mode** — the cwd is some non-plugin-dev consumer project (e.g. `shophop`, `daydreamer`). Plugin-bound findings are LEFT IN PLACE for plugin-dev-mode to harvest later; this command's curator dispatch in consumer-mode is currently a no-op (reserved for a future expansion). User-facing and project-memory findings are emitted by `/base:feature` / `/base:bug` directly; consumer-mode `/base:retros-derive` doesn't re-process them.
- **plugin-dev-mode** — the cwd is the base plugin's source repository (`claude-plugins`). Walks `${CLAUDE_PLUGIN_DATA}/retros/*/*.md` and `${CLAUDE_PLUGIN_DATA}/meta-retros/*/*.md` across every consumer subdir, harvests **only** the plugin-bound sections, and lands findings in `claude-plugins/BACKLOG.json`.

**Detect mode** by checking whether the cwd contains a `plugins/base/` directory with a `commands/retros-derive.md` file — the canonical signal that this is the base plugin's own repo:

```bash
if [ -f "$(git rev-parse --show-toplevel)/plugins/base/commands/retros-derive.md" ]; then
  MODE=plugin-dev
else
  MODE=consumer
fi
```

Set `REPO_ROOT="$(git rev-parse --show-toplevel)"` for later use.

**Consumer-mode short-circuit.** If `MODE=consumer`, print:

```
Consumer mode detected. Plugin-bound findings sit in retros for plugin-dev /base:retros-derive to harvest. No action taken.
```

and stop. Do NOT scan retros, dispatch the curator, or emit a meta-retro. Consumer-mode is a deliberate no-op for now; the directive exists so that running `/base:retros-derive` from a consumer is harmless and self-explanatory.

The rest of this command applies only to plugin-dev-mode.

---

## Step 2: Discover plugin-bound source files

In plugin-dev-mode the scope is **all consumers** plus meta-retros:

```
${CLAUDE_PLUGIN_DATA}/retros/*/*.md         # workflow retros, every consumer
${CLAUDE_PLUGIN_DATA}/meta-retros/*/*.md    # /base:retros-derive emissions, every consumer
```

Glob both. List every matching path. If no files are found in either tree, output:

```
No retros or meta-retros found under ${CLAUDE_PLUGIN_DATA}. Exiting.
```

and stop.

---

## Step 3: Sort oldest-first

For each discovered file, read its YAML frontmatter and extract the `completed:` field (format `YYYY-MM-DD`). Sort the files ascending by `completed:` — oldest first. This ensures the first occurrence of any finding becomes the canonical backlog bullet; subsequent identical findings are marked as duplicates by the curator.

**Date fallback for files without frontmatter.** If a file has no `completed:` field, attempt to extract a date from its filename using the regex `\d{4}-\d{2}-\d{2}` (e.g. `meta-audit-2026-05-08-*.md` → `2026-05-08`). Use the extracted date as the sort key. Only if neither frontmatter nor filename yields a date, fall back to the synthetic `9999-12-31` and sort the file alphabetically among undated peers.

---

## Step 4: Extract plugin-bound findings

Iterate over the sorted file list. For each file, the canonical plugin-bound section is **one** of:

1. `## Plugin-bound findings (route to plugin BACKLOG)` — modern workflow retro convention (written by the retro-synthesizer's pre-routing).
2. `## Meta-level findings (route to plugin memory)` — meta-retro convention (the section `/base:retros-derive` writes its own friction into; semantically equivalent to #1).

For each file:

**4a. Skip check (fully annotated file).** If EVERY finding block under the matched section already contains a line matching `_Curator: .*_`, note the file as "fully annotated" in the running tally and move on. Do not pass annotated findings to the curator.

**4b. Locate the plugin-bound section.** Match level 1 first, then level 2. If neither heading is present in the file, contribute zero findings — the file has no plugin-bound content (normal for legacy retros emitted before the synthesizer added the new section, or for meta-retros from runs with no pipeline-improvement friction).

**Legacy-retro fallback (structural detection).** Some retros were emitted before the synthesizer learned to write the `## Plugin-bound findings` section. Detect this **structurally**, not by date: a file is **legacy** if it contains neither `## Plugin-bound findings (route to plugin BACKLOG)` nor `## Meta-level findings (route to plugin memory)` headings. For every legacy file, apply the deterministic classifier to every finding under its `## Meta-level findings (raise to user)` and `## Lead's epic-meta findings` sections (and the level-2 variants — see "Heading variants" below):

- If the finding's `Suggested change:` text contains `plugins/base/`, `base:<cmd>`, or `/base:<cmd>` (regex: `\b(plugins/base/|base:[a-z-]+|/base:[a-z-]+)\b`) → treat as plugin-bound and include.
- Otherwise → not plugin-bound; ignore.

The fallback is self-disabling: as retros are re-emitted by the new synthesizer with the modern section, structural detection silently routes them down the modern path and the fallback never runs against them. No date cutoff to maintain.

**Heading variants recognised by the legacy fallback.** Treat any heading matching the prefix-tolerant patterns below as a legacy meta-level section (case-sensitive, but tolerant of parenthetical qualifiers):

- `## Meta-level findings (raise to user)` and any `## Meta-level findings (...)` variant.
- `## Lead's epic-meta findings` and any `## Lead's epic-meta findings (...)` variant (e.g. `## Lead's epic-meta findings (meta-level — action recommended)`).
- `## Workflow-level findings` — the meta-audit retro format. Files in this format typically have no frontmatter; the filename-date fallback in Step 3 handles their sort key.

**4c. Identify finding blocks.** Within the matched section, a **finding block** is a `###` or `####` heading plus all content under it up to the next heading of equal or higher level. Skip blocks whose heading text is `No findings` or whose body is just `**Suggested change**: N/A` — those are template placeholders.

**4d. Dedup guard.** For each block, check whether it already contains `_Curator: .*_`. If yes, mark as "skipped (already annotated)" in the tally and do not pass forward.

**4e. Early exit on fully-annotated corpus.** After iterating every file, if `K > 0` (some findings exist but every one is annotated) AND `M = 0` (no un-annotated findings remain), print:

```
All plugin-bound findings already processed. Nothing to do. Exiting.
```

and skip Steps 5–6. Step 7's meta-retro emission still applies if its strict floor (Step 7a) is violated for any other reason.

Collect remaining un-annotated finding blocks as the **findings bundle**, preserving the source file path and a brief anchor (the heading text).

---

## Step 5: Invoke base:project-curator (plugin-dev mode)

**M = 0 short-circuit.** If the bundle is empty after Step 4 (regardless of K), do NOT spawn the curator. Set `decisions=[]`, `annotated_files=[]`, and proceed to Step 6.

Otherwise, aggregate the findings bundle into a single structured input. Spawn the curator via the Agent tool:

```
subagent_type: base:project-curator
```

Pass in the spawn prompt:

- **Mode**: `plugin-dev` (explicit — the curator's disposition vocabulary depends on this).
- **Project context**: this repository (the base plugin's source repo), git root at `$(git rev-parse --show-toplevel)`.
- **BACKLOG.json path**: `${REPO_ROOT}/BACKLOG.json` (absolute path).
- **Findings bundle**: aggregated un-annotated findings, inline in the prompt. For each finding: source file path (absolute), finding anchor text, full finding block content.
- **Processing order**: oldest-first (bundle is already sorted).
- **Disposition vocabulary** (explicit — the curator MUST use one of these per finding; no others are allowed). The shape matches the curator's documented annotation vocabulary in `plugins/base/agents/project-curator.md`:
  - `BACKLOG#plugins/base/<path>` — call `plugins/base/skills/backlog/scripts/add-finding.sh` to append a new finding to BACKLOG.json, then annotate the source retro with this disposition. The `<path>` should be the most specific base plugin file the suggested change targets.
  - `DUPLICATE of finding-<slug>` — the finding restates an existing BACKLOG.json entry. Annotate only; do not call `add-finding.sh`. Use `DUPLICATE of finding-<slug> (recurrence ×N)` instead when the curator counts a recurrence (see the curator's Recurrence rule).
  - `NO_ACTION <one-line reason>` — the finding was misclassified as plugin-bound but is actually consumer-specific (rare in plugin-dev-mode because the classifier already filtered), or is too vague to be actionable. Annotate only.
- **Forbidden disposition**: `DEFERRED to /base:retros-derive`. There is no downstream handler; this command IS the handler. If the curator's instinct is to defer, it must pick `BACKLOG#`, `DUPLICATE`, or `NO_ACTION` instead.
- **Instruction**: the curator applies BACKLOG.json mutations by shelling out to `plugins/base/skills/backlog/scripts/*.sh` (per `base:project-curator`'s per-action contracts) and uses its `annotate_retro` action to mark each processed finding in the source file. Hard Rules apply as documented in the agent definition.

The curator's `decisions` output field describes what was applied. Wait for the curator to complete before proceeding.

---

## Step 6: Error handling

After the curator completes, check its report for errors:

- BACKLOG.json write failures (I/O error, file not found) → record in the running tally and continue.
- `annotate_retro` failures (unreadable file, anchor not located) → record per file in the running tally and continue.
- Curator-reported anomalies (decisions count mismatch, dispositions outside the allowed vocabulary) → record and surface in Step 7.

Do NOT halt the entire command on a per-file failure. Process all findings and surface all errors in both the final report (Step 8) and — if any errors occurred — the meta-retro (Step 7).

---

## Step 7: Emit a meta-retro (when non-trivial)

`/base:retros-derive` is itself a non-trivial workflow. Surface its own friction as a durable artifact: a meta-retro file at `${CLAUDE_PLUGIN_DATA}/meta-retros/<consumer-slug>/`. Meta-retros are now a **real input source** for future plugin-dev-mode runs (Step 2 globs them too), so any finding written here will eventually flow into `claude-plugins/BACKLOG.json` on the next plugin-dev-mode invocation. There is no separate meta-retro processor; meta-retros are workflow retros with one heading-variant difference.

**7a. Strict skip floor.** Write **no** meta-retro file when ALL of the following hold:

- Step 2 found at least one source file (no early-exit)
- Zero per-file errors recorded in Step 6
- Zero "default chosen in lieu of asking" events during this run
- Zero curator anomalies (curator returned a non-empty `decisions` array if M ≥ 1; reported no disposition-vocabulary violations)

If any condition is violated, write the meta-retro. Empty is the strong default — most healthy runs should skip.

**7b. File path.** Derive the consumer slug from the current git root:

```
CONSUMER_SLUG=$(basename "$(git rev-parse --show-toplevel)")
META_RETRO_DIR="${CLAUDE_PLUGIN_DATA}/meta-retros/${CONSUMER_SLUG}"
```

In plugin-dev-mode `CONSUMER_SLUG` resolves to `claude-plugins` (the plugin's own source repo treated as a consumer of itself, for symmetry). Write the meta-retro to:

```
${META_RETRO_DIR}/retros-derive-<YYYY-MM-DD>-<HHMM>.md
```

The timestamp uses the lead's current wall-clock time. Create the directory with `mkdir -p` if missing.

**7c. Content schema.** Use the layout below verbatim. Frontmatter `completed:` is required. The `## Meta-level findings (route to plugin memory)` section IS the plugin-bound section that the next plugin-dev-mode run will harvest (same scanner, same dedup, same destination).

```markdown
---
completed: YYYY-MM-DD
source_command: /base:retros-derive
mode: plugin-dev
retros_scanned: <N>
findings_processed: <M>
findings_skipped: <K>
decisions_applied: <curator summary, one line>
---

# /base:retros-derive meta-retro — YYYY-MM-DD HHMM

## Tally
- Mode: plugin-dev
- Retros scanned: <N>
- Findings processed (un-annotated, passed to curator): <M>
- Findings skipped (already annotated): <K>
- Decisions applied by curator: <one-line summary>
- Annotated source files: <count>

## Errors
<one bullet per per-file error from Step 6; omit this entire section if zero errors>

## Meta-level findings (route to plugin memory)

### <short headline for the finding>
**Suggested change**: <one concrete change to the base plugin: commands, agents, schemas, curator rules, prompt text>

<one short paragraph: what was observed, where, why it matters>

## Project-specific findings (route to project memory)

### <short headline for the finding>
**Suggested change**: <one concrete change to the project where retros-derive ran — local infra, tooling, paths, env, project-specific config>

<one short paragraph: what was observed, where, why it matters>
```

**7d. Partitioning findings into the two sections.** The rule is: friction about the **base plugin's design** (commands, agents, schemas, curator rules, prompt text) → `## Meta-level findings (route to plugin memory)`. Friction about the **environment this run actually executed in** (local filesystem, project tree, local tooling, project-specific paths and env) → `## Project-specific findings (route to project memory)`. When in doubt: would the same friction affect a different consumer running the same command? If yes, it's meta; if no, it's project-specific.

Emit one `###` block per event. If a section has no entries, emit a single `### No findings` placeholder so the section always carries at least one block.

Goes in `## Meta-level findings (route to plugin memory)`:

- **Default chosen in lieu of asking.** Any place the lead or curator would have prompted the user but chose a documented default. Record the ambiguity, the default chosen, and where it appeared.
- **Curator anomaly.** Curator returned 0 decisions despite ≥10 processed findings, used a disposition outside the allowed vocabulary, reported write errors, or its `summary` line conflicted with the `decisions` array length.
- **Corpus-shape per-file error.** A per-file error that reveals a class of malformed retros (missing frontmatter at scale, unrecognised heading variants surfacing in volume) — the friction is about synthesizer behavior, not this environment.

Goes in `## Project-specific findings (route to project memory)`:

- **Environment-rooted per-file error.** Per-file errors from Step 6 about local filesystem state (unreadable file, missing path, permission issue).
- **Anything else specific to this run's project tree.** Local tooling glitches, mis-set env vars, project-specific path assumptions that broke.

**7e. Do not annotate yourself.** Do not pre-fill any `_Curator: ..._` line on the meta-retro's findings. The next plugin-dev-mode `/base:retros-derive` run will harvest and annotate them via the same Step 4d convention.

---

## Step 8: Final report

Output to the user in this exact structure:

```
Mode: <consumer | plugin-dev>
Retros scanned: N
Findings processed: M  (un-annotated, passed to curator)
Findings skipped: K  (already annotated)
Decisions applied: <count and summary from curator>
Annotated source files: <list of absolute paths>
Meta-retro: <absolute path written>  OR  skipped (strict floor satisfied)
[Errors: <list of per-file errors, if any>]
```

- **N** = total number of files discovered in Step 2.
- **M** = total un-annotated plugin-bound finding blocks passed to the curator.
- **K** = total finding blocks skipped because they carried a `_Curator: .*_` line.
- **Decisions applied** = the `decisions` summary returned by the curator.
- **Annotated source files** = paths the curator's `annotate_retro` action successfully wrote to.
- **Meta-retro** = the absolute path written in Step 7, or the literal `skipped (strict floor satisfied)` when Step 7a's floor was met.
- The **Errors** line is omitted entirely when there are no errors.
- In consumer-mode the report is simply the short-circuit line from Step 1; none of the above fields apply.
