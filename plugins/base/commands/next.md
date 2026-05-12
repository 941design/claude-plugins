---
name: next
description: Pick the next actionable finding from BACKLOG.md and dispatch it to the right workflow (/base:bug or /base:feature).
argument-hint: (no arguments)
allowed-tools: Read, Edit, Bash, AskUserQuestion, Skill
model: sonnet
---

# Backlog Dispatcher

You are a thin dispatcher. Your job is to pick the top actionable finding from `BACKLOG.md` and hand it to the right command. You do one dispatch and exit. You do not loop. You do not modify `BACKLOG.md` — that is the target command's responsibility.

## Input: $ARGUMENTS

This command takes no arguments. Selection is internal.

---

## Step 1: Read BACKLOG.md

Read `BACKLOG.md` at the repo root. If it does not exist, exit with:

> No `BACKLOG.md` found. Run `/base:backlog init` to bootstrap project state.

---

## Step 2: Parse ## Findings

Locate the `## Findings` section. The bullet grammar (per
`plugins/base/skills/backlog/references/format.md`) is:

```
- <anchor> — <text> (YYYY-MM-DD)
```

A residual leading `[label]` token on any bullet (legacy from the
pre-prose-routing format) is part of the prose; ignore it for routing.
Do not abort on its presence.

If the section is absent, empty, or contains only the placeholder `- _no findings yet_`, exit with:

> No findings to dispatch. Run `/base:orient` for a project-wide view, or `/base:backlog add-finding` to log one.

---

## Step 3: Classify and Pick

Walk findings in **document order** — do not reorder by age or any other heuristic.

### Per-bullet classification

For every finding bullet, read its prose (anchor + text) and classify it into
exactly one of three buckets:

- **`bug`** — describes a defect: something is broken, fails, errors, regresses,
  or behaves incorrectly. Verbs like "fails", "crashes", "returns wrong", "leaks",
  "silently drops" signal this.
- **`question`** — describes an undecided behavior, unresolved scope, or pending
  decision. Verbs and shapes like "should X be A or B?", "is X correct?",
  "undocumented whether…", "unclear if…", "TBD", "waiting on…", trailing `?`
  signal this. A bullet is a question when no implementation can proceed
  without a human decision first.
- **`feature-work`** — everything else: chores, observations, cleanups,
  enhancements, refactors, additions. Anything actionable that isn't a bug
  and isn't blocked on a decision.

When in doubt between `feature-work` and `bug`, prefer the classification
that lets the right workflow take over — `/base:bug` is for defects with a
reproduction; `/base:feature` handles everything else, including chores so
small they barely warrant a story.

### Question halt

If any finding classified as `question` appears **before** the first
non-question finding in document order, surface the bullet verbatim and exit
without dispatching:

> **Blocked by an open question:**
> `<full bullet text>`
>
> Resolve it before dispatching:
> - `/base:backlog resolve <marker> done-mechanical` — question answered, no spec change
> - `/base:backlog resolve <marker> done→spec:<path>` — answer is captured in a spec
> - `/base:backlog resolve <marker> rejected` — close without action

### Candidate selection

The first finding classified as `bug` or `feature-work` (i.e. not `question`)
in document order is the candidate.

---

## Step 4: Confirmation Gate

Count the total number of actionable findings (classified as `bug` or
`feature-work`) in `## Findings`.

**Exactly 1 actionable finding** → state the classification in one line
("Dispatching as a bug" / "Dispatching as feature-work") and proceed to
Step 5. No prompt.

**2 or more actionable findings** → show the top 3 actionable findings (in
document order) with their classifications and ask via `AskUserQuestion`:

> Found N actionable findings. Top candidates:
>
> 1. `<bullet #1>` → would dispatch as <bug|feature-work>
> 2. `<bullet #2>` (if it exists) → <classification>
> 3. `<bullet #3>` (if it exists) → <classification>
>
> Options: (1) dispatch #1, (2) pick a different one from the list above, (3) abort

Do NOT dispatch before the user responds. If the user picks a different finding from the
list, use that finding as the candidate for Steps 5–6.

---

## Step 5: Derive Unique Marker

The marker must uniquely identify the selected finding — when grepped case-sensitively
against `## Findings`, it must match **exactly one bullet**.

**If the finding's anchor is not `-`:** use the anchor's path component (the part before
any `:line` suffix) as the initial marker candidate.

**If the anchor is `-`:** use the first 4–6 words of the finding's text as the initial
marker candidate.

**Uniqueness check:** Grep `## Findings` for the candidate. If more than one bullet
matches, extend the candidate (add the next word or path segment) and recheck. Repeat
until exactly one match.

---

## Step 6: Dispatch via Skill

Route by the selected finding's classification (from Step 3):

```
bug             → Skill("base:bug",     args: "backlog:<marker>")
feature-work    → Skill("base:feature", args: "backlog:<marker>")
```

---

## Step 7: Return

Exit after the Skill call returns. Report the dispatched finding and which workflow
received it.
