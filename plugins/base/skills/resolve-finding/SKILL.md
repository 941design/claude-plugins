---
name: resolve-finding
description: >-
  Closes the lifecycle on a single `BACKLOG.md ## Findings` entry between
  `/feature` or `/bug` runs (when the user fixes or rejects something without
  invoking the workflow). Walks the user through the four resolution paths
  (`done→spec`, `done-mechanical`, `rejected`, `promoted`) and applies the
  edits — removing the finding bullet, appending an archive entry or spec
  amendment, or redirecting to `/base:feature backlog:` for promotion. Use
  when `/base:orient` lists a stale finding, when the user manually fixed an
  issue and wants to mark it resolved, or when triaging the backlog without a
  full feature run.
user-invocable: true
argument-hint: "<finding-marker — substring that uniquely identifies one ## Findings bullet>"
allowed-tools: Read, Edit, Write, Bash, AskUserQuestion
---

## Purpose

Closes the gap that the curator alone cannot — finding lifecycle outside
the `/feature` and `/bug` runs. The curator's `resolve_finding_via_spec`,
`resolve_finding_mechanical`, and `move_finding_to_archive` actions
handle the in-run case; this skill is the inter-run equivalent.

The four resolution paths and where each lives:

| Path | Where it goes | Source |
|---|---|---|
| `done→spec` | spec amended, finding removed | this skill OR curator |
| `done-mechanical` | finding removed; just commit | this skill OR curator |
| `rejected` | archive entry, finding removed | this skill OR curator |
| `promoted` | new `specs/epic-*/`, finding removed | `/base:feature backlog:<marker>` only |

## Operation

```
1. Read BACKLOG.md at repo root. Refuse if missing — point to /base:init-backlog.

2. Locate the matching finding bullet under ## Findings using $ARGUMENTS as
   a substring marker. If zero matches: list the current findings and ask
   the user to re-invoke with a more specific marker. If multiple matches:
   list them and ask the user to disambiguate.

3. Show the matched bullet to the user via AskUserQuestion. Ask which
   resolution path applies:

     a. done→spec — a spec was (or needs to be) amended. Asks for:
        - target spec path (default: search specs/epic-*/ for one whose
          domain matches the finding's anchor, present as default)
        - AC ID to tighten OR "new" for a new AC
        - exact AC text (patch)
        - one-line amendment rationale

     b. done-mechanical — the fix is purely mechanical (typo, dep bump,
        formatting, no behavior change). Asks for:
        - one-line confirmation that the two-word test passes
          (could a future reader of any spec notice the change is missing?)
        Refuse if the user describes a behavior change — redirect to (a).

     c. rejected — the finding will not be addressed. Asks for:
        - reason (durable, written verbatim to ## Archive)

     d. promoted — bail with: "use /base:feature backlog:<marker>" — that
        flow scaffolds the spec and removes the finding atomically.

4. Apply the chosen path. All edits to BACKLOG.md happen in a single
   read-modify-write to avoid partial application:

     done→spec:
       - Apply the AC patch to the target spec's acceptance-criteria.md
         (or to spec.md ## Acceptance Criteria for older format).
       - Append an entry to spec.md ## Amendments (create the section
         immediately AFTER ## Non-Goals if missing — that is the
         canonical position per base:spec-template; ## Amendments is the
         last section in the documented order). The entry MUST cite the
         finding text verbatim so the audit trail links the amendment to
         its source.
       - Remove the finding bullet from BACKLOG.md ## Findings.

     done-mechanical:
       - Remove the finding bullet from BACKLOG.md ## Findings.
       - No spec edit, no archive entry. Git is the record.

     rejected:
       - Remove the finding bullet from BACKLOG.md ## Findings.
       - Append an entry to BACKLOG.md ## Archive in the canonical
         format documented in init-backlog/BACKLOG-template.md:
         `- YYYY-MM-DD — <original finding text> — <reason>`
         (No `[rejected]` prefix — the section header is the category;
         orient validates the bare format. The `[rejected]` token in
         the template's "Resolution paths" subsection is a category
         tag for the lifecycle path, NOT a literal bullet prefix.)

5. Report what was done in 2-3 lines: which resolution path, which files
   touched, and (for done→spec) the AC ID that was added or tightened.
```

## What this skill never does

- **No promotion to epic.** That is `/base:feature backlog:<marker>`'s
  job — it scaffolds the spec dir, removes the finding, and falls
  through to NEW mode in one workflow. Duplicating that here would
  fragment the integration.
- **No batch resolution.** One finding per invocation. If the user has
  multiple findings to close, they invoke the skill multiple times. The
  per-finding adjudication is the value; batching would reintroduce the
  silent-edit failure mode.
- **No archive entry for `done→spec` or `done-mechanical`.** The
  template's lifecycle is explicit about this — only `[rejected]` items
  are archived. Promotions and resolutions are recorded in the spec or
  in git, not in the rejection log.

## Why a separate skill rather than just letting the curator handle it

The curator only runs at end-of-`/feature` or end-of-`/bug`. Findings
get fixed in many other ways: a quick manual edit, a PR from a
collaborator, a one-off bug fix that doesn't warrant the full bug
workflow, the user reading code and noticing the finding is moot. This
skill closes those lifecycles without forcing the user to either edit
BACKLOG.md by hand or kick off a full workflow.
