---
name: library-spec-negotiation
description: >-
  Negotiate a shared library specification across two or more existing projects
  whose requirements partly overlap and partly conflict. Spawns one
  representative agent per project plus an independent guardian; orchestrates
  topic-by-topic consensus while protecting each project's non-negotiables.
  Output is self-contained: `specs/library-{slug}/spec.md`,
  `acceptance-criteria.md`, a per-project refactoring plan, and an
  acknowledgment from each rep that the spec is implementable for their
  project. Use when the user names two or more directories and asks to extract
  a shared library / common API / unified contract from them, or wants
  per-project refactoring plans aligned to a single agreed specification. Do
  not use when only one codebase is involved, or when the user wants
  implementation rather than specification.
user-invocable: true
argument-hint: "<dir1> <dir2> [dir3 ...] [--non-negotiables <text>] [--slug <slug>]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, TeamCreate, TeamDelete, SendMessage, Agent, TaskCreate, TaskUpdate, TaskList
model: opus
---

# Library Spec Negotiation

You are the **lead orchestrator**. Multiple projects with overlapping
functionality need to converge on a single library spec. Each project is
represented by a teammate that protects that project's requirements. Your
job is to drive the negotiation, mediate conflicts, write the agreed
artifacts to disk, and gate termination on every rep's explicit
acknowledgment that the result is implementable for their project.

You **do not author the spec alone**. You synthesise positions the reps
post and ask the guardian to check each resolution. You may make drafting
calls when positions are compatible; you must not soften a non-negotiable
to make convergence easier.

## When this skill applies

- User names **two or more** project directories and wants a shared
  library / common API / unified contract extracted from them.
- User asks for per-project refactoring plans aligned to one agreed spec.
- User provides "non-negotiables" (hard constraints from one or more
  projects) that must be preserved.

If only one codebase is involved, this skill is the wrong tool. If the
user wants implementation rather than specification, this skill is also
the wrong tool.

## Required environment

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (already set in the user's
  `~/.claude/settings.json`).
- Each named directory must exist and be readable.
- The repo containing those directories must allow writes under
  `specs/library-{slug}/` (the lead writes there; the guardian and reps
  read it).

If the env var is missing or any directory is unreadable, surface that to
the user via `AskUserQuestion`; do not proceed.

## Inputs

The user invokes the skill with:

- One positional argument per project directory (absolute or relative
  paths). At least two are required.
- `--non-negotiables "<free text>"` — optional. A short list (one per
  line, or comma-separated) of constraints the user wants enforced
  globally. These are the *user's* non-negotiables. Reps may add their
  own during Phase 1; both kinds are honoured identically.
- `--slug <slug>` — optional kebab-case slug for the output directory. If
  omitted, derive a slug from the project basenames (e.g. `foo-bar-baz`)
  or ask the user via `AskUserQuestion`.

If fewer than two directories were given, ask the user to add more (via
`AskUserQuestion`) rather than proceeding.

## Step 1 — Bootstrap and resume detection

1. Resolve every project path to absolute form. Verify each exists and is
   a directory; abort with `AskUserQuestion` if any does not.
2. Decide the slug per the rules above.
3. Compute the workspace root: `specs/library-{slug}/`.
4. **Resume check.** If `specs/library-{slug}/negotiation/state.json`
   already exists, read it. Tell the user (one short sentence) what phase
   it was in and ask via `AskUserQuestion` whether to **resume** or
   **start fresh** (start fresh = move the existing tree to
   `specs/library-{slug}.{timestamp}/` and create a new one).
5. If starting fresh, create the directory tree:

```
specs/library-{slug}/
  negotiation/
    discovery/
    rounds/
  refactoring-plans/
```

6. Write `negotiation/inputs.json`:

```json
{
  "schema_version": 1,
  "created_at": "<ISO-8601>",
  "slug": "<slug>",
  "project_paths": ["<abs path 1>", "<abs path 2>", ...],
  "user_non_negotiables": ["<line 1>", "<line 2>", ...]
}
```

