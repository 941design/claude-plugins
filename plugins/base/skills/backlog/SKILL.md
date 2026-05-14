---
name: backlog
description: >-
  Owns `BACKLOG.md` — the project-level coordination file consumed by
  `/base:orient`, `base:project-curator`, `/base:feature`, and `/base:bug`. Single
  authority for the file's format (see `references/format.md`) and the canonical
  write path. Operations: `init` (scaffold + `CLAUDE.md` pointer + one-shot epic
  seeding), `add-finding` (append a slug-keyed, scope-tagged, file-anchored
  finding under `## Findings`), `resolve <slug>` (close a finding via `done→spec`,
  `done-mechanical`, or `rejected`), `migrate-v2` (idempotent migration of
  `## Findings` from v1 to v2 grammar). Use when the user wants to bootstrap a
  backlog, append a finding outside a `/feature` or `/bug` run, close a finding
  inter-run, or migrate a v1 BACKLOG.md.
user-invocable: true
argument-hint: "<op> [op-specific args]  —  ops: init | add-finding | resolve <slug> | migrate-v2"
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion, Grep
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
- `resolve <slug>` → `## Operation: resolve`
- `migrate-v2` → `## Operation: migrate-v2`
- anything else (or empty) → list the four ops with one-line summaries and
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

Append a slug-keyed, scope-tagged, file-anchored bullet under `## Findings`.
The canonical user-invoked write path for findings discovered outside a
`/feature` or `/bug` run — keeps tonality consistent with curator-proposed
findings.

```
1. Read BACKLOG.md at repo root. Refuse if missing — point to
   `/base:backlog init`.

2. Ask the user via AskUserQuestion for:
     - text:    one line, present tense, specific (the tonality rules in
                references/format.md apply — reject filler, first-person,
                multi-sentence prose, and ask the user to retry). The prose
                must be self-explanatory enough that `/base:next` can route
                it without a type tag — if the user's draft reads
                ambiguously, ask them to rephrase before writing.
     - anchor:  `path[:line]` or `-`
     - scope:   one of `base-plugin`, `<plugin-name>`, `<consumer-project>`,
                `any`. Default the AskUserQuestion option to the value
                inferred from anchor per `references/format.md ## Scope axis
                ### Inference at write/migrate time`:
                  - anchor starts with `plugins/base/` → `base-plugin`
                  - anchor starts with `plugins/<name>/` → `<name>`
                  - anchor is `-` or doesn't match → `any`
                Let the user override (e.g. a `-`-anchored finding that
                actually targets a specific plugin).

3. If anchor is `-`, ask one follow-up: "no file applies because…?". If the
   user cannot articulate why no path applies, refuse — the format requires
   file-anchoring when applicable. (`-` is permitted for cross-cutting
   observations; "I haven't looked yet" is not a valid reason.)

4. **Derive the slug** per `references/format.md ### Slug derivation`:
     a. Tokenise `text` on whitespace and punctuation; lowercase; drop
        stopwords (`the / a / an / is / are / and / or / to / of / in / on
        / for / this / that / it / be / do`).
     b. Take the first 4–6 meaningful words. Join with hyphens. Lowercase
        ASCII only; strip any non-ASCII. Max 50 chars; truncate at a word
        boundary if needed.
     c. If fewer than 4 meaningful words remain, refuse the write and
        ask the user to rephrase the text. There is no fallback ID
        scheme — the slug-as-identity invariant is load-bearing.
     d. Grep `## Findings` for the candidate slug at position 1. On
        collision, append `-2`. If `-2` exists, append `-3`. Etc.
     e. Display the derived slug to the user. If a discriminator suffix
        (`-2`, `-3`, …) was applied due to collision, surface it
        explicitly and offer an override prompt; otherwise no
        confirmation prompt is needed (the slug is deterministic).

5. Compose the bullet per `references/format.md ## Findings — bullet grammar (v2)`:
     `- <slug> [scope:<X>] — \`<anchor>\` — <text> (YYYY-MM-DD)`
   where YYYY-MM-DD is today. The anchor is always backticked except when
   it is the bare `-`. Do not add a `[type]` prefix — the format no longer
   uses one.

6. Edit BACKLOG.md:
     - If `## Findings` still contains the placeholder `- _no findings yet_`,
       replace that line with the new bullet.
     - Otherwise append the new bullet at the end of the `## Findings`
       section (before the trailing `---` divider).

7. Report in 1 line: "Added <slug> [scope:<X>]: <text-truncated>."

8. If the post-write count of findings now exceeds 15, surface a one-line
   nudge: "Findings now at N; consider `/base:orient` to triage."
```

---

## Operation: resolve

Closes the lifecycle on a single `## Findings` entry between `/feature` or
`/bug` runs. The curator's `resolve_finding_via_spec`,
`resolve_finding_mechanical`, and `move_finding_to_archive` actions handle
the in-run case; this op is the inter-run equivalent.

