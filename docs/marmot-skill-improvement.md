# Task: rewrite the `nostr-skills:marmot` skill trigger language

You own the `nostr-skills:marmot` skill (the Marmot Protocol
implementation advisor — MDK Rust SDK, marmot-ts, `wn` CLI/daemon).
Update its frontmatter `description` so the skill fires reliably in
cases where it is currently being skipped.

## What's wrong with the current description

The current text reads (paraphrased):

> Marmot Protocol implementation advisor. Helps build applications
> using MDK (Rust SDK), marmot-ts (TypeScript), or the wn
> CLI/daemon. Invoke for questions about using these libraries,
> Nostr+MLS group messaging, WhiteNoise architecture, storage
> backends, Nostr network integration, or understanding MIP
> specifications as they relate to library behavior.

This is a capability description, not a trigger spec. The phrase
"Invoke for questions about using these libraries" gets pattern-
matched as "the user is explicitly asking an MDK question," so the
skill is skipped in adjacent cases where it would clearly help.

## Concrete failure case to fix

On 2026-04-28, an agent working in `notestr-cli` wrote a feature
proposal at `specs/proposal-admin-self-demote-before-leave.md` that
references an MDK method `mdk.self_demote(...)` inferred from a
test-failure error string ("Use self_demote() first"). The exact
method name and signature in `mdk-core` were not verified. The
agent explicitly noted the uncertainty in the proposal itself ("I
had to guess the MDK API shape from the error string"), then
committed it anyway. The marmot skill — whose entire purpose is to
resolve exactly this kind of uncertainty — never triggered.

The agent's later retrospective identified two causes:

1. **Description framed around user questions, not agent
   uncertainty.** The proposal was being written, not asked about,
   so the "questions about using these libraries" trigger didn't
   match.
2. **No explicit "fire when guessing" trigger.** Self-detected
   uncertainty about an in-domain API should be a hard trigger;
   the current wording does not say so.

## What to write instead

Adopt the imperative TRIGGER / SKIP shape used by sibling skills
like `codex:gpt-5-4-prompting` and `claude-api`. Concrete trigger
conditions get matched mechanically; vague capability descriptions
get skipped. Aim for something like:

```
Marmot Protocol implementation advisor — MDK (Rust), marmot-ts
(TypeScript), and the wn CLI/daemon. Authoritative source for MDK
API shape, MIP specifications, MLS-on-Nostr behavior, and
WhiteNoise architecture.

TRIGGER when: about to reference MDK / marmot-ts / wn APIs in
code, comments, specs, or PR descriptions; about to claim a method
exists or has a given signature; uncertain about an MIP behavior
or MLS-on-Nostr semantics; user mentions Marmot, MDK, MLS-on-
Nostr, WhiteNoise, or wn; about to write or modify code in a file
that imports `mdk-core`, `marmot-ts`, or wn bindings. Invoke even
if the user did not explicitly ask an MDK-specific question — the
skill is the canonical source for these APIs and the agent's
uncertainty alone is a sufficient trigger.

SKIP when: working on plain Nostr (no MLS / no group encryption)
— use nostr-skills instead; working on rmcp / JSON-RPC transport
plumbing that does not touch group state; pure SQLite / storage
work with no protocol-level concern.
```

You may iterate on the exact wording, but the rewrite MUST:

1. Use imperative `TRIGGER when:` and `SKIP when:` clauses with
   semicolon-separated concrete conditions, not capability
   prose.
2. Explicitly include "agent self-detected uncertainty about MDK
   / marmot-ts / wn APIs" as a trigger.
3. Explicitly include "writing specs, proposals, or
   documentation that references MDK APIs" as a trigger (not
   just code).
4. Include a SKIP clause so the skill does not fire on
   plain-Nostr or pure-transport work where the marmot context
   is not needed.
5. Stay under ~150 words so the description still reads cleanly
   in the skill index.

## Validation

Once the description is updated, sanity-check it by mentally
replaying these prompts and confirming the skill would now fire:

- "I'll add a `mdk_bridge::self_demote` wrapper around
  `mdk.self_demote(group_id)`" — should fire (claiming an API).
- "Write a spec for an admin-leave flow that calls self_demote
  first" — should fire (spec referencing MDK).
- "What's the right way to publish a kind-445 message?" — should
  fire (MIP behavior question).
- "Add a new SQLite migration for the `daemon_running` config
  row" — should NOT fire (pure storage, no protocol concern).
- "Wire a new rmcp tool that lists open MLS groups" — should
  fire (touches MDK group state) even though the user phrased
  it as transport work.

If any of those fire/skip the wrong way, tighten the trigger or
skip clauses until they are correct.

## Out of scope

- Changing the skill's tools, knowledge base, or runtime
  behavior. This task is purely the frontmatter `description`.
- Renaming the skill or moving it to a different namespace.
- Editing the `nostr-skills:marmot-researcher` agent description
  unless the same trigger gap exists there too — if it does,
  apply the same TRIGGER/SKIP rewrite to that agent's
  description as a separate change with its own validation
  prompts.

## Deliverable

A single edit to the `nostr-skills:marmot` skill's frontmatter
`description` (and optionally the `marmot-researcher` agent
description if it shares the same gap). No code changes
elsewhere. Report the before/after diff so the requester can
review the new trigger language without re-reading the entire
skill file.
