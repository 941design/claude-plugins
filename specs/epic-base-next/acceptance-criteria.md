# /base:next — Acceptance Criteria

## Terminology

- **Dispatcher** — the new `/base:next` command in
  `plugins/base/commands/next.md`.
- **Target command** — the command the dispatcher invokes via Skill
  (`/base:feature` or `/base:bug`).
- **Actionable finding** — a `## Findings` bullet whose `[type]` is one
  of `bug`, `chore`, or `observation`.
- **Marker** — the substring of a finding's bullet that uniquely
  identifies it inside `## Findings`. The dispatcher passes this string
  as the `backlog:<marker>` argument to the target command.

## Dispatcher File and Frontmatter

**AC-NEXT-1** — `plugins/base/commands/next.md` MUST exist with YAML
frontmatter declaring `name: next`, a `description` mentioning that the
command picks the next actionable finding and dispatches it,
`model: sonnet`, and `allowed-tools` including at minimum `Read`,
`Edit`, `Bash`, `AskUserQuestion`, and `Skill`.

**AC-NEXT-2** — The dispatcher MUST accept either no argument (interpreted as `detail` mode) or the literal token `auto` (interpreted as `auto` mode). The dispatcher MUST exit with a usage hint on any other argument. The `argument-hint` frontmatter field MUST be updated to reflect this two-mode grammar.

## Missing or Empty Backlog

**AC-NEXT-3** — If `BACKLOG.md` does not exist at the repo root, the
dispatcher MUST exit without invoking any target command and MUST print
a message that names `BACKLOG.md` and recommends running
`/base:backlog init`.

**AC-NEXT-4** — If `BACKLOG.md` exists but its `## Findings` section is
absent, empty, or contains only the documented placeholder
(`- _no findings yet_`), the dispatcher MUST exit without invoking any
target command and MUST print a message recommending `/base:orient` and
`/base:backlog add-finding` as next steps.

## Selection Rule

**AC-NEXT-5** — Within `## Findings`, the dispatcher MUST honor document
order. It MUST NOT reorder findings by type, age, or any other
heuristic.

**AC-NEXT-6** — If any `[question]` finding appears before the first
actionable finding in document order, the dispatcher MUST surface the
leading question verbatim, list the resolution paths available via
`/base:backlog resolve` (`done→spec`, `done-mechanical`, `rejected`),
and exit without invoking any target command. It MUST NOT skip over
questions to reach a later actionable finding.

**AC-NEXT-7** — Otherwise, the dispatcher MUST select the first
actionable finding (type ∈ {`bug`, `chore`, `observation`}) in document
order as the candidate.

**AC-NEXT-8** — If the matched type prefix in a finding bullet is not
one of the canonical values defined in
`plugins/base/skills/backlog/references/format.md` (case-sensitive,
exact match against `bug | chore | question | observation`), the
dispatcher MUST abort with a message naming the offending bullet and
the canonical set. It MUST NOT attempt fuzzy or case-insensitive
matching.

## Confirmation Gate

**AC-NEXT-9** — The 1-actionable-finding fast-path is mode-conditional. In `auto` mode, the dispatcher MUST proceed to dispatch without prompting regardless of actionable-finding count. In `detail` mode, the dispatcher MUST render the paragraph synthesis output and confirm via `AskUserQuestion` regardless of actionable-finding count (including the 1-finding case).