`<slug>` is the exact position-1 slug of one `## Findings` bullet. Slug
uniqueness is enforced at write time per
`references/format.md ### Slug derivation`, so lookup is a single
unambiguous match.

### Argument forms

The op accepts a `<slug>` plus an OPTIONAL action token that pre-selects
the resolution path. The action-token forms are what `/base:next` Step 6
dispatches when routing `(feature-work, amendment)` and `(*, mechanical)`
findings; the bare `<slug>` form is the interactive path used when a
human invokes `/base:backlog resolve <slug>` directly.

```
resolve <slug>                              [interactive — existing flow]
resolve <slug> done-mechanical              [pre-selected — skip top-level prompt]
resolve <slug> done→spec:<spec-path>        [pre-selected — skip top-level prompt + path prompt]
resolve <slug> rejected:<reason>            [pre-selected — skip top-level prompt + reason prompt]
```

**Backward-compat guarantee.** Invoking `resolve <slug>` with no action
token preserves the existing interactive flow verbatim — the top-level
`AskUserQuestion` for resolution path still fires and the user picks
one of the four paths. This op is safe to invoke either way; the action
token is purely an optimisation for non-interactive dispatchers.

### Parsing

```
tokens = $ARGUMENTS split on whitespace, with the leading `resolve`
         op token removed.
slug = tokens[0]    (required)

IF tokens has length >= 2:
    action_token = tokens[1] (joined with subsequent tokens when the
                              action's payload itself contains
                              whitespace — currently none of the
                              recognised action tokens do, but the
                              join is defensive).

    Match action_token against the prefixes:
      - exactly "done-mechanical"    → action = "done-mechanical",
                                        payload = None
      - starts with "done→spec:"      → action = "done→spec",
                                        payload = everything after
                                        "done→spec:" (the spec path)
      - starts with "rejected:"       → action = "rejected",
                                        payload = everything after
                                        "rejected:" (the reason)
      - anything else                 → REJECT with the four-op summary
                                        message (do not guess)
ELSE:
    action = None    (existing interactive flow applies)
```

The four resolution paths and where each lives:

| Path | Where it goes | Source |
|---|---|---|
| `done→spec` | spec amended, finding removed | this op OR curator |
| `done-mechanical` | finding removed; just commit | this op OR curator |
| `rejected` | archive entry, finding removed | this op OR curator |
| `promoted` | new `specs/epic-*/`, finding removed | `/base:feature backlog:<slug>` only |

```
1. Read BACKLOG.md at repo root. Refuse if missing — point to
   `/base:backlog init`.

2. Locate the matching finding bullet under `## Findings` by exact
   position-1 slug match (`grep -F "<slug>"` against the position-1
   token). Slug uniqueness is enforced at write time so this is a
   single unambiguous match.
     - Zero matches: list the current findings and ask the user to
       re-invoke with the correct slug.
     - >1 matches: the file is malformed (slugs should be unique).
       Surface the duplicates and point to `/base:backlog migrate-v2`
       (which dedups by appending `-2`, `-3`, … on collision).

3. **Resolution-path selection.**

   IF `action` was supplied via args (parsed above), SKIP the top-level
   "which resolution path?" `AskUserQuestion` and branch directly into
   the corresponding sub-flow:
     - `action == "done-mechanical"` → sub-flow (b), no confirmation
       prompt (the dispatcher has already classified the bullet as
       mechanical; the two-word test was applied at classification
       time). Proceed directly to step 4.
     - `action == "done→spec"` → sub-flow (a) with the target spec path
       set from `payload` (skip the path-selection prompt). The AC ID
       / AC text / amendment rationale prompts in sub-flow (a) STILL
       FIRE — those require user authorship and are not derivable
       from the dispatcher's args.
     - `action == "rejected"` → sub-flow (c) with the reason set from
       `payload` (skip the reason prompt). Proceed directly to step 4.

   ELSE (no `action`, i.e. interactive invocation), show the matched
   bullet via `AskUserQuestion` and ask which resolution path applies:

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

     d. promoted — bail with: "use `/base:feature backlog:<slug>`" — that
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
   (for done→spec) the AC ID that was added or tightened. When the op
   was invoked with an action token via args, prefix the report with
   `Resolved via args (<action>):` so audits can distinguish
   dispatcher-driven resolutions from interactive ones.
```

---

## Operation: migrate-v2

Idempotent migration of `## Findings` from v1 grammar to v2 grammar
(slug at position 1, scope token, backticked anchor at position 2,
unified `[DEFERRED:<reason>:<detail>]` stamp at position 3). See
`references/format.md ### Migration from v1 grammar` for the contract.

This op is auto-invoked by `/base:next` and `/base:orient` when they
detect v1 bullets at startup; it can also be run manually. Direct
worker invocations (`/base:bug`, `/base:feature`) do NOT auto-migrate
— they refuse and surface this command.

