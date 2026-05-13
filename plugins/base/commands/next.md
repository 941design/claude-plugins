---
name: next
description: Pick the next actionable finding from BACKLOG.md and dispatch it to the right workflow (/base:bug or /base:feature). Runs in detail mode by default (renders top candidates with a prose paragraph and asks for confirmation) or auto mode (/base:next auto — silently dispatches the top actionable finding without prompting).
argument-hint: "(no args = detail) | auto | <hint> [auto]"
allowed-tools: Read, Edit, Bash, AskUserQuestion, Skill, Grep
model: sonnet
---

# Backlog Dispatcher

You are a thin dispatcher. Your job is to pick the top actionable finding from `BACKLOG.md` and hand it to the right command. You do one dispatch and exit. You do not loop. You do not modify `BACKLOG.md` — that is the target command's responsibility.

## Input: $ARGUMENTS

Accepts an optional argument string. Valid forms:

- `/base:next` — no argument; runs in **detail** mode (default).
- `/base:next auto` — single token `auto`; runs in **auto** mode (silent dispatch).
- `/base:next <hint>` — free-text content hint; runs in **detail** mode and
  short-circuits selection to the bullet that best matches the hint.
- `/base:next <hint> auto` — hint plus trailing `auto`; auto-dispatches the
  hint-matched bullet without confirmation.

---

## Step 0: Parse Mode Argument

Parse `$ARGUMENTS` into `mode` and `hint` variables before any other step
executes. Both are consumed by Steps 3 and 4.

```
trimmed = $ARGUMENTS with leading/trailing whitespace removed.

IF trimmed is empty:
    mode = "detail"
    hint = None

ELSE IF trimmed == "auto" (case-sensitive, exact match — "Auto", "AUTO",
                           "--auto" do NOT qualify; a leading/trailing
                           space was already stripped above):
    mode = "auto"
    hint = None

ELSE:
    # trimmed is non-empty and is not the bare token "auto".
    # Check for a trailing auto-mode token.
    tokens = trimmed split on whitespace.
    IF tokens has length ≥ 2 AND the LAST token == "auto" (case-sensitive):
        mode = "auto"
        hint = tokens[:-1] rejoined with single spaces
    ELSE:
        mode = "detail"
        hint = trimmed

    # hint is now a non-empty string; mode is "detail" or "auto".

proceed to Step 1.
```

`mode` is exactly one of `"detail"` or `"auto"`. `hint` is either `None`
(no hint supplied; document-order walk applies) or a non-empty string
(hint-mode dispatch, see Step 3).

There is no longer a strict-exit branch on unrecognised arguments —
anything that is not empty and is not exactly `auto` is interpreted as
a content hint. Hint matching itself can still fail (Step 3 handles
zero-match and ambiguous-match cases).

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

Two paths: **hint short-circuit** (when `hint != None` from Step 0) or the
default **document-order walk**.

### Per-bullet classification

For every finding bullet, read its prose (anchor + text) and classify it
into exactly one of four buckets:

- **`insufficient`** — the bullet's `<text>` (everything between ` — ` and
  ` (YYYY-MM-DD)`) begins with the literal token `[INSUFFICIENT:`. The
  bullet was stamped by a prior `/base:next auto` dispatch whose target
  returned `ABORT:UNDERSPECIFIED`. See
  `plugins/base/skills/backlog/references/format.md` for the stamp
  grammar. These are **deferred**, not blocking — the walk treats them
  as not-present.
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

### Default path: document-order walk (when `hint == None`)

Walk findings in **document order** — do not reorder by age or any other
heuristic. **Skip every bullet classified as `insufficient`** as if it
were not in the file (do not surface, do not count toward question-halt
or the top-3 list).

**Question halt** — if any finding classified as `question` appears
**before** the first non-question, non-insufficient finding in document
order, surface the bullet verbatim and exit without dispatching:

> **Blocked by an open question:**
> `<full bullet text>`
>
> Resolve it before dispatching:
> - `/base:backlog resolve <marker> done-mechanical` — question answered, no spec change
> - `/base:backlog resolve <marker> done→spec:<path>` — answer is captured in a spec
> - `/base:backlog resolve <marker> rejected` — close without action

**Candidate selection** — the first finding classified as `bug` or
`feature-work` (skipping `insufficient` bullets, halting on a leading
`question`) is the candidate.

