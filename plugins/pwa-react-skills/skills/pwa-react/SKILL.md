---
name: pwa-react
description: >-
  Expert knowledge on Progressive Web Apps and React best practices. Covers
  service workers, caching strategies, offline support, Workbox, Web App
  Manifest, push notifications, Core Web Vitals, React 19+ (Server Components,
  Actions, Compiler), state management (Zustand, Jotai, TanStack Query),
  component patterns, testing (Vitest, Playwright), accessibility, Tailwind CSS,
  TypeScript, UX patterns, and modern build tooling (Vite, Next.js). Use when
  designing, building, optimizing, or debugging PWAs and React applications.
argument-hint: "[question about PWA, React, frontend performance, or web UX]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: pwa-react-expert
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Follow the
refresh procedure described in your agent system prompt (fetch React docs,
MDN, Workbox docs, write findings to agent memory only — never modify plugin
files).

If memory is fresh, proceed directly to answering.

## User Question

$ARGUMENTS

## Modes

### Default (with arguments)

Answer the question using your knowledge base:

1. Load your memory (MEMORY.md and referenced knowledge files)
2. Answer using stored knowledge + reasoning
3. Update memory if you learned something new (from web search or analysis)

### No arguments

Show the knowledge base summary:

1. Read your MEMORY.md
2. For each category (PWA, React, UX, tooling), show a brief summary of what's available
3. Suggest example questions the user could ask

## Example Questions

### PWA
- "How do I add offline support to a Next.js static export?"
- "Which caching strategy for API responses — Network-First or Stale-While-Revalidate?"
- "How do I set up Workbox with a postbuild step?"
- "What are the installability criteria for PWAs in 2026?"
- "How do push notifications work on iOS?"
- "How should I handle service worker updates?"

### React
- "Should I use Zustand or React Context for global state?"
- "How does the React Compiler change memoization best practices?"
- "What's the recommended testing stack for React in 2026?"
- "How do Server Components work with TanStack Query?"
- "When should I use useOptimistic vs manual optimistic updates?"
- "Tailwind vs CSS Modules — which should I pick?"

### UX & Performance
- "How do I improve INP (Interaction to Next Paint)?"
- "What's the best pattern for offline-first UX?"
- "How should I handle loading states with Suspense?"
- "What are good install promotion UX patterns?"
- "How do I implement skeleton loading in React?"
- "What's the View Transitions API and how do I use it with React?"

### Integration
- "How do I add PWA support to a Next.js static export?"
- "How do I configure CSP for a PWA with service workers?"
- "What's the best way to handle forms with React 19 Actions + Zod?"

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [pwa-best-practices.md](pwa-best-practices.md) | Service workers, caching, manifest, push, storage, lifecycle, security, mobile |
| [react-best-practices.md](react-best-practices.md) | React 19+, state management, performance, patterns, testing, styling, forms, TypeScript |
| [ux-patterns.md](ux-patterns.md) | PWA UX, mobile UX, optimistic UI, loading states, animations, design systems |
| [design-guidance.md](design-guidance.md) | Decision trees for PWA vs native, caching strategy selection, state management choice, testing strategy |

Read the relevant documents to answer the user's question. Consult your agent
memory for additional context and prior findings.

## Response Format

- Provide concrete code examples and configuration snippets.
- Always include browser compatibility notes when discussing Web APIs.
- Recommend the appropriate pattern for the user's stack and constraints.
- Note iOS/Safari limitations when relevant.
- Ground advice in Core Web Vitals impact where applicable.
- If you need to fetch live documentation to verify details, do so.
