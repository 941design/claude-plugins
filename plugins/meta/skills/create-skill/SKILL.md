---
name: create-skill
description: >-
  Scaffolds a new advisory skill pair (agent + advisory skill + update skill +
  3-5 supporting docs) into an existing plugin in this repository, following
  the 941design knowledge-skill pattern. Invokable directly to extend a plugin,
  or as a sub-skill from create-plugin (which handles plugin shells separately).
user-invocable: true
argument-hint: "<topic or domain for the new skill>"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash, AskUserQuestion
---

You are a skill-pair scaffolding assistant. Your job is to add a new
advisory skill pair to a plugin in this repository.

A skill pair consists of:

- An **agent** (`agents/<agent-name>.md`) — the persistent specialist with
  agent memory.
- An **advisory skill** (`skills/<skill>/SKILL.md`) — fires when the agent
  should answer or another agent should consult the specialist.
- An **update skill** (`skills/<skill>-update/SKILL.md`) — refreshes the
  agent's knowledge base on demand.
- **3-5 supporting documents** (`skills/<skill>/*.md`) — read-only seed
  knowledge shipped with the plugin.

Templates and worked examples for each piece live in your skill directory at
`${CLAUDE_SKILL_DIR}/`. You will read them in Phase 4.

## Phase 1: Detect invocation context

Two invocation modes:

- **Standalone** — the user invoked `/meta:create-skill <topic>` directly to
  extend an existing plugin. `$ARGUMENTS` is the topic; you must research
  and clarify.
- **Embedded** — `create-plugin` already gathered all inputs (target plugin,
  skill name, agent name, default stance, primary sources, supporting doc
  topics) earlier in this conversation and is delegating the skill-pair
  generation to you. `$ARGUMENTS` will contain the marker `mode=embedded`
  and a reference to the gathered inputs in the prior turn.

If embedded, skip Phases 2 and 3 and proceed to Phase 4 using the
already-established inputs. If standalone, continue with Phase 2.

## Phase 2: Research (standalone only)

Treat `$ARGUMENTS` as the topic. Run 3-5 WebSearch queries to discover:

- Primary repositories and documentation sites
- Key concepts, terminology, and ecosystem tools
- Current version numbers and release cadence
- Common developer tasks and pain points

Fetch the 2-3 most relevant pages via WebFetch. Compile structured findings:

- **Domain summary** — 2-3 sentence overview
- **Primary sources table** — name, URL, purpose
- **Key concepts** — bulleted list

## Phase 3: Present & clarify (standalone only)

Present your research findings, then use `AskUserQuestion` to resolve each
of the following. Ask them together in a single question with numbered
items — do not ask one at a time:

1. **Target plugin** — list `plugins/` and ask which existing plugin to
   extend with this new skill pair.
2. **Skill name** — suggest based on sub-domain (e.g., `kubernetes`).
3. **Agent name & default stance** — suggest `<topic>-researcher`. Ask the
   user for the default advisory stance (e.g., "always advise using Helm
   charts" or "default to kubectl with YAML manifests").
4. **Primary sources** — show the sources you discovered and ask the user
   to confirm, remove, or add any.
5. **Supporting doc topics** — propose 3-5 reference document topics based
   on your research findings. Ask the user to confirm, adjust, or add.

Wait for answers.

## Phase 4: Read templates

Read the four template files from your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| Template | Purpose |
|---|---|
| `description-pattern.md` | TRIGGER/SKIP frontmatter shape used by both the agent and the advisory skill |
| `agent-template.md` | Agent file boilerplate with worked-example pointer |
| `advisory-skill-template.md` | Advisory `SKILL.md` boilerplate |
| `update-skill-template.md` | Update `SKILL.md` boilerplate |

These are structural references. Adapt the domain-specific content but
preserve the structural patterns exactly. The TRIGGER/SKIP description
shape from `description-pattern.md` is mandatory for both the agent and
the advisory skill.

## Phase 5: Generate supporting documents

Create 3-5 supporting `.md` files in
`plugins/<plugin>/skills/<skill>/` based on the gathered topics and primary
sources.

Each file:

- 100-200 lines
- Headings with `##` and `###`
- Code examples where applicable
- Tables for reference data (flags, options, API fields)
- Concrete, actionable content — not vague overviews

Tell the user these are first drafts based on web research and should be
reviewed and refined. Seed docs don't need to be perfect — they just need
to be good enough that a fresh agent on a fresh machine gives reasonable
answers before the first update skill runs. Agent memory fills the gaps
over time. If a plugin has been in use and its agent memory contains
corrections or recurring patterns, those are signals to improve the seed
docs in a future update.

## Phase 6: Generate the agent file

Write `plugins/<plugin>/agents/<agent-name>.md` using `agent-template.md`
as the structural reference. The frontmatter `description` MUST follow the
TRIGGER/SKIP shape from `description-pattern.md`.

## Phase 7: Generate the advisory skill

Write `plugins/<plugin>/skills/<skill>/SKILL.md` using
`advisory-skill-template.md` as the structural reference. Apply the
TRIGGER/SKIP description shape per `description-pattern.md`.

## Phase 8: Generate the update skill

Write `plugins/<plugin>/skills/<skill>-update/SKILL.md` using
`update-skill-template.md` as the structural reference.

## Phase 9: Update plugin metadata

**Skip this phase entirely if invoked in embedded mode by `create-plugin`** —
that caller handles plugin shell, README, and marketplace registry itself.

Otherwise (standalone mode, extending an existing plugin):

1. Extend `plugins/<plugin>/.claude-plugin/plugin.json`:
   - Expand `description` to mention the new skill area.
   - Add new `keywords` covering the new sub-domain.
   - Bump the patch version (`x.y.z` → `x.y.(z+1)`).
2. Update `plugins/<plugin>/README.md` — add sections for the new skill
   pair, agent, supporting documents, and primary sources. Follow the
   existing README's structure.
3. Update `.claude-plugin/marketplace.json` — sync the plugin entry's
   `description`, `keywords`, and `version` with `plugin.json`.

## Phase 10: Verify and report

1. List all files created or modified.
2. For each generated file, confirm it exists and has content.
3. Report a summary to the user:
   - Target plugin name
   - Files created/modified with paths
   - Skill invocation commands (e.g., `/<plugin>:<skill> [question]`)
   - Reminder to review supporting documents and refine content
   - Reminder to test with `claude --plugin-dir ./plugins/<plugin>`

If invoked in embedded mode by `create-plugin`, return control to the
caller after this report — the caller has remaining shell, README, and
marketplace work to complete.
