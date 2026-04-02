# pwa-react-skills

Expert knowledge on Progressive Web Apps and modern React applications.

- **PWA** — service workers, caching strategies, offline support, Workbox,
  Web App Manifest, push notifications, Core Web Vitals, storage APIs,
  PWA lifecycle, security, and mobile patterns (iOS/Android)
- **React** — React 19+ (Server Components, Actions, Compiler), state
  management (Zustand, Jotai, TanStack Query), component patterns, testing
  (Vitest, Playwright), accessibility, styling (Tailwind, CSS Modules),
  forms (React Hook Form + Zod), TypeScript, and build tooling (Vite, Next.js)
- **UX** — offline UX, install promotion, loading states, mobile gestures,
  View Transitions API, optimistic UI, design systems (Radix/shadcn)

## Installation

```bash
/plugin marketplace add 941design/claude-plugins
/plugin install pwa-react-skills@941design
```

## Skills

### `/pwa-react-skills:pwa-react [question]`

Advisory skill. Answers questions about:

- Service worker caching strategies and offline support
- Web App Manifest configuration and installability
- Workbox setup and integration (generateSW, injectManifest, Serwist)
- Push notifications (including iOS limitations)
- Core Web Vitals optimization (LCP, INP, CLS)
- React 19+ features (Server Components, Actions, use(), Compiler)
- State management selection (Zustand, Jotai, TanStack Query, Context)
- Testing stack (Vitest, React Testing Library, Playwright, MSW)
- Accessibility (React Aria, Radix, focus management, ARIA)
- UX patterns (skeleton loading, View Transitions, optimistic UI)
- Build tooling (Vite, Next.js, static export, PWA integration)

**Auto-invokes** when Claude detects PWA or React questions. Runs in an
isolated agent context with persistent memory.

**Self-updating:** Checks documentation freshness on each invocation. If
knowledge is older than 7 days, automatically fetches the latest from React
docs, MDN, Workbox docs, and web.dev before answering.

### `/pwa-react-skills:pwa-react-update [topic]`

Manual maintenance skill. Fetches the latest React releases, PWA API changes,
browser compatibility updates, and tooling releases, then updates agent memory.

```bash
# Full update
/pwa-react-skills:pwa-react-update

# Targeted update
/pwa-react-skills:pwa-react-update react-compiler
/pwa-react-skills:pwa-react-update workbox
```

## Agent

### pwa-react-expert

Custom agent with user-scoped persistent memory
(`~/.claude/agent-memory/pwa-react-expert/`). Accumulates knowledge across
sessions — PWA patterns, React updates, browser compatibility changes, tooling
releases, and common pitfalls.

Both pwa-react skills run in this agent's context, sharing the same memory.

### First Run

Agent memory is user-scoped and lives outside the plugin directory. Plugin
files are never modified at runtime — all dynamic state lives in agent memory.

On first invocation, the agent detects that its memory is empty and
automatically runs a full knowledge refresh, fetching from React docs, MDN,
Workbox docs, and web.dev. This adds latency to the first invocation but
requires no manual setup. Subsequent invocations reuse cached memory and only
refresh when stale (>7 days). When memory and supporting docs conflict, the
agent trusts its memory (latest fetch) over the shipped docs.

To force a rebuild at any time:

```bash
/pwa-react-skills:pwa-react-update
```

## Supporting Documents

Four read-only reference files:

| File | Content |
|---|---|
| `pwa-best-practices.md` | Service workers, caching, manifest, push, storage, lifecycle, security, mobile |
| `react-best-practices.md` | React 19+, state management, performance, patterns, testing, styling, forms, TypeScript |
| `design-guidance.md` | Decision trees for PWA vs native, caching strategy, state management, testing, styling |
| `ux-patterns.md` | PWA UX, mobile UX, optimistic UI, loading states, animations, design systems |

## Primary Sources

| Source | Link |
|---|---|
| React docs | [react.dev](https://react.dev) |
| MDN Web Docs | [developer.mozilla.org](https://developer.mozilla.org) |
| Workbox docs | [developer.chrome.com/docs/workbox](https://developer.chrome.com/docs/workbox) |
| web.dev | [web.dev](https://web.dev) |
| Next.js docs | [nextjs.org/docs](https://nextjs.org/docs) |
| Can I Use | [caniuse.com](https://caniuse.com) |

## Development

Load the plugin directly:

```bash
claude --plugin-dir ./plugins/pwa-react-skills
```
