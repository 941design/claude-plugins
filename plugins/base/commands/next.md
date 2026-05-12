---
name: next
description: Pick the next actionable finding from BACKLOG.md and dispatch it to the right workflow (/base:bug or /base:feature). Runs in detail mode by default (renders top candidates with a prose paragraph and asks for confirmation) or auto mode (/base:next auto — silently dispatches the top actionable finding without prompting).
argument-hint: "(no args = detail) | auto"
allowed-tools: Read, Edit, Bash, AskUserQuestion, Skill, Grep
model: sonnet
---

# Backlog Dispatcher

You are a thin dispatcher. Your job is to pick the top actionable finding from `BACKLOG.md` and hand it to the right command. You do one dispatch and exit. You do not loop. You do not modify `BACKLOG.md` — that is the target command's responsibility.

## Input: $ARGUMENTS

Accepts an optional single positional token. Valid forms:

- `/base:next` — no argument; runs in **detail** mode (default).
- `/base:next auto` — single token `auto`; runs in **auto** mode (silent dispatch).

---

## Step 0: Parse Mode Argument

Parse `$ARGUMENTS` into a `mode` variable before any other step executes.

```
IF $ARGUMENTS is empty or whitespace-only:
    mode = "detail"
    proceed to Step 1

ELSE IF $ARGUMENTS is exactly the token "auto" (case-sensitive, exact match — "Auto", "AUTO", " auto", "--auto" do not qualify):
    mode = "auto"
    proceed to Step 1

ELSE:
    exit immediately with usage hint (do NOT proceed to Step 1):

    > Unrecognised argument. Valid forms:
    >   /base:next        — detail mode (renders top findings with synthesis, then asks)
    >   /base:next auto   — auto mode (silently dispatches the top actionable finding)
```

`mode` is exactly one of the two string literals `"detail"` or `"auto"`. It is set here and consumed by Step 4.

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

## Step 4: Mode-Gated Dispatch

**Pre-branch invariant (question-halt):** The question-halt check in Step 3
already ran before this step. If execution reaches Step 4, no leading `question`
finding was present — the first actionable candidate is a `bug` or `feature-work`.
Neither `auto` mode nor `detail` mode bypasses the question-halt; both modes rely
on Step 3's check firing before this branch. This satisfies AC-INV-1.

Branch on `mode` (set by Step 0):

---

### IF mode == auto

Select the candidate using the following rule: **the first actionable finding
in document order** from `## Findings` — the same position-1 candidate that
Step 3 identified. No re-scanning is needed; Step 3 already produced this.

Print exactly one notice line before proceeding — no other output, no prompt:

```
Dispatching as <classification>: <truncated-bullet>
```

Where:
- `<classification>` is exactly `bug` or `feature-work` (the label from Step 3).
- `<truncated-bullet>` is a non-empty excerpt of the selected finding's bullet text
  (truncate to approximately 60 characters, appending `…` if longer).

Do **not** invoke `AskUserQuestion`. Do not present any confirmation prompt. Fall
through immediately to Step 5 with the selected candidate.

The Skill dispatch in Step 6 will append ` auto` to the args when `mode == auto`,
signaling non-interactive mode to the downstream skill (`/base:feature` or `/base:bug`).
If the downstream skill cannot proceed without user input, it will append a question
finding to `BACKLOG.md` and return the literal abort signal `ABORT:UNDERSPECIFIED`,
which Step 6a inspects.

---

### IF mode == detail

Collect candidates: take the first 3 actionable findings in document order (the same
ordered list Step 3 produced — position 1, 2, 3). There may be fewer than 3.

For each candidate, invoke Step 4a to synthesise a paragraph. The anchor reads for
all candidates MAY be performed in parallel — they are independent.

Render the findings to the user:

```
## Top 3 actionable findings

**1.** <anchor#1> → <classification#1>
      <paragraph#1>

**2.** <anchor#2> → <classification#2>
      <paragraph#2>

**3.** <anchor#3> → <classification#3>
      <paragraph#3>
```

Omit any numbered entry for which no candidate exists. A single-candidate invocation
renders only the `**1.**` block — there is no special case that skips synthesis or the
prompt for the 1-finding scenario; detail mode always renders and always confirms.

Then invoke `AskUserQuestion` with the following options (conditional inclusion rule
stated explicitly):

- `Dispatch #1` — always present when at least one actionable finding exists.
- `Dispatch #2` — present **only when a second actionable finding exists** (i.e.
  the candidate list has ≥ 2 entries). Omit entirely when only 1 candidate exists.