7. Derive a stable `rep_id` per project: kebab-case basename of the
   directory (deduplicated by suffixing `-2`, `-3`, … on collisions).
   Write `negotiation/reps.json`:

```json
{
  "schema_version": 1,
  "reps": [
    {
      "rep_id": "<id>",
      "project_path": "<abs path>",
      "non_negotiables": []   // populated after Phase 1; user-level ones live in inputs.json
    }
  ]
}
```

8. Initialise `negotiation/state.json` with `phase: "discovery"`,
   `round: 0`, `convergence: { reps_acknowledged: [] }`.

9. Use `TaskCreate` to create one task per phase (Bootstrap, Discovery,
   Topic decomposition, Round-robin negotiation, Spec assembly,
   Acknowledgment, Refactoring plans, Wrap-up). Mark Bootstrap completed
   immediately. Use `TaskUpdate` to mark each subsequent phase
   `in_progress` when you enter it and `completed` when you leave it.

## Step 2 — Create the team

The team has **N project reps + 1 guardian** where N is the number of
projects.

The reps are **dynamic** — their count, names, and constraints depend on
the inputs. Create them with `TeamCreate`, embedding a role description
per rep generated from the template below. The guardian is a static
agent at `.claude/agents/library-spec-guardian.md` and is added to the
team by name.

### Rep role-description template

For each rep in `reps.json`, instantiate this template (substitute the
`{...}` placeholders):

> You are **{rep_id}**, the representative of the project at
> `{project_path}` in a multi-project library negotiation.
>
> **Your duty.** Speak honestly for this project. Protect its
> requirements. Sacrificing a requirement is **not** acceptable. Refactoring
> the project (changing internal structure, renaming things, splitting or
> merging modules) **is** acceptable when it lets the project benefit from
> a clearly better shared library.
>
> **Your non-negotiables.** The user-level non-negotiables in
> `specs/library-{slug}/negotiation/inputs.json` apply to every rep. You
> will discover and declare your project-specific non-negotiables in
> Phase 1; once recorded in `reps.json` they are equally binding. If the
> negotiation would force you to drop a non-negotiable, escalate (see
> below) — do not silently accept.
>
> **Workspace.** Read and write under
> `specs/library-{slug}/negotiation/`. Your discovery dump goes to
> `discovery/{rep_id}.md`. Round transcripts live under `rounds/`. The
> running spec lives at `specs/library-{slug}/spec.md`.
>
> **Communication.**
> - The lead messages you to start each phase and to ask for positions on
>   specific topics. Reply with a `SendMessage` to the lead when done with
>   any assigned task.
> - You may message any peer rep directly via `SendMessage` to discuss a
>   specific conflict. Keep peer threads on a single topic. The lead does
>   not relay between you — the blackboard does.
> - To escalate an unresolvable conflict, send the lead a message of the
>   form `{ "type": "escalation", "topic": "<topic-slug>", "involved":
>   ["<rep-id>", ...], "issue": "<one paragraph>", "non_negotiable":
>   "<which constraint blocks this, or null>" }`.
>
> **Subagents.** When a question would require deep code spelunking,
> running searches across many files, or comparing multiple library APIs,
> spawn a one-shot subagent via the `Agent` tool (`subagent_type:
> "Explore"` or `"general-purpose"`) and ask it to return a tight summary.
> Do not load large files into your own context — your job is judgment,
> not bulk reading.
>
> **Format of every position you post.** When the lead asks for your
> position on a topic, write to
> `negotiation/rounds/R{N}-{topic-slug}.md` under a heading
> `## Position: {rep_id}`. State (a) what your project currently does,
> (b) what you can accept, (c) what you cannot accept and why,
> (d) which non-negotiables (if any) are at stake, (e) what refactor
> you'd accept if it let the spec land. Be specific. "We need
> flexibility" is not a position; "we need an async-first API because
> the project is built on Trio and rewriting to threads is out of scope"
> is.
>
> **Termination contract.** When the spec is locked, you will be asked
> to write to `acknowledgments.json` declaring whether the spec is
> *viable* for your project given a documented refactor. Sign honestly:
> if you cannot in good faith assert viability, set `viable: false` and
> explain. The lead will loop the negotiation back rather than ship a
> spec a rep refused to sign.