### Hint path: content-overlap match (when `hint != None`)

Skip the document-order walk. Instead, narrow `## Findings` to the single
bullet whose content best matches the hint:

1. Tokenize `hint` on whitespace and punctuation, lowercase, then drop
   stopwords: `the / a / an / is / are / and / or / to / of / in / on /
   for / this / that / it / be / do`. Call the result `hint_tokens`. If
   `hint_tokens` is empty after stopword removal, fall through to step 5
   (no-match exit) — a hint composed entirely of stopwords cannot
   discriminate.

2. For each bullet in `## Findings` (**excluding** `insufficient` bullets
   in this first pass; step 4 revisits them as an escape hatch):
     - Tokenize the bullet's full content (anchor + text + date) the
       same way to get `bullet_tokens`.
     - Score = count of `hint_tokens` that appear in `bullet_tokens`
       (substring match, case-insensitive).

3. Pick the bullet with the highest score. Selection is unique iff:
     - Top score ≥ 2 meaningful tokens matched, AND
     - Top score exceeds the second-best score by ≥ 1 token.

   On a unique winner, the bullet becomes the candidate. Classify it
   (per the four buckets above). If its classification is `question`,
   the question-halt above still applies — surface and exit. Otherwise
   proceed to Step 4 with this single candidate; the candidate list
   has size 1 and Step 4 still renders synthesis in detail mode.

4. **`insufficient` escape hatch.** If step 3 produced no unique winner
   from non-insufficient bullets, re-run step 3 *including*
   `insufficient` bullets. If a unique winner now emerges and it is
   `insufficient`-stamped:

     a. Surface a one-line warning:

        > Warning: hint matched an `[INSUFFICIENT]`-stamped finding.
        > Re-dispatching anyway because you named it explicitly; un-stamping in BACKLOG.md before dispatch.

     b. **Un-stamp the bullet on disk.** Perform a single `Edit`
        read-modify-write on `BACKLOG.md` that strips the leading
        `[INSUFFICIENT: <anything>] ` prefix (including the trailing
        space) from the matched bullet's `<text>`. The anchor,
        original text, and `(YYYY-MM-DD)` trailer are unchanged.
        Example transform:

        ```
        before: - `path/spec.md` — [INSUFFICIENT: gap reason] Original prose. (2026-05-13)
        after:  - `path/spec.md` — Original prose. (2026-05-13)
        ```

        Rationale: the bullet text flows downstream into
        `/base:feature` and `/base:bug` (slug derivation, spec stub,
        bug-report description). Leaving the stamp in place would
        poison those derivations. Un-stamping reactivates the
        finding — the user has explicitly chosen to work on it
        again. If the downstream skill aborts again with
        `ABORT:UNDERSPECIFIED`, Step 6a will re-stamp it with the
        new gap reason.

        If the Edit fails (file gone, marker no longer unique,
        etc.), print a single WARNING line and **do not proceed**:

        > WARNING: could not un-stamp finding in BACKLOG.md; aborting hint dispatch to avoid poisoned downstream slug/text.

        Exit without dispatching. The user can resolve manually.

     c. Classify the un-stamped bullet (per the four buckets
        above; it is now no longer `insufficient`). If the
        classification is `question`, the question-halt applies —
        surface and exit. Otherwise proceed to Step 4 with this
        single candidate.

   This honors explicit user intent — a hint that points squarely at a
   stamped bullet overrides the default skip semantics, and the
   un-stamp action keeps downstream consumers (feature/bug slug and
   stub derivation) reading clean text.

5. **No unique match** (zero hits, or ambiguous even after the escape
   hatch). Print and exit without dispatching:

   ```
   No unique BACKLOG finding matches: "<hint>"

   Closest candidates:
     1. <bullet text, truncated to ~120 chars>
     2. <bullet text, truncated to ~120 chars>
     ...

   Refine the hint or run `/base:next` (no args) to see top findings.
   ```

   List up to 5 candidates ranked by score (include `insufficient`
   bullets here, prefixed `[insufficient]` so the user sees them).

---

## Step 4: Mode-Gated Dispatch

