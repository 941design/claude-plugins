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

Locate the `## Findings` section. The canonical bullet grammar is:

```
- [<type>] <anchor> — <text> (YYYY-MM-DD)
```

where `<type>` ∈ { `bug` | `chore` | `question` | `observation` }.

If the section is absent, empty, or contains only the placeholder `- _no findings yet_`, exit with:

> No findings to dispatch. Run `/base:orient` for a project-wide view, or `/base:backlog add-finding` to log one.

---

## Step 3: Filter and Pick

Walk findings in **document order** — do not reorder by type, age, or any other heuristic.

### Type validation

For every finding encountered, validate its `[type]` prefix against the canonical set
`{ bug | chore | question | observation }` using a case-sensitive exact match. If a
finding's type is not in this set, abort with the offending bullet and the canonical set:

> Finding has unrecognized type `[<offending>]`. Canonical types are: bug, chore, question, observation. Fix the bullet in BACKLOG.md before dispatching.

Do NOT attempt fuzzy or case-insensitive matching.

### Question halt

If any `[question]` finding appears **before** the first actionable finding in document
order, surface the question verbatim and exit without dispatching:

> **Blocked by question finding:**
> `<full bullet text>`
>
> Resolve it before dispatching:
> - `/base:backlog resolve <marker> done-mechanical` — question answered, no spec change
> - `/base:backlog resolve <marker> done→spec:<path>` — answer is captured in a spec
> - `/base:backlog resolve <marker> rejected` — close without action

### Candidate selection

The first actionable finding (type ∈ { `bug`, `chore`, `observation` }) in document order
is the candidate.

---

## Step 4: Confirmation Gate

Count the total number of actionable findings (type ∈ { `bug`, `chore`, `observation` })
in `## Findings`.

**Exactly 1 actionable finding** → proceed to Step 5 immediately. No prompt.

**2 or more actionable findings** → show the top 3 actionable findings (in document order)
and ask via `AskUserQuestion`:

> Found N actionable findings. Top candidates:
>
> 1. `<bullet #1>`
> 2. `<bullet #2>` (if it exists)
> 3. `<bullet #3>` (if it exists)
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

Route by the selected finding's type:

```
[bug]                     → Skill("base:bug",     args: "backlog:<marker>")
[chore] | [observation]   → Skill("base:feature", args: "backlog:<marker>")
```

---

## Step 7: Return

Exit after the Skill call returns. Report the dispatched finding and which workflow
received it.
