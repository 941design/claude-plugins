---
name: create-plugin
description: >-
  Project-local meta skill that creates a new plugin in this repository (shell
  + plugin.json + README + marketplace entry) and delegates the skill-pair
  generation (agent + advisory skill + update skill + supporting docs) to the
  meta:create-skill skill. For adding a new skill pair to an *existing* plugin,
  invoke /meta:create-skill directly instead.
user-invocable: true
argument-hint: "<topic or domain to create a plugin for>"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash, AskUserQuestion, Skill
---

You are a plugin scaffolding assistant. Your job is to create a new skill
plugin in this repository for the topic provided in `$ARGUMENTS`. Plugin
shell creation lives here; the skill-pair (agent + advisory skill + update
skill + supporting docs) generation is delegated to the `meta:create-skill`
skill.

If the user actually wants to **add a new skill pair to an existing
plugin**, stop now and tell them to run `/meta:create-skill <topic>`
directly — that is the supported path for plugin extension.

## Phase 1: Research

Parse `$ARGUMENTS` as the topic/domain. Run 3-5 WebSearch queries to
discover:

- Primary repositories and documentation sites
- Key concepts, terminology, and ecosystem tools
- Current version numbers and release cadence
- Common developer tasks and pain points

Fetch the 2-3 most relevant pages via WebFetch. Compile structured findings:

- **Domain summary** — 2-3 sentence overview
- **Primary sources table** — name, URL, purpose
- **Key concepts** — bulleted list of core ideas a developer needs

## Phase 2: Present & Clarify

Present your research findings to the user, then use `AskUserQuestion` to
resolve each of the following. Ask them together in a single question with
numbered items — do not ask one at a time:

1. **Plugin name** — Suggest a name based on the topic (e.g.,
   `kubernetes-skills`). Follow the `<topic>-skills` convention.
2. **Skill name** — Suggest a name for the advisory skill based on the
   sub-domain (e.g., `kubernetes`).
3. **Agent name & default stance** — Suggest `<topic>-researcher` as the
   agent name. Ask what the default advisory stance should be (e.g.,
   "always advise using Helm charts" or "default to kubectl with YAML
   manifests").
4. **Primary sources** — Show the sources you discovered and ask the user
   to confirm, remove, or add any.
5. **Supporting doc topics** — Propose 3-5 reference document topics based
   on your research findings. Ask the user to confirm, adjust, or add
   topics.

Wait for the user's answers before proceeding.

## Phase 3: Create plugin shell

Create the plugin manifest and register it in the marketplace. The
skill-pair files (agent, advisory skill, update skill, supporting docs)
will be created by `meta:create-skill` in Phase 4. The README is generated
in Phase 5 once the skill-pair files exist.

**1. `plugins/<plugin>/.claude-plugin/plugin.json`**

```json
{
  "name": "<plugin-name>",
  "version": "0.1.0",
  "description": "<one-line description of the plugin's scope>",
  "author": {
    "name": "941design"
  },
  "repository": "https://github.com/941design/claude-plugins",
  "keywords": [<relevant keywords>]
}
```

**2. Update `.claude-plugin/marketplace.json`**

Append a new entry to the `plugins` array:

```json
{
  "name": "<plugin-name>",
  "source": "./plugins/<plugin-name>",
  "description": "<description matching plugin.json>",
  "version": "0.1.0",
  "keywords": [<matching keywords>]
}
```

## Phase 4: Delegate skill-pair generation to meta:create-skill

Invoke the `meta:create-skill` skill via the `Skill` tool. Pass an
`args` payload that signals embedded mode and references the inputs
already gathered in this conversation.

Recommended args string:

```
mode=embedded plugin=<plugin-name> skill=<skill-name>
agent=<agent-name> stance="<default-stance>"
sources="<comma-separated sources or 'see prior turn'>"
docs="<comma-separated topics or 'see prior turn'>"
```

Before invoking, ensure the most recent assistant turn in this
conversation contains the gathered inputs in clear prose so the embedded
skill can read them — pasted source list, doc topics, etc.

Invoke:

```
Skill(skill="meta:create-skill", args="mode=embedded ...")
```

`meta:create-skill` will, in embedded mode:

- Read its own templates from `plugins/meta/skills/create-skill/`.
- Generate `plugins/<plugin>/skills/<skill>/*.md` (3-5 supporting docs).
- Generate `plugins/<plugin>/agents/<agent-name>.md`.
- Generate `plugins/<plugin>/skills/<skill>/SKILL.md`.
- Generate `plugins/<plugin>/skills/<skill>-update/SKILL.md`.
- **Skip** plugin.json/README/marketplace updates — those are your job.

When `meta:create-skill` returns, verify the four expected paths exist
before proceeding to Phase 5.

## Phase 5: Generate the README

Create `plugins/<plugin>/README.md` now that the skill pair is in place.
Follow the structure used by `plugins/aws-skills/README.md`:

- Title and one-line description
- Bullet list of skill coverage areas
- Installation section with marketplace commands
- Skills section with usage examples for each skill
- Agent section explaining persistent memory
- First Run section explaining auto-refresh behavior
- Supporting Documents table (referencing the files meta:create-skill
  generated)
- Primary Sources table
- Development section with `claude --plugin-dir` command

## Phase 6: Verify

1. List all files that were created or modified.
2. For each generated file, confirm it exists and has content.
3. Report a summary to the user:
   - Plugin name (new)
   - Files created with paths
   - Skill invocation commands (e.g., `/<plugin>:<skill> [question]`)
   - Reminder to review supporting documents and refine content
   - Reminder to test with `claude --plugin-dir ./plugins/<plugin>`
   - Note that further skill pairs can be added via
     `/meta:create-skill <topic>`
