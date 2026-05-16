# General Guidelines

+ NEVER bump versions on your own. There is a process for it.

## Project state
Project orientation lives in `BACKLOG.json` (machine-readable;
validated by `plugins/base/schemas/backlog.schema.json`). On a fresh
session — or when resuming work after idle time — run `/base:orient`
to get a 3-line "you are here" plus ranked next moves. From the shell,
use `plugins/base/skills/backlog/scripts/list.sh` to inspect findings
or `scripts/render.sh --format orient` for a full view. Do not inline
backlog content into this file.

## Design rationale for workflows

LLMs are the runtime for every skill, command, and agent in this repo.
That makes rigid rule cascades brittle: an `IF A then X ELSE IF B then Y`
structure that looks deterministic on paper gets mis-applied under
cognitive load, especially when branches share evidence (e.g. a string
prefix that matches more than one case). Workflows here should give the
LLM **evidence and reasoning principles**, not decision-tree control
flow. When information is incomplete, inconsistent, or contradictory,
the workflow itself owns the adjudication — by reasoning, surfacing to
the user, or aborting with a deferred stamp — rather than gating on a
brittle rule that may not match reality.

Existing examples to extend rather than reinvent:
`plugins/base/agents/verification-examiner.md` (confidence scoring with
`0.5 = judgment call`), `plugins/base/agents/story-planner.md`
(conservative default: never emit `true` on missing or uncertain data),
`plugins/base/agents/project-curator.md` (autonomous decisions with
mandatory recorded reasoning). Deterministic computation (file paths,
JSON parsing, slug derivation, script invocations) stays deterministic.
Classification, routing, and adjudication are reasoning tasks — frame
them as such.
