# Presentations — standing conventions

This file is loaded automatically when working anywhere under `docs/presentations/`. It distils hard-won lessons from prior decks. The `presentation-builder` skill consumes it; humans editing by hand should respect it too.

## Output shape

- One deck = one folder: `docs/presentations/<slug>/index.html`.
- **Single static HTML file** with embedded CSS + JS + inline SVG. No build step, no external CDNs, no fonts loaded over the network.
- Opens by double-clicking. Works fully offline.
- Bootstrap from `.claude/skills/presentation-builder/deck-template.html` — it provides the chrome, palette, navigation, and SVG primitives.
- Target file size 30–60 KB for a 5–7 slide deck.

## Visual identity

- Dark slate gradient background (`--bg-1` → `--bg-2`) with a soft amber radial top-right and cyan radial bottom-left.
- System font stack only (`-apple-system, BlinkMacSystemFont, "Segoe UI", Inter, system-ui, sans-serif`). No Google Fonts, no `@font-face`.
- Role colours map onto an agentic mental model:
  - amber `--lead` for orchestrators / lead nodes / accent words in titles.
  - cyan `--teammate` for primary content / teammate nodes.
  - indigo `--subagent` for nested / spawned-by-others.
  - pink `--gate` (dashed boxes) for external read-only gates.
  - emerald `--success` for happy-path arrows / "done" states.
  - rose `--failure` (dashed) for failure / escalation arrows.
- Use these as semantic, not decorative — once a deck establishes that "amber = lead", don't suddenly use amber for something else.

## Navigation

- `←` / `→` / `Space` / `PageUp` / `PageDown` move between slides.
- `↑` / `↓` are **per-slide actions**, registered via the `slideActions` object keyed by `data-slide`. If a slide hasn't registered handlers, ↑/↓ do nothing.
- `Home` / `End` jump to first / last.
- `?` toggles a help overlay.
- URL hash is the slide number (`#3`). Deep linking + refresh restore position.
- The help overlay describes only what *exists* — if no slide has step actions, omit that line.

## SVG geometry rules

- Author in `viewBox` units, not pixels. The deck stretches the SVG to container width.
- Pick a `viewBox` whose aspect roughly matches the slide stage (wide and short for sequence diagrams, near-square for org charts). Mismatched aspect causes letterboxing.
- Boxes use `rx="12"` (CSS `svg .box { rx: 12 }`). Stick to that radius for visual consistency.
- For text inside a box: `text-anchor="middle"` at `x = box.cx`, `y = box.cy + 5` for the optical baseline.
- For long titles in narrow boxes (e.g. "establish baseline" in a 185u box), split onto two `<text>` elements with manual y offsets.
- Connector arrows: use a `<defs>` `<marker>` per arrow style (`s-arrow`, `s-arrow-fail`, `s-arrow-success`, `s-arrow-loop`) and reference via `marker-end="url(#…)"`.
- **Label / arrow collisions are the #1 layout bug.** Position any label `>=` 30u away from the curve it belongs to, OR put it outside the curve's x-range. When in doubt, lower the arc apex and raise the label.
- For comparison decks (two parallel rows of nodes), reserve a clear horizontal band between the rows for the loop / FAIL arc — at least 80u tall.

## Common pitfalls (from prior runs)

These have all bitten us. Don't repeat them.

- **Default `<button>` background is light grey.** If you use buttons as touch zones or any layout element, set `background: transparent; border: 0; padding: 0; appearance: none;` explicitly. We chased a "white margins on the page" bug for a full iteration before catching this.
- **Playwright MCP cannot load `file://`.** The visual-inspector must start a local HTTP server (`python3 -m http.server 8765`) at the **repo root** and navigate to `http://localhost:8765/docs/presentations/<slug>/index.html`.
- **Playwright MCP requires Chrome, not Chromium.** On Linux ARM64 the Playwright MCP fails with `ERROR: not supported on Linux Arm64` because Chrome can't be installed there even though the bundled `chromium-headless-shell` is present. If the very first `browser_resize` errors, surface this to the user — don't loop trying to install browsers.
- **Cache-bust aggressively when iterating.** Add `?v=N` to the URL and increment on every reload. Without it, Chrome reuses old layouts and screenshots disagree with the file on disk.
- **The favicon 404 is harmless.** A `console_messages level: error` always shows it because the deck has no favicon. Treat it as noise.
- **`<button>` artefacts aside, every "the slide is mysteriously narrow" or "an element is missing" bug we have hit was caused by an element with an unexpected default background covering the slide.** Run `document.elementFromPoint(50, 100)` first when you see white margins.

## Slide-1 pattern: collapsible step list

If a slide has a long ordered list of steps and each step has a paragraph of detail, use the *expandable phase ribbon* pattern from `feature-workflow/index.html`:

- Numbered circle + title shown by default.
- Description (`<p>` inside the card) hidden via `display: none`.
- A class `.expanded` on the row (`.phase-row`) flips description to `display: block`, highlights the circle, and tints the card.
- `↑` / `↓` cycle through expanded steps; only one is open at a time. State `0` means none expanded.
- This lets headings be large (24–28px) and descriptions readable (18–20px) without overflowing the slide.

Don't reach for this pattern if the descriptions are one-line — just show them all.

## Density

- Larger fonts beat denser pages. If a slide can't fit at 16:9 1440×900 without crowding, **split it** rather than shrink the type.
- Reserve `--muted` for tertiary information. Body should default to `--text`.
- Captions / subtitles are surprisingly heavy — past iterations removed all `<p class="subtitle">` and `<p class="caption">` to let titles + diagrams breathe.

## Accessibility

- Every slide has `aria-label` on its `<section>`. Make it the slide's heading rephrased.
- `prefers-reduced-motion: reduce` should disable slide transitions and progress bar animation. The template handles this — don't override.
- The deck still renders without JavaScript via the `body.no-js` fallback (every slide stacked vertically). When adding a slide, ensure its content makes sense in that mode.

## Working with the agent team

- The `presentation-builder` skill creates a 2-teammate team: `slide-deck-architect` (designs, never writes) and `visual-inspector` (verifies, never writes).
- The architect dispatches `slide-implementer` subagents (default model: haiku) for each focused edit.
- Send the architect a one-shot brief; let it run. Don't keep poking at it. Coordination noise is the enemy of focus.
- The inspector reports findings in compact text (selectors, coordinates) — it should not relay screenshot bytes back. If it does, ask it to summarise.

## Changing this file

This file persists between sessions and is read by every presentation-related agent. Add lessons here when:

- A new pitfall has cost more than one round of debugging.
- A convention emerges from multiple decks (not a one-off preference for one deck).
- An external constraint changes (Playwright MCP, browser defaults, framework updates).

Keep it punchy. If a convention can be stated in one line, state it in one line.
