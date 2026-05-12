---
name: backlog
description: >-
  Owns `BACKLOG.md` — the project-level coordination file consumed by
  `/base:orient`, `base:project-curator`, `/base:feature`, and `/base:bug`. Single
  authority for the file's format (see `references/format.md`) and the canonical
  write path. Operations: `init` (scaffold + `CLAUDE.md` pointer + one-shot epic
  seeding), `add-finding` (append a file-anchored finding under `## Findings`),
  `resolve <marker>` (close a finding via `done→spec`, `done-mechanical`, or
  `rejected`). Use when the user wants to bootstrap a backlog, append a finding
  outside a `/feature` or `/bug` run, or close a finding inter-run.
user-invocable: true
argument-hint: "<op> [op-specific args]  —  ops: init | add-finding | resolve <marker>"
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

## Format authority

This skill owns the format of `BACKLOG.md`. The canonical spec is at
`${CLAUDE_SKILL_DIR}/references/format.md` — bullet grammar for every
section, the four resolution paths, the `## Epics` status mapping, the
tonality rules. Every other skill or agent that writes to `BACKLOG.md`
(the curator's `append_finding` / `append_rejection` proposals, the
`/feature` epic-section mutations) cites that reference rather than
restating the rules.

The seed file at `${CLAUDE_SKILL_DIR}/templates/seed.md` is intentionally
near-empty — three headings and placeholders. All policy and lifecycle
documentation lives in `references/format.md`, NOT inline in the on-disk
file.

---

## Dispatch

Read `$ARGUMENTS`. The first whitespace-separated token is the operation:

- `init` → `## Operation: init`
- `add-finding` → `## Operation: add-finding`
- `resolve <marker>` → `## Operation: resolve`
- anything else (or empty) → list the three ops with one-line summaries and
  exit. Do not guess.

All operations refuse to act outside a git repository — `BACKLOG.md` is
project state and belongs in version control. Detect via
`git rev-parse --show-toplevel`.

---

## Operation: init

Bootstraps two artifacts. Idempotent — running on an already-initialised
repo is safe; each substep checks its own precondition independently so the
skill can repair partial state.

```
1. Detect repo root (`git rev-parse --show-toplevel`).

2. Scaffold BACKLOG.md if missing.
     - If `<root>/BACKLOG.md` does NOT exist:
         a. Copy `${CLAUDE_SKILL_DIR}/templates/seed.md` to `<root>/BACKLOG.md`.
         b. Run the one-shot seeding pass below (step 3).
     - If it exists: do not overwrite. Skip step 3 but continue to step 4.

3. Seed `## Epics` from existing `specs/epic-*/` directories
   (one-shot, only when this op just created BACKLOG.md in step 2):
     - Find every `specs/epic-*/` directory.
     - For each, read `epic-state.json` and emit one bullet under
       `## Epics`:
         `- specs/epic-<slug>/ — <STATUS> — seeded by /base:backlog init YYYY-MM-DD`
       where `<STATUS>` derives from `epic-state.json#status` via the
       canonical mapping in `references/format.md` (`planning|in_progress`
       → `IN_PROGRESS`, `done` → `DONE`, `escalated` → `ESCALATED`). If
       `epic-state.json` is missing or malformed, write `UNKNOWN` and
       surface the dir in the final report.
     - Replace the placeholder `- _no epics yet_` line with the seeded
       bullets. If no spec dirs exist, leave the placeholder as-is.

4. Add the CLAUDE.md pointer if missing.
     - Read `<root>/CLAUDE.md` (create if missing — start with a minimal stub).
     - If the literal string `BACKLOG.md` is NOT already present anywhere
       in the file (cheap grep), append the pointer block:

           ## Project state
           Project orientation lives in `BACKLOG.md`. On a fresh session — or when
           resuming work after idle time — run `/base:orient` to get a 3-line
           "you are here" plus ranked next moves. Do not inline backlog content
           into this file.

     - If `BACKLOG.md` already appears in CLAUDE.md, leave it alone — the
       user may have customised the wording.

5. Report in 1–3 lines, distinguishing the four idempotent outcomes:
     - "Initialized: created BACKLOG.md (seeded N epics) + CLAUDE.md pointer."
     - "Repaired: BACKLOG.md was present; added missing CLAUDE.md pointer."
     - "Repaired: CLAUDE.md pointer was present; created BACKLOG.md (seeded N epics)."
     - "Already initialised: nothing to do."
   When epics were seeded, end with: "Run `/base:orient` to triage."
```

Why a skill, not a one-shot bash script: the pointer line in `CLAUDE.md`
is load-bearing for discoverability of the entire project-state
mechanism. Centralising it here keeps the convention single-sourced.

**Non-goals**: Does not migrate existing backlog-shaped files
(`TODO.md`, `TODO.org`, `BACKLOG.txt`); surface them and let the user
decide. Does not create `docs/adr/`. Does not populate `## Findings` or
`## Archive` — the `add-finding` op and the curator populate those as
work proceeds.

---

## Operation: add-finding

Append a file-anchored bullet under `## Findings`. The canonical user-invoked
write path for findings discovered outside a `/feature` or `/bug` run — keeps
tonality consistent with curator-proposed findings.