**Pre-branch invariant (question-halt):** The question-halt check in Step 3
already ran before this step. If execution reaches Step 4, no leading
`question` finding was present (or, in hint mode, the matched bullet is not
a `question` — an `insufficient` bullet may have been accepted via the
escape hatch). The candidate is `bug` or `feature-work`. Neither `auto`
mode nor `detail` mode bypasses the question-halt; both modes rely on
Step 3's check firing before this branch. This satisfies AC-INV-1.

Branch first on **`hint`** (set by Step 0), then on `mode`:

- `hint == None` → doc-order top-3 detail rendering OR doc-order auto
  one-shot, depending on `mode`. This is the original two-branch flow.
- `hint != None` → single-candidate rendering (detail) OR silent
  single-candidate dispatch (auto). Step 3's hint path produced exactly
  one candidate.

---

### IF mode == auto AND hint == None

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

### IF mode == auto AND hint != None

Step 3's hint path produced a unique candidate. Print exactly one notice
line before proceeding — no other output, no prompt:

```
Dispatching as <classification> (hint-matched): <truncated-bullet>
```

`<classification>` and `<truncated-bullet>` follow the same rules as the
no-hint auto branch above. Fall through immediately to Step 5 with the
hint-matched candidate. Do **not** invoke `AskUserQuestion`.

---

### IF mode == detail AND hint != None

Step 3's hint path produced a unique candidate. Invoke Step 4a to
synthesise a paragraph for it. Render:

```
## Hint-matched finding

**Match.** <anchor> → <classification>
      <paragraph>
```

Then invoke `AskUserQuestion` with two options:

- `Dispatch` — proceed to Step 5 with this candidate.
- `Abort` — exit without dispatching.

On `Dispatch`: continue to Step 5. On `Abort`: exit.

---

### IF mode == detail AND hint == None

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

1. **Extract the gap description.** Take all text following the first
   `ABORT:UNDERSPECIFIED:` occurrence in the return output, trimmed. Use
   only the first such line if multiple exist. Then truncate the gap to
   ≤80 characters; if longer, replace the trailing portion with a single
   `…` so the total length (excluding the literal `[INSUFFICIENT: ` and
   `]` framing added in step 2) is ≤80. This preserves the
   one-line-per-bullet tonality rule
   (`plugins/base/skills/backlog/references/format.md`).

2. **Stamp the original finding in `BACKLOG.md`.** Perform a single
   read-modify-write before printing anything to the user:
     a. Read `BACKLOG.md` at the repo root.
     b. Locate the dispatched finding's bullet using the marker derived
        in Step 5 — it is unique by construction.
     c. Compute the new bullet line by injecting
        `[INSUFFICIENT: <truncated-gap>] ` (with a trailing space)
        immediately after the ` — ` separator between `<anchor>` and
        `<text>`. The anchor, the original `<text>`, and the
        ` (YYYY-MM-DD)` trailer are unchanged. Example transform:

        ```
        before: - `path/to/spec.md` — Original prose. (2026-05-13)
        after:  - `path/to/spec.md` — [INSUFFICIENT: gap reason] Original prose. (2026-05-13)
        ```

     d. Apply via the `Edit` tool with the full original bullet line as
        `old_string` and the stamped bullet line as `new_string`. Edit's
        uniqueness guarantee combined with the unique marker makes this
        write safe.

   **Stamp failure fallback.** If the Edit fails (file not found, marker
   no longer unique because BACKLOG.md was edited between Step 5 and
   here, or any other Edit error), skip the stamp silently and append a
   single warning line to the abort message in step 3:
   `WARNING: could not stamp original finding — manual /base:backlog resolve recommended to avoid re-dispatch.`

3. **Print the abort message:**

   ```
   Auto-dispatch aborted.
   Reason: {extracted gap description}
   Original finding stamped [INSUFFICIENT] in BACKLOG.md (deferred).
   A question finding capturing the gap has been added; run /base:next (without auto) to address it interactively.
   ```

   If the stamp failed (per the fallback above), replace the
   "stamped" line with the WARNING line.

Then exit. Do NOT attempt the next candidate. Auto mode processes exactly
one item regardless of result (success or abort).

The next `/base:next auto` invocation will see the stamped bullet,
classify it as `insufficient` in Step 3, and skip it — breaking the
re-rejection loop.

---

## Step 7: Return

Exit after the Skill call returns. Report the dispatched finding and which workflow
received it.

In auto mode, Step 7 is reached after either a successful dispatch or an abort —
the skill exits after one dispatch attempt in either case.