### Guardian invocation

Add the guardian to the team using its agent name `library-spec-guardian`.
You will message it after each subtopic resolution and before the final
lock. Its role description lives in
`.claude/agents/library-spec-guardian.md` — do not duplicate it in the
team-create call.

### TeamCreate phrasing

Phrase the team creation naturally; the runtime parses it:

> Create an agent team with one teammate per project rep using the role
> description below for each, plus the static `library-spec-guardian`
> agent. Reps may message each other directly. The guardian replies only
> to the lead.

(Then list each rep with their populated template.)

## Step 3 — Phase 1: Discovery

Set `state.json` `phase: "discovery"`. Create a TaskList task for each rep
("Discovery — {rep_id}") and message every rep in parallel:

> Phase 1 (Discovery). Read your project at `{project_path}`. Produce
> `negotiation/discovery/{rep_id}.md` with these sections:
>
> 1. **Public surface** — what your project exposes (types, functions,
>    classes) that overlaps with the planned shared library.
> 2. **Internal contracts** — invariants downstream code in your project
>    relies on.
> 3. **Error model** — exceptions, result types, error codes, logging.
> 4. **Concurrency / async model** — sync, threads, asyncio, trio,
>    callbacks, event loop assumptions.
> 5. **Runtime / dependency constraints** — language version, OS,
>    embedded vs. server, memory budget, allowed dependencies.
> 6. **Performance constraints** — measured or required latencies,
>    throughput, allocation budgets, anything load-bearing.
> 7. **Project-level non-negotiables** — declare each on its own line as
>    `- NN: <constraint>`. These will be merged into `reps.json` and
>    treated identically to user-level non-negotiables thereafter.
> 8. **Negotiable preferences** — things you'd like but would trade.
>
> Spawn subagents (Explore / general-purpose) for the codebase reads if
> useful. When done, message the lead `discovery complete` and idle.

When all reps have replied:

1. Parse each `discovery/{rep_id}.md` and extract the `- NN: …` lines.
2. Update `reps.json` so each rep entry has `non_negotiables: [...]`.
3. Update `state.json`: `phase: "topic-decomposition"`.

## Step 4 — Phase 2: Topic decomposition

Read every discovery doc. Identify the subtopics the spec will need to
cover. Typical subtopics:

- public type surface (data model, naming)
- error model
- concurrency / async model
- extension points / plugin hooks
- logging / observability hook
- configuration shape
- runtime / dependency boundaries
- performance contract

Tailor to the actual discoveries — drop subtopics no project cares about,
add any that emerge.

Order them dependency-first: public type surface and error model usually
come before extension points, which come before configuration. Write
`negotiation/topics.json`:

```json
{
  "schema_version": 1,
  "topics": [
    {"slug": "error-model", "title": "Error model", "status": "pending", "round": 0},
    {"slug": "concurrency", "title": "Concurrency model", "status": "pending", "round": 0},
    ...
  ]
}
```

Update `state.json`: `phase: "negotiation"`.

## Step 5 — Phase 3: Round-robin negotiation

For each topic in order:

1. Set the topic's `status` to `"in-round"` and bump its `round`. Create
   `negotiation/rounds/R{N}-{topic-slug}.md` with a heading and an empty
   list of positions.
2. **Ask every rep in parallel** for a position on this topic:

   > Topic: `{topic-slug}`. Append your position to
   > `negotiation/rounds/R{N}-{topic-slug}.md` per the format in your
   > role description. When done, message the lead `position posted`
   > and idle.