```
1. Read BACKLOG.md at repo root. Refuse if missing — point to
   `/base:backlog init`.

2. Ask the user via AskUserQuestion for:
     - anchor:  `path[:line]` or `-`
     - text:    one line, present tense, specific (the tonality rules in
                references/format.md apply — reject filler, first-person,
                multi-sentence prose, and ask the user to retry). The prose
                must be self-explanatory enough that `/base:next` can route
                it without a type tag — if the user's draft reads
                ambiguously, ask them to rephrase before writing.

3. If anchor is `-`, ask one follow-up: "no file applies because…?". If the
   user cannot articulate why no path applies, refuse — the format requires
   file-anchoring when applicable. (`-` is permitted for cross-cutting
   observations; "I haven't looked yet" is not a valid reason.)

4. Compose the bullet per `references/format.md`:
     `- <anchor> — <text> (YYYY-MM-DD)`
   where YYYY-MM-DD is today. Do not add a `[type]` prefix — the format no
   longer uses one.

5. Edit BACKLOG.md:
     - If `## Findings` still contains the placeholder `- _no findings yet_`,
       replace that line with the new bullet.
     - Otherwise append the new bullet at the end of the `## Findings`
       section (before the trailing `---` divider).

6. Report in 1 line: "Added <anchor>: <text-truncated>."

7. If the post-write count of findings now exceeds 15, surface a one-line
   nudge: "Findings now at N; consider `/base:orient` to triage."
```

---

## Operation: resolve

Closes the lifecycle on a single `## Findings` entry between `/feature` or
`/bug` runs. The curator's `resolve_finding_via_spec`,
`resolve_finding_mechanical`, and `move_finding_to_archive` actions handle
the in-run case; this op is the inter-run equivalent.

`<marker>` is a substring that uniquely identifies one `## Findings` bullet
(typically the path component of its anchor or the first few words of its
text).

The four resolution paths and where each lives:

| Path | Where it goes | Source |
|---|---|---|
| `done→spec` | spec amended, finding removed | this op OR curator |
| `done-mechanical` | finding removed; just commit | this op OR curator |
| `rejected` | archive entry, finding removed | this op OR curator |
| `promoted` | new `specs/epic-*/`, finding removed | `/base:feature backlog:<marker>` only |

```
1. Read BACKLOG.md at repo root. Refuse if missing — point to
   `/base:backlog init`.

2. Locate the matching finding bullet under `## Findings` using <marker> as
   a substring match.
     - Zero matches: list the current findings and ask the user to re-invoke
       with a more specific marker.
     - Multiple matches: list them and ask the user to disambiguate.

3. Show the matched bullet via AskUserQuestion. Ask which resolution path
   applies:

     a. done→spec — a spec was (or needs to be) amended. Ask for:
          - target spec path (default: search `specs/epic-*/` for one whose
            domain matches the finding's anchor)
          - AC ID to tighten OR "new" for a new AC
          - exact AC text (patch)
          - one-line amendment rationale

     b. done-mechanical — purely mechanical fix. Ask for:
          - one-line confirmation that the two-word test from
            `references/format.md` passes (could a future reader of any spec
            notice the change is missing?)
          Refuse if the user describes a behavior change — redirect to (a).

     c. rejected — finding will not be addressed. Ask for:
          - reason (durable, written verbatim to `## Archive`)

     d. promoted — bail with: "use `/base:feature backlog:<marker>`" — that
        flow scaffolds the spec and removes the finding atomically.

4. Apply the chosen path. All edits to BACKLOG.md happen in a single
   read-modify-write to avoid partial application:

     done→spec:
       - Apply the AC patch to the target spec's `acceptance-criteria.md`
         (or to `spec.md ## Acceptance Criteria` for older format).
       - Append an entry to `spec.md ## Amendments` (create the section
         immediately AFTER `## Non-Goals` if missing — canonical position
         per `base:spec-template`). The entry MUST cite the finding text
         verbatim so the audit trail links the amendment to its source.
       - Remove the finding bullet from `## Findings`.

     done-mechanical:
       - Remove the finding bullet from `## Findings`.
       - No spec edit, no archive entry. Git is the record.

     rejected:
       - Remove the finding bullet from `## Findings`.
       - Append an entry to `## Archive` in the canonical format from
         `references/format.md`:
           `- YYYY-MM-DD — <original finding text> — <reason>`

5. Report in 2–3 lines: which resolution path, which files touched, and
   (for done→spec) the AC ID that was added or tightened.
```

---

## Non-goals (skill-wide)

- **No promotion to epic.** That is `/base:feature backlog:<marker>`'s job —
  it scaffolds the spec dir, removes the finding, and falls through to NEW
  mode in one workflow. Duplicating that here would fragment the integration.
- **No batch operations.** One finding per `add-finding` or `resolve`
  invocation. The per-finding adjudication is the value; batching would
  reintroduce silent-edit failure modes.
- **No `## Epics` updates as a user-facing op.** Epic-section mutations are
  proposed by `base:project-curator` and applied by `/base:feature` /
  `/base:bug` (citing `references/format.md`). The `init` op's one-shot
  seeding is the only `## Epics` write this skill performs.
- **No archive entry for `done→spec` or `done-mechanical`.** Only
  `rejected` items are archived. Promotions and resolutions live in the
  spec or in git, not in the rejection log.

---

## Relationship to other components

- **`base:project-curator`** — the write-side proposal generator at the end
  of `/feature` / `/bug`. Proposes mutations as JSON; the lead applies them
  citing `references/format.md`. The `resolve` op here is the inter-run
  equivalent of the curator's `resolve_finding_via_spec`,
  `resolve_finding_mechanical`, and `move_finding_to_archive` actions.
- **`/base:orient`** — the read-side detector. Surfaces malformations
  against `references/format.md` (Rule 0), proposes `/base:backlog init`
  when the file is missing (Rule 1), and suggests
  `/base:backlog resolve <marker>` for findings whose lifecycle was closed
  in the user's head but not in the file (Rule 8).
- **`/base:feature backlog:<marker>`** — the promotion path. The `resolve`
  op bails to it when the user picks `promoted`.
