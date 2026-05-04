# meta

Meta tooling for the 941design Claude Code plugin repository. Scaffolds new
advisory skill pairs into existing plugins, following the established
knowledge-skill pattern (agent + advisory skill + update skill + 3-5
supporting docs).

## Skills

### `/meta:create-skill <topic>`

Adds a new advisory skill pair to an existing plugin. Walks through:

1. Web research on the topic.
2. Clarification of target plugin, skill name, agent name, default stance,
   primary sources, and supporting doc topics.
3. Generation of:
   - 3-5 supporting documents in `plugins/<plugin>/skills/<skill>/*.md`
   - Agent file at `plugins/<plugin>/agents/<agent-name>.md`
   - Advisory skill at `plugins/<plugin>/skills/<skill>/SKILL.md`
   - Update skill at `plugins/<plugin>/skills/<skill>-update/SKILL.md`
4. Update of `plugin.json`, `README.md`, and `marketplace.json`.

Also invoked as a sub-skill by the project-level `/create-plugin` skill,
which handles plugin shell, README, and marketplace registry on its own and
delegates the skill-pair generation to `meta:create-skill`.

## Templates

The `create-skill` skill ships with four template files used during
generation:

| Template | Purpose |
|---|---|
| `description-pattern.md` | TRIGGER/SKIP frontmatter shape (mandatory for agent and advisory skill) |
| `agent-template.md` | Agent file boilerplate with worked-example pointer |
| `advisory-skill-template.md` | Advisory `SKILL.md` boilerplate |
| `update-skill-template.md` | Update `SKILL.md` boilerplate |

Each template references a worked example in `plugins/aws-skills/cloudfront`
so the resulting skill can be diffed against a real, shipped pair.

## Installation

This plugin is registered in the repo's `.claude-plugin/marketplace.json`.
Install via:

```bash
/plugin install meta@941design
```

Or run locally:

```bash
claude --plugin-dir ./plugins/meta
```

## Relationship to `create-plugin`

`create-plugin` is a project-local skill at `.claude/skills/create-plugin/`
(not part of any plugin) because plugin scaffolding is specific to this
repo's layout (`plugins/<name>/`, marketplace registry, version policy).

`meta:create-skill` is generic skill-pair scaffolding — it operates inside
a plugin directory and could in principle ship to any repo following the
same layout convention.