**AC-NEXT-10a** — In `detail` mode, the dispatcher MUST render the top-3 actionable findings (or fewer, if fewer exist) with classification labels and a synthesised paragraph per candidate, then present `AskUserQuestion` with options `Dispatch #1` (always when ≥1 candidate), `Dispatch #2` (only when #2 exists), `Dispatch #3` (only when #3 exists), and `Abort` (always). The dispatcher MUST NOT dispatch before the user responds.

**AC-NEXT-10b** — In `auto` mode, the dispatcher MUST skip the prompt entirely and dispatch the first actionable finding in document order, printing a one-line notice of the form `Dispatching as <classification>: <truncated-bullet>` before falling through to Step 5. The dispatcher MUST NOT invoke `AskUserQuestion` in `auto` mode.

## Marker Derivation and Uniqueness

**AC-NEXT-11** — The marker passed as the `backlog:<marker>` argument
MUST be a substring of the selected finding's bullet that, when grepped
case-sensitively against `## Findings`, matches exactly one bullet.

**AC-NEXT-12** — When the selected finding has a non-`-` anchor, the
dispatcher MUST prefer the anchor's path component as the marker. If
that substring is not unique, the dispatcher MUST extend it until
unique.

**AC-NEXT-13** — When the selected finding has anchor `-`, the
dispatcher MUST use the first 4–6 words of the finding's text as the
marker, extending until unique.

## Dispatch Routing

**AC-NEXT-14** — When the selected finding's type is `[bug]`, the
dispatcher MUST invoke `Skill("base:bug", args: "backlog:<marker>")`
and exit upon its return. The dispatcher MUST NOT invoke
`/base:feature` for a `[bug]` finding.

**AC-NEXT-15** — When the selected finding's type is `[chore]` or
`[observation]`, the dispatcher MUST invoke
`Skill("base:feature", args: "backlog:<marker>")` and exit upon its
return. The dispatcher MUST NOT invoke `/base:bug` for these types.

**AC-NEXT-16** — The dispatcher MUST NOT mutate `BACKLOG.md` itself.
All bullet removal MUST be performed by the target command, after that
command has successfully written its primary artifact
(`specs/epic-<slug>/epic-state.json` for `/base:feature`,
`bug-reports/{slug}-result.json` for `/base:bug`).

## /base:bug `backlog:<marker>` Mode

**AC-BUG-1** — `plugins/base/commands/bug.md` Step 1 MUST add a
detection branch: if the argument begins with `backlog:`, the input
mode MUST be set to `BACKLOG_PROMOTE`.

**AC-BUG-2** — In `BACKLOG_PROMOTE` mode, `bug.md` MUST read
`BACKLOG.md` and locate the finding whose bullet uniquely contains the
marker substring. If zero or more than one bullet matches, `bug.md`
MUST abort with the candidate set listed.

**AC-BUG-3** — If the matched finding's type is not `[bug]`, `bug.md`
MUST abort and recommend `/base:feature backlog:<marker>` instead. It
MUST NOT process a non-`[bug]` finding under bug.md's flow.

**AC-BUG-4** — In `BACKLOG_PROMOTE` mode, `bug.md` MUST scaffold
`bug-reports/{slug}-report.md` with the finding's text in the
description section, the finding's anchor in the reproduction-steps
section when the anchor is non-`-` (omit the anchor reference when the
finding's anchor field is `-`), and a `Source: BACKLOG.md finding
promoted YYYY-MM-DD` line.

**AC-BUG-5** — In `BACKLOG_PROMOTE` mode, `bug.md` MUST derive the
slug as kebab-case from the finding's text, capped at 40 characters,
and MUST confirm via `AskUserQuestion` when the derivation is
ambiguous.

**AC-BUG-5b** — In `BACKLOG_PROMOTE` mode, if `bug-reports/` already
contains a file whose name matches the derived `{slug}-report.md`, `bug.md`
MUST NOT silently overwrite it. It MUST ask the user via `AskUserQuestion`
and suggest a numbered suffix (e.g. `{slug}-2-report.md`) as the default.

**AC-BUG-6** — In `BACKLOG_PROMOTE` mode, `bug.md` MUST capture
`pending_finding_removal = <marker>` as in-session state. It MUST NOT
remove the source bullet from `BACKLOG.md ## Findings` at this point.

**AC-BUG-7** — `bug.md`'s closing step (the step that writes
`bug-reports/{slug}-result.json`) MUST, after that write succeeds and
only if `pending_finding_removal` is set, perform a single
read-modify-write on `BACKLOG.md` that removes the source bullet from
`## Findings`. The removal MUST be skipped silently if `BACKLOG.md`
does not exist.

**AC-BUG-8** — If the bug run aborts before
`bug-reports/{slug}-result.json` is written, the source bullet in
`BACKLOG.md ## Findings` MUST remain intact, leaving the half-scaffolded
`bug-reports/{slug}-report.md` for `/base:orient` to surface as drift.

**AC-BUG-9** — When `bug.md` Step 1 scaffolds a report in
`BACKLOG_PROMOTE` mode, it MUST persist the marker to
`bug-reports/{slug}-state.json` as a top-level field
`"backlog_marker": "<marker>"`. The Crash Recovery section MUST
instruct the lead: if `bug-reports/{slug}-state.json` contains a
non-null `backlog_marker` field AND `bug-reports/{slug}-result.json`
does not yet exist (i.e. the fix did not complete before the crash),
restore `pending_finding_removal = <marker>` as in-session state before
resuming. This ensures a crash-resumed `BACKLOG_PROMOTE` run can still
perform deferred bullet removal after `result.json` is eventually
written.

## /base:orient Cross-Reference

**AC-ORIENT-1** — When `/base:orient` Rule 8 fires (i.e. at least one
`[bug]` or `[chore]` finding has been on the list for ≥ 30 days without
resolution), the Rule 8 output block MUST include a suggestion line
recommending `/base:next` as a one-shot dispatch follow-up. The
suggestion MUST be conditional: it MUST NOT appear in orient output
when no qualifying stale finding exists. This MUST be additive — no
existing detection rule, Rule 8 trigger condition, or recommendation
behavior may change.

## Marketplace / Plugin Manifest

**AC-MANIFEST-1** — The `base` plugin uses file-presence-based command
discovery: any `.md` file placed in `plugins/base/commands/` with valid
YAML frontmatter is auto-registered as `/base:<name>`. No entry in
`plugin.json` or `marketplace.json` is required. This AC is satisfied
when `plugins/base/commands/next.md` exists with valid frontmatter
(verified by AC-NEXT-1 and AC-NEXT-2). There is no commands listing to
update in any manifest file.

## Non-Regression

**AC-NONREG-1** — `/base:feature backlog:<marker>` MUST continue to
function for direct user invocation exactly as documented at
`plugins/base/commands/feature.md:54-76` and `:248-260`. The
introduction of the dispatcher MUST NOT change `feature.md`'s control
flow.

**AC-NONREG-2** — `/base:bug <description>` and `/base:bug
@bug-report.md` invocations MUST continue to function as before. The
`BACKLOG_PROMOTE` branch is additive and MUST NOT alter the other input
modes.

**AC-NONREG-3** — `/base:orient` MUST remain read-only. The
cross-reference text addition (AC-ORIENT-1) MUST NOT introduce any
write operation, mutation, or Skill invocation into the orient flow.
