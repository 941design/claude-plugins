---
name: backlog
description: >-
  Owns `BACKLOG.json` — the project-level coordination file consumed by
  `/base:orient`, `/base:next`, `base:project-curator`, `/base:feature`, and
  `/base:bug`. Single authority for the file's format
  (`plugins/base/schemas/backlog.schema.json`) and the canonical write path
  (`scripts/`). Operations: `init` (scaffold + `CLAUDE.md` pointer + one-shot
  epic seeding), `add-finding`, `resolve <slug>`, `defer-stamp <slug>`,
  `add-epic`, `list`, `get`, `pick-next`, `render`, `query`, `migrate-v3`
  (one-shot v2-MD → v3-JSON conversion). Use when the user wants to bootstrap
  a backlog, append a finding outside a `/feature` or `/bug` run, close a
  finding inter-run, query backlog state, or migrate a legacy v2 BACKLOG.md.
user-invocable: true
argument-hint: "<op> [op-specific args]  —  ops: init | add-finding | resolve <slug> | defer-stamp <slug> | add-epic | list | get | pick-next | render | query | migrate-v3"
allowed-tools: Read, Bash, AskUserQuestion
---

## Format authority

The canonical format of `BACKLOG.json` is defined by the JSON Schema at
`plugins/base/schemas/backlog.schema.json`. All readers and writers cite
that schema rather than restating the rules. Every write script in
`scripts/` validates against the schema before committing a mutation —
the file cannot land in a malformed state.

The semantic policy that does not fit in a JSON Schema — resolution
paths, scope axis, scale axis, deferred-reason semantics, tonality —
lives in `references/format.md`.

## Where the writes happen

All mutations go through scripts in `${CLAUDE_SKILL_DIR}/scripts/`:

| Operation | Script | Purpose |
|---|---|---|
| `init` | `init.sh` | Scaffold BACKLOG.json + CLAUDE.md pointer; seed epics from `specs/epic-*/` |
| `add-finding` | `add-finding.sh` | Append a finding with slug derivation + scope inference + collision handling |
| `add-epic` | `add-epic.sh` | Append (or update) an epic entry |
| `resolve <slug>` | `resolve.sh` | Close a finding via `done`, `done-mechanical`, `rejected`, or `promoted` |
| `defer-stamp <slug>` | `defer-stamp.sh` | Set/clear `findings[i].deferred` from a worker abort |
| `list` | `list.sh` | Filter and print findings (compact, table, or JSON) |
| `get <slug>` | `get.sh` | Fetch a single finding |
| `pick-next` | `pick-next.sh` | Deterministic top-candidate selection for programmatic `/base:next auto` |
| `render` | `render.sh` | Terminal-friendly view (used by `/base:orient`) |
| `query <jq>` | `query.sh` | Arbitrary jq expression passthrough |
| `migrate-v3` | `migrate-v3.sh` | One-shot v2-MD → v3-JSON conversion |

Every script:
- Refuses to act outside a git repository.
- Uses atomic tmp+rename so concurrent runs cannot tear the file.
- Validates against the schema after every write.
- Stamps `updated_at` with an ISO 8601 timestamp.
- Requires `jq` (a hard dependency; checked at startup).

Consumers (the curator, `/base:bug` defer-stamp step, `/base:feature` epic
creation, `/base:retros-derive` curator dispatch) shell out to these
scripts. Direct `Edit` of `BACKLOG.json` from outside this skill is a
contract violation — the schema, atomic-write, and validation guarantees
only hold when every writer takes this path.

---

## Dispatch

Read `$ARGUMENTS`. The first whitespace-separated token is the operation;
the rest are op-specific arguments passed through to the script. Run the
matching script with `bash`, capture output, surface to the user.

```
init                                  → scripts/init.sh
add-finding [args...]                 → scripts/add-finding.sh [args...]
add-epic [args...]                    → scripts/add-epic.sh [args...]
resolve <slug> [args...]              → scripts/resolve.sh <slug> [args...]
defer-stamp <slug> [args...]          → scripts/defer-stamp.sh <slug> [args...]
list [args...]                        → scripts/list.sh [args...]
get <slug> [args...]                  → scripts/get.sh <slug> [args...]
pick-next [args...]                   → scripts/pick-next.sh [args...]
render [args...]                      → scripts/render.sh [args...]
query <jq-expr>                       → scripts/query.sh <jq-expr>
migrate-v3 [args...]                  → scripts/migrate-v3.sh [args...]
anything else (or empty)              → list ops with one-line summaries, exit
```

The skill is a thin dispatcher: it does not encode validation, format
rules, or routing in prose. Each script is self-documenting via `--help`
and `set -e`-driven error surfaces. When the user wants to know what
arguments an op takes, run the script with `--help`.

---

## Operation summaries

### `init`
Idempotent bootstrap. Creates BACKLOG.json if missing, seeds `epics[]`
from existing `specs/epic-*/` directories on first creation, adds the
project-root `CLAUDE.md` pointer. Reports one of four outcomes:
"Initialized", "Repaired: …", "Already initialised".

### `add-finding`
Interactive when invoked with no args. With args, takes
`--text "<one-line text>"` (required), `--anchor <path[:line]|path:N-M|->`
(required), `--scope <X>` (optional; inferred from anchor when omitted),
`--slug <slug>` (optional; derived from text when omitted),
`--created <YYYY-MM-DD>` (optional; defaults to today).