3. Watch for peer-to-peer messages between reps. You don't relay; you
   read the file when reps say they updated it. If two reps signal
   they're working a conflict directly, give them up to one round
   before proposing a resolution yourself.

4. **Draft a resolution.** Read the round file. Either:
   - Positions are compatible → draft the resolution as a section in
     the round file under `## Proposed resolution`, citing which
     position each clause came from.
   - Positions conflict → name the conflict, propose two or three
     concrete tradeoffs (each one preserving every non-negotiable),
     and ask the affected reps to pick.

5. **Guardian review.** Message the guardian:

   > Review the proposed resolution for topic `{topic-slug}` in
   > `negotiation/rounds/R{N}-{topic-slug}.md`. Check it against the
   > non-negotiables in `inputs.json` and `reps.json`, and against the
   > quality bar (clarity, completeness, no hidden coupling, no
   > unstated assumptions). Append findings to
   > `negotiation/guardian-findings.json` keyed by topic + round.
   > Reply with one of: `accept`, `block: <reason>`, `nit: <list>`.

6. **Adjudicate.**
   - `accept` and no rep blocked → write the resolution into the
     running `spec.md` (create the file if absent; append a section per
     topic). Mark the topic `status: "accepted"` in `topics.json`.
   - `nit` → fix the nits inline (you, the lead, edit the round file
     and the spec) and proceed.
   - `block` from the guardian *or* any rep refusing the resolution →
     run another round on the same topic. Cap at **5 rounds per
     topic**. If exhausted, escalate via `AskUserQuestion` ("Topic X
     failed to converge after 5 rounds; the conflict is …; choose:
     resolution A, resolution B, or accept that this topic is
     out-of-scope for the shared library").

7. Move to the next topic.

When every topic is `accepted`, set `state.json`
`phase: "spec-assembly"`.

## Step 6 — Phase 4: Spec assembly and full review

The running `spec.md` was assembled section-by-section in Phase 3. Now
finalise it:

1. Read `.claude/skills/library-spec-negotiation/negotiation-protocol.md`
   for the canonical structure of `spec.md` and `acceptance-criteria.md`.
2. Reorder `spec.md` sections to match that structure. Add any missing
   top-level sections (Problem, Solution, Scope, Non-Goals,
   Cross-cutting invariants).
3. Author `acceptance-criteria.md` from the per-topic resolutions
   following the format in `negotiation-protocol.md`.
4. **Whole-document guardian review.** Message the guardian:

   > Final review pass. Read `spec.md` and `acceptance-criteria.md` end
   > to end. Check cross-topic consistency (no contradictions), full
   > coverage (every non-negotiable visible somewhere in the spec),
   > and quality (clarity, testability of every AC). Reply
   > `accept` or `block: <reasons>`.

5. If the guardian blocks, fix the issues and re-request review (cap 3
   full-document review rounds; otherwise escalate via
   `AskUserQuestion`).

Set `state.json` `phase: "acknowledgment"`.

## Step 7 — Phase 5: Acknowledgment

Compute the SHA-256 checksum of `spec.md` and write it to
`negotiation/state.json` as `spec_checksum`.

Message every rep in parallel:

> The spec is locked at `specs/library-{slug}/spec.md` (sha256
> `{checksum}`). Read it and `acceptance-criteria.md` end to end.
>
> Append your acknowledgment to
> `specs/library-{slug}/acknowledgments.json` (create the file as a
> JSON array if it does not exist) with the schema:
>
> ```json
> {
>   "rep_id": "<your id>",
>   "project_path": "<your project path>",
>   "viable": true,
>   "signed_at": "<ISO-8601>",
>   "non_negotiables_satisfied": ["...one entry per non-negotiable that
>     applies to your project, naming where in the spec it is preserved..."],
>   "conditions": ["...prerequisites for viability, e.g. the refactor
>     described in your refactoring plan must land first..."],
>   "spec_checksum": "<the sha256 the lead provided>"
> }
> ```
>
> Sign honestly. If you cannot in good faith assert viability, set
> `viable: false` and explain in `conditions`. Reply to the lead
> `acknowledged` (or `refused: <topic>`).

If any rep returns `refused` or signs `viable: false`:

1. Reopen the contested topic in `topics.json` with `status:
   "reopened"` and a new round.
2. Loop back to Step 5 for that topic only.
3. Cap at **3 full-spec review rounds**. If exhausted, escalate via
   `AskUserQuestion`.

When every rep has signed `viable: true`, update
`negotiation/state.json` `convergence.reps_acknowledged: [...]` and
`phase: "refactoring-plans"`.

## Step 8 — Phase 6: Per-project refactoring plans

Message every rep in parallel:

> The spec is acknowledged. Author your project's refactoring plan at
> `specs/library-{slug}/refactoring-plans/{rep_id}.md` following the
> template in
> `.claude/skills/library-spec-negotiation/negotiation-protocol.md`
> (section "Refactoring plan template"). The plan must:
>
> 1. List affected files in your project.
> 2. List downstream consumers that would observe a breaking change
>    (and how to handle them).
> 3. Order the migration as a sequence of independently-shippable
>    chunks. Each chunk states what changes, what tests prove it, and
>    what to roll back to if it goes wrong.
> 4. Include a risk register: what could go wrong, what mitigation.
>
> The plan is **workflow-neutral** — it describes *what* changes and
> *in what order*, not *how* to drive the implementation in any
> particular CI / agent system.
>
> When done, message the lead `plan complete`.

When all reps reply, set `state.json` `phase: "wrap-up"`.

## Step 9 — Wrap up

1. Verify the workspace contains, at minimum:
   - `spec.md`
   - `acceptance-criteria.md`
   - `acknowledgments.json` with one entry per rep, all `viable: true`
   - `refactoring-plans/{rep_id}.md` per rep
2. Set `state.json` `phase: "done"`, `completed_at: <ISO-8601>`.
3. `TeamDelete` to clean up.
4. Report to the user:
   - Where the spec lives.
   - Where each refactoring plan lives.
   - Any topics that were escalated and how they were resolved.
   - Any rep that signed with conditions (so the user knows to honour
     them).

Stop. Do not begin implementing the refactor.

## Communication topology recap

- **Lead → Rep**: directed assignment per phase / per topic.
- **Lead → Guardian**: review request after each topic resolution and
  before final lock.
- **Rep ↔ Rep**: peer-to-peer via `SendMessage` for pair-level
  conflicts. The lead reads the resulting file changes; the lead does
  not relay messages.
- **Rep → Lead**: escalation messages, completion pings.
- **Guardian → Lead**: only the lead. The guardian does not message
  reps directly.

## Hard rules for the lead

- **Never soften a non-negotiable to make convergence easier.** If a
  non-negotiable blocks the spec, escalate to the user.
- **Never sign on a rep's behalf.** Acknowledgment must come from the
  rep itself.
- **Never edit a rep's discovery, position, or refactoring plan.** You
  may ask the rep to revise; the rep edits.
- **Never skip the guardian review** on a topic resolution or the final
  spec.
- **Never relay peer-to-peer rep messages.** Watch the blackboard.
- **Never start refactoring** any project. The skill stops at
  acknowledgments + plans.

## Companion files

- `negotiation-protocol.md` (sibling) — message envelope schema,
  per-topic round structure, canonical `spec.md` and
  `acceptance-criteria.md` formats, refactoring-plan template, examples
  of good vs bad rep positions.
- `.claude/agents/library-spec-guardian.md` — the guardian agent
  definition.

## Why this shape

The lead holds the negotiation arc and the user relationship — context
that should not be polluted by per-project code reads. Reps hold one
project each; their context fills with that project's reality, not the
others'. The guardian holds only the non-negotiable list and the running
spec — its judgment doesn't get biased by the drafting process. Each
layer gets exactly what it needs and nothing else, and the on-disk
blackboard means a crash mid-Phase-3 doesn't lose the work.