- `Dispatch #3` — present **only when a third actionable finding exists** (i.e.
  the candidate list has ≥ 3 entries). Omit entirely when fewer than 3 candidates exist.
- `Abort` — always present.

On selection of `Dispatch #1`, `Dispatch #2`, or `Dispatch #3`: identify the
corresponding candidate and continue to Step 5 with that candidate.

On `Abort`: exit without dispatching.

---

## Step 4a: Paragraph Synthesis

Invoked once per candidate by Step 4 in `detail` mode. Executes inline by the lead
agent — no subagent is spawned (architecture.md Boundary Rule 2, Design Decision 7).

**Inputs.** A finding bullet (anchor + text + date) and the bullet's classification
(`bug` or `feature-work`).

**1. Parse anchor.** Extract the anchor field (the first token before ` — ` in the
bullet grammar). Three forms are recognised:

- `path:line` form — anchor contains a colon followed by a line number. Split into
  `path` and `line` (integer).
- `path` form (no `:line`) — anchor is a file path with no line number component.
  `line` is absent.
- `-` form — anchor is the literal `-`. No file path. Skip steps 2–3 entirely and
  proceed directly to step 4 (bullet-only composition).

**2. Read the anchor file.** Perform a bounded Read call:

- **With line:** Read the file using `offset = max(1, line - 10)` and `limit = 21`.
  This produces a centred 21-line window around the anchor line, with the offset
  clamped to line 1 for near-top anchors.
- **Without line:** Read the first 30 lines of the file (`offset = 1`, `limit = 30`).

Any read failure — file not found, directory not found, permission denied, anchor path
containing glob characters (`*`, `?`, `[`), or ambiguous path — is treated identically:
fall back to bullet-only composition (step 4) and append the literal string
`(anchor file missing)` to the paragraph. The fallback note text is fixed and does not
vary by failure mode.

**3. (Optional) Grep for context.** If cheaply available, grep the anchor file for the
nearest preceding heading (Markdown `#` or `##`) or function declaration (e.g. `def `,
`function `, `fn `, `func `) relative to the anchor line. Use the result to name the
surrounding section in the paragraph. Skip this step if the result is not obvious or the
file type does not lend itself to heading/function extraction — the paragraph is still
valid from bullet text and the read window alone.

**4. Compose paragraph.** Write 3–5 sentences that cover all three of the following
topics:

- **(a) What** — what the issue or opportunity is (drawn from the bullet prose,
  sharpened by the anchor file context).
- **(b) Where** — where the relevant code lives: named file, section heading, or
  function name. Use the anchor path and any heading/function found in step 3.
- **(c) Goal** — what resolving this finding accomplishes for the user or the system.

The paragraph must be self-contained: a reader who has not seen the raw bullet should
still understand what dispatching this finding would do.

**5. Return.** The paragraph as a single string with no trailing whitespace.

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

Route by the selected finding's classification (from Step 3). The args differ by
mode — auto mode appends a trailing ` auto` token that downstream skills detect for
non-interactive mode.

```
[when mode == detail]
bug             → Skill("base:bug",     args: "backlog:<marker>")
feature-work    → Skill("base:feature", args: "backlog:<marker>")

[when mode == auto]
bug             → Skill("base:bug",     args: "backlog:<marker> auto")
feature-work    → Skill("base:feature", args: "backlog:<marker> auto")
```

---

## Step 6a: Auto-Mode Abort Check (auto mode only)

This step runs only when `mode == auto`. Skip entirely in detail mode.

After the Skill call in Step 6 returns in auto mode, inspect the return output for the
literal string `ABORT:UNDERSPECIFIED`. If present:

1. Extract the gap description: take all text following the first `ABORT:UNDERSPECIFIED:`
   occurrence in the return output, trimmed. Use only the first such line if multiple exist.
2. Print:

```
Auto-dispatch aborted.
Reason: {extracted gap description}
A question finding has been added to BACKLOG.md.
Run /base:next (without auto) to work on the spec interactively.
```

Then exit. Do NOT attempt the next candidate. Auto mode processes exactly one item
regardless of result (success or abort).

---

## Step 7: Return

Exit after the Skill call returns. Report the dispatched finding and which workflow
received it.

In auto mode, Step 7 is reached after either a successful dispatch or an abort —
the skill exits after one dispatch attempt in either case.
