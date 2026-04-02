# React Best Practices (2025-2026)

## 1. React 19+ Features

### Stable Features (React 19, Dec 2024)
- **Server Components (RSC)**: Execute on server, stream HTML, no client JS. Adopt incrementally for non-interactive, data-heavy UI
- **Actions**: Async functions in transitions handling pending/error/optimistic states. Pass directly as `action` prop on `<form>`
- **`use()` hook**: Read promises and context during render. Can be called in conditionals/loops/early returns. Errors/loading via Suspense/ErrorBoundary
- **`useActionState`**: Returns `[state, formAction, isPending]` — wraps action, gives last result + pending status
- **`useOptimistic`**: Immediately render optimistic value during server action; auto-reverts on error
- **`useFormStatus`**: Submission info (pending, data) for disabling inputs, showing spinners
- **Server Actions (`'use server'`)**: Replace many REST/GraphQL API calls for mutations

### React 19.2 (Oct 2025)
- Stable React Compiler v1.0 (see Performance section)

### Best Practices
- Use `useTransition` for smooth route changes and form updates
- Embrace `use()` in Server Components for data fetching
- Let Actions handle form submission plumbing instead of manual onSubmit + fetch + useState

## 2. State Management

| Library | Size | Best For |
|---------|------|----------|
| **React Context** | built-in | Simple prop-drilling avoidance, infrequently-changing globals (theme, auth) |
| **Zustand** | ~3 KB | Medium-to-large apps, hook-based, minimal boilerplate, no providers |
| **Jotai** | ~4 KB | Complex atomic interdependent state, derived/computed state |
| **Redux Toolkit** | ~15 KB | Large enterprise apps, complex state logic, middleware, time-travel debug |

### Signals
- TC39 proposal (Stage 1, April 2024) with `Signal.State` and `Signal.Computed`
- ~3ms single-state updates vs Zustand ~12ms, Redux ~18ms
- React team chose React Compiler over native signals
- Available via `@preact/signals-react`

### Key Insight
Libraries can coexist — use right tool for each state domain. Server state belongs in TanStack Query/SWR, not global store.

## 3. Performance

### React Compiler (v1.0, Oct 2025)
- Build-time automatic memoization (useMemo, useCallback, React.memo)
- More precise than manual approaches (individual expressions, conditional paths)
- Meta results: 20-30% render time reduction, up to 12% faster loads, 2.5x quicker interactions
- **With compiler**: Remove most manual useMemo/useCallback
- **Without compiler**: Manual memoization still essential

### Optimization Techniques
- `React.lazy()` + `<Suspense>` for code splitting (example: 95KB → 31KB bundle, 6s → 2.8s load)
- `react-window` or TanStack Virtual for long list virtualization
- `useTransition` for non-urgent state updates
- Performance budgets: aim for <200KB total JS compressed

### Pitfall
New tools don't fix architectural problems — bad component design, deep prop drilling, or wrong-place fetching still cause issues.

## 4. Component Patterns

### Custom Hooks (most important pattern)
Extract stateful logic into reusable functions. Shareable across components without changing hierarchy.

### Compound Components
Parent + children share implicit state (like `<select>`/`<option>`). Uses useState + useContext internally. Great for design systems.

### Container/Presentational
Container is now typically a custom hook. Presentational components are pure functions of props.

### Render Props vs Hooks
Hooks are default for new code. Render props for: inversion of control, isolating JSX, injecting state without side effects. Hooks cannot render, set context, or implement error boundaries.

### Provider Pattern
Essential for theme, auth, locale. Combine useContext with custom hooks for clean APIs (`useTheme()` instead of raw `useContext(ThemeContext)`).

## 5. Testing

| Layer | Tool | Purpose |
|-------|------|---------|
| Unit | **Vitest** | Fast isolated logic tests. Vite ESM transforms, handles TS/JSX/CSS |
| Component | **React Testing Library** + Vitest | User-focused interaction tests |
| Component (browser) | **Vitest Browser Mode** / Playwright CT | Real browser, superior to JSDOM |
| E2E | **Playwright** | 3-5 critical flows in CI. Cross-browser, auto-waiting |
| API/Integration | **MSW** | Intercept at SW level for reliable integration tests |