```
1. Read BACKLOG.md at repo root. Refuse if missing — point to
   `/base:backlog init`.

2. Locate the `## Findings` section. For each bullet:

   2a. **Detect grammar version.** Parse position 1 (the token before
       the first ` — `):
         - If position 1 is a bare kebab-case word (no backtick, no
           literal `-`, no whitespace-broken structure), the bullet is
           already v2 → skip.
         - Else (position 1 starts with backtick `` ` ``, the literal
           `-`, or position 3 contains `[INSUFFICIENT:` /
           `[ALREADY-RESOLVED:` / `Auto-dispatch aborted:`), the
           bullet is v1 → migrate per step 2b.

   2b. **Migrate the v1 bullet:**

       i.   **Extract fields from v1 shape**
            `- <anchor> — <text> (YYYY-MM-DD)`:
              - `<anchor>`: position 1 (may be backticked or bare).
                Strip backticks if present.
              - `<text>`: position 2 (everything between the ` — `
                separator and the ` (YYYY-MM-DD)` trailer).
              - `<date>`: the parenthesised trailer.

       ii.  **Detect and rewrite legacy stamps in `<text>`:**
              - Leading `[INSUFFICIENT: <gap>] ` → strip prefix; remember
                stamp = `[DEFERRED:spec-gap:<gap>]`.
              - Leading `[ALREADY-RESOLVED: <evidence>] ` → strip prefix;
                remember stamp = `[DEFERRED:already-resolved:<evidence>]`.
              - Contains substring `Auto-dispatch aborted:` anywhere →
                remember stamp =
                `[DEFERRED:legacy-orphan:<original-text-truncated-to-fit-80-char-framing>]`.
                Leave `<text>` as-is (the orphan tag captures the
                original framing; the bullet's text is unrecoverable
                structured signal).
              - No legacy stamp present → stamp = None (the bullet
                becomes a normal v2 finding).

       iii. **Derive slug** from the stripped `<text>` per
            `references/format.md ### Slug derivation`:
              - Tokenise, lowercase, drop stopwords, take first 4–6
                meaningful words, join with hyphens, max 50 chars.
              - Grep `## Findings` (post-migration in-progress state) for
                collisions at position 1; append `-2`, `-3`, … as needed.
              - If `<text>` is too short/generic to yield 4 meaningful
                words: **pause migration** and surface to the user:

                > Cannot derive slug for bullet: `<verbatim bullet>`. Rephrase the text and re-run `/base:backlog migrate-v2`.

                Exit without writing. The user fixes the bullet manually
                (edit the text in place) and re-runs. Migration is
                idempotent — already-migrated bullets are skipped on the
                re-run.

       iv.  **Infer scope** from `<anchor>` per
            `references/format.md ## Scope axis ### Inference at write/migrate time`:
              - starts with `plugins/base/` → `base-plugin`
              - starts with `plugins/<name>/` → `<name>`
              - is `-` or doesn't match → `any`

       v.   **Emit v2 bullet:**

              ```
              - <slug> [scope:<X>] — `<anchor>` — [DEFERRED:<reason>:<detail>] <text> (YYYY-MM-DD)
              ```

            Omit the `[DEFERRED:...]` prefix if `stamp == None`. The
            anchor is always backticked except when it is the bare `-`.

       vi.  **Edit BACKLOG.md** to replace the v1 bullet line with the
            v2 bullet line.

3. After all bullets processed, emit a one-line report:

   ```
   Migrated <N> bullets (<S> deferred). <M> skipped (already v2).
   ```

   Where:
     - `<N>` is the count of v1 bullets rewritten.
     - `<S>` is the subset of `<N>` that now carry a `[DEFERRED:...]` stamp.
     - `<M>` is the count of bullets that were already v2 (skipped).

   If `<N>` is zero and `<M>` is zero, report "No findings to migrate."
   If migration paused on an un-sluggable bullet, the report instead
   names that bullet and exits with a non-zero status (the user fixes
   and re-runs).
```

**Idempotency.** Running `migrate-v2` on an already-v2 BACKLOG.md is a
no-op (every bullet skips via step 2a). Running it on a partially
migrated file resumes from the first remaining v1 bullet.

**Out of scope.** This op does NOT migrate `## Archive` (already keyed
by date, not slug) or `## Epics` (already keyed by spec dir path).
Only `## Findings` is rewritten.

---

## Non-goals (skill-wide)

- **No promotion to epic.** That is `/base:feature backlog:<slug>`'s job —
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
  `/base:backlog resolve <slug>` for findings whose lifecycle was closed
  in the user's head but not in the file (Rule 8).
- **`/base:feature backlog:<slug>`** — the promotion path. The `resolve`
  op bails to it when the user picks `promoted`.
