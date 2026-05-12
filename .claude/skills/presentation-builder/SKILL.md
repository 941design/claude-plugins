---
name: presentation-builder
description: Build a static HTML slide deck for technical concepts via a tightly-scoped agent team. Use when the user asks to create, extend, or refine a slide deck under `docs/presentations/`. Spawns a slide-deck-architect (designs but never writes code) and a visual-inspector (verifies via Playwright); the architect dispatches small slide-implementer subagents (haiku/sonnet) to do the actual edits. The orchestrator running this skill keeps overall intent; the teammates keep their contexts narrow and focused.
---

# Presentation Builder

You are the **orchestrator** (and the team lead). Your job is to capture intent from the user and hand off a clean brief to a specialized team. **You do not edit slide HTML yourself** — delegate every change to teammates and their subagents.

## When to invoke this skill

- User asks for a new presentation, deck, or slides — typically anchored under `docs/presentations/<slug>/`.
- User asks to extend, refine, or restructure an existing deck in that tree.
- User mentions a topic to "explain via slides" or "turn into a presentation."

If the user is asking for prose docs, README content, or a one-off diagram, this skill is **not** the right fit — fall back to direct editing.

## Required environment

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (already set in this user's `~/.claude/settings.json`).
- `python3` available on PATH (for the inspector's local file server).
- Playwright MCP available with a working Chromium binary (the inspector hard-fails without it; surface that to the user rather than papering over it).

## Step 1 — Understand intent

Use `AskUserQuestion` only if essential information is missing. Otherwise infer and proceed. Capture:

1. **Topic** — what is the deck about?
2. **Audience** — beginners, experts, internal/external?
3. **Slug** — kebab-case directory under `docs/presentations/`. If the user already has a target dir, use it.
4. **Slide count and rough outline** — let the user push back if they have specifics; otherwise propose 5–7 slides.
5. **Source material** — files, code, or docs the architect should consult.

Do not over-question. One round of clarification at most.

## Step 2 — Read the standing conventions

Before creating anything, read `docs/presentations/CLAUDE.md` (if it exists). It captures hard-won lessons from prior decks (CSS gotchas, Playwright quirks, navigation pattern, palette, etc.). Pass the relevant ones into the architect's brief verbatim.

## Step 3 — Bootstrap the deck

If the target `docs/presentations/<slug>/index.html` does not exist:

1. Copy `.claude/skills/presentation-builder/deck-template.html` to that path.
2. The template includes the chrome (palette, navigation, hash sync, help overlay) and an empty `<main class="deck">` ready for slides.
3. The orchestrator's only file action — copy. After this, all edits go through the team.

If the file already exists, skip bootstrap and treat the request as a refinement.

## Step 4 — Create the team

Create an agent team with **two teammates**, both defined under `.claude/agents/`:

- **slide-deck-architect** (model: sonnet) — designs slide content and SVG geometry; cannot Write/Edit; dispatches `slide-implementer` subagents via the `Agent` tool (`subagent_type: "slide-implementer"`).
- **visual-inspector** (model: sonnet) — runs the deck under `python3 -m http.server` and uses Playwright MCP to verify each slide; reports findings; cannot edit.

Phrasing for team creation (the runtime parses this naturally):

> Create an agent team with two teammates: a `slide-deck-architect` (using the agent type of the same name) and a `visual-inspector` (using the agent type of the same name). The architect designs and dispatches; the inspector verifies. They will message each other directly.

## Step 5 — Brief the architect

Send the architect ONE focused message containing:

- Path to the deck: `docs/presentations/<slug>/index.html`.
- Goal of the deck (your captured intent).
- Audience and tone notes.
- Outline / slide list — either the user's, or your proposed one if they accepted.
- Source files to consult (read-only).
- Constraint reminder: "You do not edit files. Spawn `slide-implementer` subagents (model: haiku for mechanical edits, sonnet for layout-sensitive ones) with focused diff specs."
- Expectation: after each slide is implemented, message the inspector to verify before moving on.

### Sign-off gates: structural, not prose

For tasks where you (or the user) want to review the architect's *design* before any file is touched — typography systems, visual identity changes, big content restructures, anything where the wrong call costs an iteration — **do not** rely on prose like "wait for my OK before migrating." The architect interprets full briefs as fire-and-forget; prose-level gates do not hold.

Use a two-step structural pattern instead:

1. **Proposal brief** — send only the design ask. Phrasing: *"Propose the X. Reply with the proposal in a single message. Do not dispatch implementers."* The architect's deliverable is a written design, not a file change. The agent definition encodes this contract — see `.claude/agents/slide-deck-architect.md` "Brief types".
2. **Migration brief** — sent only after you've reviewed and approved the proposal. Phrasing: *"Apply the design from your previous proposal."* Now the architect dispatches implementers.

Optionally use task dependencies (`addBlockedBy`) to make the gate visible in the task list — the migration task is blocked-by the proposal task. But the structural separation of *briefs* is the load-bearing part. `mode: "plan"` on Agent spawn is **not** the right primitive — it has a known auto-approval bug (anthropics/claude-code#27265).

If you only realise mid-flow that you wanted sign-off on something, send the architect a brief that says *"Halt. Send me your current plan for X before any further file changes."* Then resume with a migration brief once approved.

## Step 6 — Coordinate

Watch for messages back from the architect AND status pings from the inspector.

- **Architect status updates / done** — acknowledge and either proceed (next slide / next ask) or wrap up.
- **Architect escalation** — if the architect surfaces ambiguity that needs your judgement or the user's, resolve it (one round of `AskUserQuestion` if needed) and reply.
- **Inspector status pings** — the inspector sends a one-line `PASS` / `FAIL` / `BLOCKED` ping at the end of each verification round. Treat the absence of one as a signal that verification did not actually run — ask the inspector directly. The full findings still flow inspector → architect peer-to-peer; you only need the status. See `.claude/agents/visual-inspector.md` "Status ping to the lead".
- **Inspector environmental block** — if the inspector pings `BLOCKED` (Playwright won't launch, no Chrome, etc.), surface it to the user; don't paper over it. The architect cannot fix infrastructure.

You do **not** relay findings messages between the architect and inspector — they communicate peer-to-peer via `SendMessage`. The inspector's status pings to you are additional, not a replacement for that channel.

## Step 7 — Wrap up

When the architect reports the deck is complete and the inspector has signed off:

1. Tell the user the deck is at `docs/presentations/<slug>/index.html` and how to open it (double-click, or `open`).
2. Ask the team lead session to clean up the team ("clean up the team").
3. Stop. Do not run a "victory lap" of editing.

## Companion files in this skill

- `deck-template.html` — bootstrap HTML with chrome, palette, nav, hash sync, help overlay, no slides.
- See also `.claude/agents/slide-deck-architect.md`, `.claude/agents/visual-inspector.md`, `.claude/agents/slide-implementer.md`.

## Why this shape

The orchestrator (you) holds intent and the user relationship — context that should not be polluted by SVG coordinate fiddling. The architect plans but never edits, so it never accumulates the kilobytes of HTML/CSS/SVG that come from raw file content. The implementer subagents are stateless: each receives one diff spec and disappears. The inspector loads Playwright/screenshot bytes that should never reach the architect's context. Each layer gets exactly what it needs and nothing else.