### Key Shifts
- Vitest overtaking Jest for new projects — fastest, most ergonomic
- Playwright component testing now stable
- Test user behavior, not implementation. Query by role/label/text, not CSS class/test ID

## 6. Accessibility

### Regulatory Context
- ADA Title II enforcement April 2026
- European Accessibility Act now in effect
- Lawsuit volumes surged 37% in 2025

### Core Principles
1. **Semantic HTML first** — native `<button>`, `<nav>`, `<dialog>`, `<input>`
2. **"No ARIA is better than bad ARIA"** — only use when native elements can't achieve desired behavior
3. **Focus management** — `useRef` + `useEffect` for modals: move focus in, trap inside, return on close
4. **Client-side routing breaks focus** — set focus to `<h1>` or main content after SPA navigation
5. **Dynamic content** — `aria-live="polite"` for announcing changes

### Recommended Tools
- **React Aria** (Adobe): Headless accessible component primitives
- **Radix UI**: Unstyled accessible component library
- **eslint-plugin-jsx-a11y**: Lint-time accessibility checks
- Test with actual screen readers (VoiceOver, NVDA)

## 7. Styling

### Tailwind CSS (dominant choice)
- Zero runtime cost (critical for Server Components)
- Enforces design system via config
- Fastest development velocity

### CSS Modules (reliable standard)
- Scoped by default, no runtime, familiar CSS
- Best for extending existing codebases

### CSS-in-JS (declining)
- Runtime overhead increases INP
- Problematic with React Server Components
- Only for existing projects or highly dynamic styles

### Hybrid
Tailwind for utilities + CSS Modules (or vanilla-extract) for specific/dynamic components.

## 8. Data Fetching

### TanStack Query v5 (industry standard, 12M+ weekly downloads)
- `useQuery`/`useMutation` hooks
- Built-in caching, background refetch, optimistic updates
- Better RSC support and Suspense integration in v5+

### SWR (4KB vs TanStack's 13KB)
- Simpler API, smaller bundle
- Best for straightforward Next.js/Vercel apps

### 2026 Pattern: RSC + TanStack Query Hybrid
- Server Components for initial server-fetchable data
- TanStack Query for client-side interactive/real-time data
- Pass server data as initial data to client queries

## 9. Form Handling

### React Hook Form + Zod (dominant)
- Minimal re-renders (uncontrolled via refs)
- `@hookform/resolvers/zod` bridges the two
- Same Zod schema reusable on client and server

### Conform (purpose-built for Server Actions)
- Progressive enhancement with web standards
- Works with any HTML form markup
- `@conform-to/zod` for validation

### React 19 Native
For simple cases: `<form action={serverAction}>` + `useActionState` + `useFormStatus` may eliminate need for form library.

### Zod Techniques
`refine()` and `superRefine()` for custom/async validation. `z.infer<typeof schema>` for type derivation.

## 10. Build Tooling

| Tool | Type | Best For |
|------|------|----------|
| **Vite** | Build tool | Default for non-framework React. #1 in State of JS 2024 (95% satisfaction) |
| **Next.js** | Framework | SSR, SSG, RSC, App Router. Frontrunner for sizeable apps |
| **Remix / React Router v7** | Framework | Interactive apps, fine-grained server/client control |
| **RSBuild** | Build tool | Rust-based, Webpack-compatible, recommended by React team as CRA replacement |
| **Turbopack** | Bundler | Rust-based, integrated with Next.js 15+ |

## 11. TypeScript

### Essential Patterns
- **Strict mode**: `strict: true` in tsconfig
- **Interface for props**: Prefer `interface` for extendable, `type` for unions
- **Discriminated unions**: Type-safe reducers and conditional rendering
- **Generic components**: Reusable with preserved type safety
- **`z.infer<typeof schema>`**: Types from Zod schemas
- **`satisfies`**: Validate value matches type without widening
- **Avoid `any`**: Use `unknown` + type guards

### Pitfalls
- Over-using `as` assertions (hides real errors)
- Not using `React.ComponentProps<typeof Component>`
- `React.FC` no longer recommended (type props as function params)
