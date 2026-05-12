# Architecture — epic-next-modes

Living document. Read by every story's `base:integration-architect` and
`base:verification-examiner`. Updated when stories surface new seams.

## Paradigm

**Prompt-as-program inside a modular plugin.** `plugins/base/` is a
Claude Code plugin in which each top-level directory is a module of a
specific kind — commands (user entry points), agents (subagent
blueprints), skills (reference docs + utility workflows), schemas
(JSON Schema enforcement). The "code" is structured Markdown read at
runtime by Claude; the seams between modules are tool-mediated
(`Agent`, `Skill`, `SendMessage`, `Edit`/`Read`).

Boundary rule: cross-module access goes only through these tool seams.
A command does not invoke an agent except via the Agent tool; an agent
does not edit a skill's SKILL.md; a skill does not spawn an agent on
its own (it returns instructions for the lead to execute).

## Module map

This epic touches three modules:

| Module | Path | Owned by epic-next-modes? |
|---|---|---|
| commands | `plugins/base/commands/next.md` | **EDIT** — new Step 0, reworked Step 4, new Step 4a, frontmatter changes |
| specs (existing) | `specs/epic-base-next/spec.md` | **AMEND** — append `## Amendments` entry |
| specs (existing) | `specs/epic-base-next/acceptance-criteria.md` | **AMEND** — tighten AC-NEXT-2, revise AC-NEXT-9, split AC-NEXT-10 |
| specs (new) | `specs/epic-next-modes/*` | **CREATE** — already on disk (spec.md, acceptance-criteria.md, epic-state.json, exploration.json, mocks-registry.json, this file) |

Untouched modules: `plugins/base/agents/`, `plugins/base/skills/`,
`plugins/base/schemas/`, every other `plugins/base/commands/*.md`,
every other `specs/epic-*/`, `docs/adr/`, `.claude-plugin/`,
`package.json`, `scripts/`.

## Boundary rules

1. **No new commands.** This epic edits one existing command file
   (`next.md`). The plugin's auto-discovery of commands by file
   presence (no manifest enumeration) means a new command file would
   need no registration step — but that is out of scope.

2. **No new agents.** The dispatcher uses only built-in tools (`Read`,
   `Edit`, `Bash`, `AskUserQuestion`, `Skill`, with `Grep` added by
   this epic). It must not spawn subagents — see Design Decision 7
   (inline lead synthesis, not a subagent).

3. **No new skills.** The exploration surfaced a meta-level
   observation (no `skills/languages/markdown.md` exists) but creating
   one is explicitly out of scope for this epic.

4. **Cross-epic amendment goes through the spec's `## Amendments`
   section.** `epic-base-next`'s `spec.md` is amended; its
   `acceptance-criteria.md` is edited in place; both edits are part
   of S4. No other file in `specs/epic-base-next/` is touched.

5. **Frontmatter changes are atomic with their step changes.** S1
   updates the frontmatter (argument-hint, description,
   allowed-tools) and the new Step 0 in one edit pass. An examiner
   would catch divergence (frontmatter says `(no args) | auto` but
   Step 0 doesn't parse `auto`) as a failed SPEC question.

## Seams (cross-story dependencies)

Initially empty. The story-planner populates this section in Mode 2
if it identifies inter-story coupling. Expected to remain shallow:

- **S1 → S2/S3**: Step 0 (S1) sets `mode` which Steps 4 / 4a (S2 / S3)
  branch on. Contract: `mode ∈ {detail, auto}` is the only seam.
- **S2 / S3 ↔ S4**: The behavior described by S2/S3's ACs is what
  S4's amendment text to `acceptance-criteria.md` references. S4
  cites the new ACs verbatim. Order: S1 → S2 → S3 → S4 is the
  document-order ordering in `## Stories` and is the recommended
  implementation order.
- **All stories**: preserve the question-halt invariant (`AC-INV-1`)
  — neither mode auto-skips a leading `question` finding.

## Implementation constraints

Derived from `exploration.json`:

1. **Argument grammar follows the prefix/bare-token convention.**
   `auto` is a bare positional token, not `--auto`. Anchored to
   `feature.md:52-63` and `backlog/SKILL.md:37-43`.

2. **AskUserQuestion is described in prose, not as a JSON schema.**
   The `multiSelect` field, `header` field, and option-list shape
   are NOT enforced by any schema in this codebase. Step 4 (detail
   branch) describes options in numbered prose; the runtime model
   translates to the tool call. Downstream verification asserts the
   prose contract, not a JSON shape.

3. **Anchor line-window read uses explicit arithmetic.** `offset =
   max(1, line - 10)`, `limit = 21` (centered 21-line window). This
   is a NEW pattern this epic introduces — the prior corpus uses
   `awk`/`grep` or prose budgets. Future commands that need similar
   bounded context reads should cite this epic's Step 4a as the
   precedent.

4. **`(anchor file missing)` is a fixed string.** Any read failure
   (file not found, dir not found, permission denied, glob in path)
   produces the same fallback note appended to the paragraph.
   Verbatim, no variation by failure mode.

5. **Detail mode always renders + confirms** — including the
   1-actionable case. Auto mode never prompts — including when
   multiple actionable findings exist. Question-halt applies to
   both modes equally.

6. **No telemetry, no metrics, no state writes.** The dispatcher is
   stateless. The one-line "Dispatching as …" notice is UX
   feedback only — it is not logged anywhere.

7. **Verification for every story is Read-based textual assertion.**
   No test runner runs. Story-planner Mode 3 will phrase pre-impl
   questions as "does `plugins/base/commands/next.md` at
   line-range X contain the clause Y?". Examiners answer by reading
   the file. The YES/PARTIAL/NO verdict reduces to clause presence
   /absence, not behavioral test execution.

## Out of scope (architecture-level)

- A new `skills/languages/markdown.md` language skill. The
  examiner-protocol gap surfaced by exploration is real but is a
  separate meta-finding for the project curator (Step 6.3) to log.
- A general re-architecture of argument parsing across `/base:*`.
  This epic accepts the precedent and follows it.
- Persisting any paragraph text or routing decision. Synthesis is
  per-invocation; nothing caches between runs.
- A migration path for users who relied on the current Step 4 gate
  shape. Detail mode is a superset of that experience; auto mode is
  opt-in. No deprecation needed.

## ADR pointer

None. If this epic surfaces a decision worth promoting to ADR (e.g.
the centered-window Read pattern, or a Markdown-language skill carve-
out), the project-curator at Step 6.3 will propose it. No ADRs
constrain this epic at start.