For interactive use, prompt the user via `AskUserQuestion` for text and
anchor, then call `add-finding.sh` with the collected args. Tonality
rules and slug-derivation refusals are enforced by the script.

### `add-epic`
Append or update an entry in `epics[]`. Takes `--path <specs/epic-foo/>`,
`--status <PLANNED|IN_PROGRESS|DONE|ESCALATED|UNKNOWN>`, optional
`--next-action "..."`.

### `resolve <slug>`
Close a finding via one of four paths:

```
resolve <slug> --as done-mechanical                    # remove only
resolve <slug> --as done --target <spec-path>          # remove; caller amends spec
resolve <slug> --as rejected --reason "..."            # remove + archive
resolve <slug> --as promoted --target <spec-path>      # remove; caller creates epic
```

The interactive form (just `resolve <slug>`) prompts the user via
`AskUserQuestion` for which path applies and gathers the missing
arguments, then re-invokes the script with `--as`.

For `done` and `promoted`, the spec amendment / epic creation is the
caller's responsibility. The script only mutates BACKLOG.json.

### `defer-stamp <slug>`
Set or clear `findings[i].deferred`. Used by `/base:bug` and
`/base:feature` workers when they abort with
`ABORT:DEFERRED:<reason>:<detail>`. The structured field replaces the v2
markdown stamp (a positional `[DEFERRED:…]` prefix in the bullet text).

```
defer-stamp <slug> --reason <ENUM> --detail "<text>" [--stamped-at YYYY-MM-DD]
defer-stamp <slug> --clear
```

Reason enum: `spec-gap | already-resolved | escalated | arch-debate-required | legacy-orphan`.

### `list`
Filter and print findings.

```
list [--status open|deferred|all] [--scope <X>] [--scope-prefix <X>]
     [--format compact|table|json] [--include-archive]
```

Defaults: `--status open --format compact`. The `--scope-prefix` form
matches the scope token OR the `anchor.path` prefix — useful for
"show me everything targeting plugins/base/".

### `get <slug>`
Single-finding lookup. `--field <name>` to print one field as a raw
string.

### `pick-next`
Deterministic top-candidate selector for programmatic dispatch.

```
pick-next [--scope <X>] [--scope-prefix <X>] [--include-deferred]
          [--format slug|json]
```

Selection: scope filter → exclude deferred → sort by created_at
ascending → first. Exit code 1 with "No actionable findings." when the
filter is empty.

This is the entrypoint a non-LLM `/base:next auto` driver uses. The
interactive form of `/base:next` may still rank with prose reasoning.

### `render`
Terminal-friendly view.

```
render --format orient            # full picture (epics + findings + archive)
render --format short             # one-line summary (counts)
```

`/base:orient` consumes `render --format orient`.

### `query <jq-expr>`
Thin passthrough for ad-hoc queries. The expression runs against the
full BACKLOG.json document.

### `migrate-v3`
One-shot v2-MD → v3-JSON conversion.

```
migrate-v3                # ./BACKLOG.md → ./BACKLOG.json, then `git rm BACKLOG.md`
migrate-v3 --dry-run      # emit to stdout, don't write
migrate-v3 --keep-md      # write JSON, don't delete BACKLOG.md
migrate-v3 --force        # overwrite an existing BACKLOG.json
```

Idempotent. Auto-invoked by `/base:orient` and `/base:next` on detection
of a v2 BACKLOG.md without a corresponding BACKLOG.json.

---

## Non-goals (skill-wide)

- **No promotion to epic.** Promotion is `/base:feature backlog:<slug>`'s
  job — that flow scaffolds the spec dir, calls `resolve.sh --as promoted`
  to remove the finding, and calls `add-epic.sh` to register the new
  epic.
- **No batch operations.** One finding per `add-finding` or `resolve`
  invocation. Batching reintroduces silent-edit failure modes.
- **No archive entry for `done`, `done-mechanical`, or `promoted`.** Only
  `rejected` writes to `archive[]`. Promotions and resolutions live in
  the spec or in git, not in the rejection log.

---

## Relationship to other components

- **`base:project-curator`** — the autonomous write-side at the end of
  `/feature` / `/bug` and during `/base:retros-derive`. Calls
  `add-finding.sh`, `resolve.sh`, `add-epic.sh`, and (for archive
  routing) `resolve.sh --as rejected` rather than editing the file
  directly.
- **`/base:orient`** — read-side renderer. Consumes
  `render --format orient`. Auto-invokes `migrate-v3` on detection of a
  v2 BACKLOG.md.
- **`/base:next`** — dispatch driver. Auto mode calls `pick-next`;
  interactive mode reads `list --format json` and ranks with prose
  reasoning. Auto-invokes `migrate-v3` on detection of a v2 BACKLOG.md.
- **`/base:bug`** and **`/base:feature`** workers — when aborting with
  `ABORT:DEFERRED:<reason>:<detail>`, call `defer-stamp.sh` to record
  the structured defer state.
- **`/base:feature backlog:<slug>`** — the promotion path. Calls
  `resolve.sh --as promoted` to atomically remove the source finding,
  then `add-epic.sh` to register the new epic.
