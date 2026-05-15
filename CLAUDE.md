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
