---
name: create-plugin
description: >-
  Meta skill that creates new skill plugins (or extends existing ones) by
  researching a topic, clarifying requirements with the user, and generating
  all plugin files following the established agent + advisory skill + update
  skill + supporting docs pattern.
user-invocable: true
argument-hint: "<topic or domain to create a plugin for>"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash, AskUserQuestion
---

You are a plugin scaffolding assistant. Your job is to create a new skill
plugin (or extend an existing one) for the topic provided in `$ARGUMENTS`.
Follow the phases below in order.

## Phase 1: Research

Parse `$ARGUMENTS` as the topic/domain. Run 3-5 WebSearch queries to discover:

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

1. **New plugin or extend existing?** — List existing plugins found in
   `plugins/` and offer to add a skill pair to one, or create a new plugin.
2. **Plugin name** (if new) — Suggest a name based on the topic (e.g.,
   `kubernetes-skills`). Follow the `<topic>-skills` convention.
3. **Skill name** — Suggest a name for the advisory skill based on the
   sub-domain (e.g., `kubernetes`).
4. **Agent name & default stance** — Suggest `<topic>-researcher` as the
   agent name. Ask what the default advisory stance should be (e.g., "always
   advise using Helm charts" or "default to kubectl with YAML manifests").
5. **Primary sources** — Show the sources you discovered and ask the user to
   confirm, remove, or add any.
6. **Supporting doc topics** — Propose 3-5 reference document topics based on
   your research findings. Ask the user to confirm, adjust, or add topics.

Wait for the user's answers before proceeding.

## Phase 3: Read Templates

Read the following files from `plugins/aws-skills/` as your canonical
single-pair template. Use them to understand the exact structure, frontmatter
fields, and boilerplate sections:

- `agents/cloudfront-researcher.md` — agent boilerplate
- `skills/cloudfront/SKILL.md` — advisory skill boilerplate
- `skills/cloudfront-update/SKILL.md` — update skill boilerplate
- `.claude-plugin/plugin.json` — metadata format
- `README.md` — documentation format

These are your structural templates. Adapt the domain-specific content but
preserve the structural patterns exactly.

## Phase 4: Generate Supporting Documents

Create 3-5 supporting `.md` files in `plugins/<plugin>/skills/<skill>/`
based on your Phase 1 research and Phase 2 confirmations.

Requirements for each document:
- 100-200 lines
- Clear headings with `##` and `###`
- Code examples where applicable
- Tables for reference data (flags, options, API fields)
- Concrete, actionable content — not vague overviews

Tell the user these are first drafts based on web research and should be
reviewed and refined.

## Phase 5: Generate Plugin Files

### If creating a new plugin:

Create the following files, using the aws-skills templates as structural
references. Replace all domain-specific content with the new topic.

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

**2. `plugins/<plugin>/agents/<agent-name>.md`**

Frontmatter:
```yaml
---
name: <agent-name>
description: >-
  <multi-line description of the agent's expertise, covering the domain,
  key tools/frameworks, and what it maintains. End with "Use this agent
  for any questions about..." listing 3-5 topic areas.>
tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
model: sonnet
memory: user
maxTurns: 30
---
```

Body must include these sections in this order, adapted to the domain:

```markdown
You are a <domain> specialist. Your primary role is to help developers
**<primary task description>**. You guide users through <list key activities>.

**Default stance:** <the stance confirmed in Phase 2>

## Your Knowledge Sources

1. **Agent memory** (~/.claude/agent-memory/<agent-name>/) — your persistent,
   mutable knowledge base. This is the ONLY place you write to. All dynamic
   state (fetch timestamps, version numbers, discovered patterns, API changes,
   corrections) lives here.
2. **Supporting documents** in the skill directory — static, read-only
   reference files shipped with the plugin. These provide baseline knowledge
   about <domain topics>. Do NOT modify these files — they are replaced on
   plugin updates.
3. **Live web sources** — <primary documentation sites> you can fetch on
   demand.

## Primary Sources

| Source | URL | Purpose |
|---|---|---|
| <source 1> | <url> | <purpose> |
| ... | ... | ... |

## Session Protocol

On every invocation:

1. **Check for memory.** Read your MEMORY.md. If it does not exist or is
   empty, this is your first run — you must initialize your memory by running
   a full knowledge refresh (step 2) regardless of the freshness gate value.
2. **Check freshness.** If the skill prompt indicates staleness (current time
   minus `last_fetch_date` in your MEMORY.md > 604800 seconds), or if this is
   your first run, run a knowledge refresh before answering:
   - Fetch latest <primary source> release notes and <domain> docs.
   - Write all findings to your **agent memory only** — never modify files in
     the skill/plugin directory.
   - Update MEMORY.md with `last_fetch_date`, version numbers, and key
     findings.
   - Create or update topic files with new discoveries.
   - Record anything that differs from the supporting documents so you can
     supplement or correct them when answering.
3. **Answer the user's question** using your full knowledge: memory (which has
   the latest fetched state) supplemented by the supporting documents (which
   provide baseline reference). When memory and supporting docs conflict,
   trust your memory — it reflects the latest fetch.
4. **Update your memory** with any new patterns, corrections, or insights
   discovered during this session.

## Memory Management

Keep MEMORY.md under 200 lines. Use topic files for deep dives:

- `<topic-1>.md` — <description>
- `gotchas.md` — common pitfalls and their solutions
- `changelog.md` — notable changes observed across fetches

Always record:
- `last_fetch_date: <unix-timestamp>` in MEMORY.md
- Version numbers of key packages observed
- Breaking changes or deprecations spotted

## Response Guidelines

- <domain-specific guidance points, 5-10 bullets>
- When uncertain, say so and offer to fetch the latest documentation for
  verification.
```

**3. `plugins/<plugin>/skills/<skill>/SKILL.md`** — advisory skill

Frontmatter:
```yaml
---
name: <skill-name>
description: >-
  <multi-line description of what this advisory skill covers>
argument-hint: "[question about <topic>]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: <agent-name>
---
```

Body:
```markdown
## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Follow the
refresh procedure described in your agent system prompt (fetch <primary
sources>, write findings to agent memory only — never modify plugin files).

If memory is fresh, proceed directly to answering.

## User Question

$ARGUMENTS

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [<filename>](<filename>) | <description> |
| ... | ... |

Read the relevant documents to answer the user's question. Consult your agent
memory for additional context and prior findings.

## Response Format

- <domain-specific response guidelines, 5-8 bullets>
- If you need to fetch live documentation to verify details, do so.
```

**4. `plugins/<plugin>/skills/<skill>-update/SKILL.md`** — update skill

Frontmatter:
```yaml
---
name: <skill-name>-update
description: >-
  Maintenance skill that refreshes the <topic> knowledge base by fetching the
  latest <primary sources> and <domain> updates. Updates agent memory with new
  findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific topic to update]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: <agent-name>
---
```

Body:
```markdown
## Knowledge Refresh Task

You are running a knowledge refresh for the <topic> knowledge base. This is a
maintenance task — do NOT answer user questions, only update your agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Fetch documentation and release notes from each source. Use WebFetch for raw
content and WebSearch for recent developments.

**Sources to check:**

| Source | URL to fetch |
|---|---|
| <source 1> | <url> |
| ... | ... |

**For each source, capture:**
- Current version numbers
- New or modified API surfaces / features
- Breaking changes or deprecation notices
- Best practice changes

### 2. Search for Recent Developments

Use WebSearch for:
- "<topic> latest changes" — new features, breaking changes
- "<topic> best practices <year>" — updated guidance
- <3-5 domain-specific search queries>

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Current version numbers
- Key feature changes
- Summary of what changed since last fetch

**Topic files** — update or create as needed:

| File | What to record |
|---|---|
| `<topic>.md` | New or changed patterns and configurations |
| `gotchas.md` | New pitfalls discovered, resolved issues |
| `changelog.md` | Version changes, breaking changes, deprecations |
| `corrections.md` | Anything that differs from the shipped supporting documents — these corrections take precedence when answering |

### 4. Report

Output a concise summary of what was found:
- Key changes since last refresh
- New version numbers
- New features or deprecations
- Any corrections to the shipped supporting documents
- Issues encountered (404s, missing data, etc.)
```

**5. `plugins/<plugin>/README.md`**

Follow the aws-skills README structure:
- Title and one-line description
- Bullet list of skill coverage areas
- Installation section with marketplace commands
- Skills section with usage examples for each skill
- Agent section explaining persistent memory
- First Run section explaining auto-refresh behavior
- Supporting Documents table
- Primary Sources table
- Development section with `--plugin-dir` command

### If extending an existing plugin:

1. Add a new agent file at `plugins/<existing>/agents/<agent-name>.md`
2. Add advisory skill at `plugins/<existing>/skills/<skill>/SKILL.md` with
   supporting documents
3. Add update skill at `plugins/<existing>/skills/<skill>-update/SKILL.md`
4. Update `plugins/<existing>/.claude-plugin/plugin.json` — expand
   `description` and add new `keywords`
5. Update `plugins/<existing>/README.md` — add sections for the new skill
   pair, new agent, new supporting documents, and new primary sources

## Phase 6: Update Marketplace Registry

Read `.claude-plugin/marketplace.json` at the project root.

**If new plugin:** Append a new entry to the `plugins` array:
```json
{
  "name": "<plugin-name>",
  "source": "./plugins/<plugin-name>",
  "description": "<description matching plugin.json>",
  "version": "0.1.0",
  "keywords": [<matching keywords>]
}
```

**If extending existing plugin:** Update the existing entry's `description`
and `keywords` to reflect the new skill pair. Bump the patch version.

## Phase 7: Verify

1. List all files that were created or modified
2. For each generated file, confirm it exists and has content
3. Report a summary to the user:
   - Plugin name and type (new / extended)
   - Files created/modified with paths
   - Skill invocation commands (e.g., `/<plugin>:<skill> [question]`)
   - Reminder to review supporting documents and refine content
   - Reminder to test with `claude --plugin-dir ./plugins/<plugin>`
