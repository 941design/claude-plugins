# Design Guidance

## PWA vs Native App Decision Tree

### Choose PWA when:
- Cross-platform reach is priority (one codebase, all platforms)
- Content-focused app (news, articles, feeds, documentation)
- Budget constraints (no app store fees, no separate native codebases)
- Rapid iteration needed (deploy instantly, no store review)
- SEO matters (PWA content is indexable)
- Offline capability needed but not hardware-dependent features

### Choose Native when:
- Deep hardware access needed (Bluetooth, NFC, advanced camera, health sensors)
- Heavy computation (3D rendering, video editing, gaming)
- Background processing is critical (not limited by browser restrictions)
- App store presence is a hard business requirement

### Choose PWA + TWA when:
- Want PWA benefits AND Google Play Store presence
- Package with PWABuilder/Bubblewrap for Android distribution

## Caching Strategy Selection

### By Resource Type

| Resource | Strategy | Why |
|----------|----------|-----|
| App shell (HTML, JS, CSS) | **Precache** | Versioned, immutable after build |
| Static images, fonts | **Cache-First** | Rarely change, fast offline |
| API responses (feeds) | **Stale-While-Revalidate** | Balance freshness + speed |
| User-specific data | **Network-First** | Freshness matters more |
| Analytics, auth tokens | **Network-Only** | Must not be cached |
| Offline fallback page | **Cache-Only** (precached) | Always available |

### By Network Condition

| Condition | Strategy |
|-----------|----------|
| Fast, reliable network | Network-First for most; cache for performance |
| Slow or intermittent | Stale-While-Revalidate as default |
| Fully offline | Cache-Only with offline fallback page |

## State Management Decision Tree

```
Is the state server data? (API responses, DB data)
├── YES → TanStack Query or SWR
│         └── With RSC: pass server data as initialData
└── NO → Is it shared across many components?
    ├── NO → useState / useReducer (local state)
    └── YES → Does it change frequently?
        ├── NO → React Context (theme, auth, locale)
        └── YES → How complex?
            ├── Simple (few stores) → Zustand (~3KB)
            ├── Atomic/derived → Jotai (~4KB)
            └── Complex with middleware → Redux Toolkit (~15KB)
```

## Testing Strategy

### The Testing Trophy (Kent C. Dodds model, updated 2026)

```
         ╱╲
        ╱E2E╲          ← Playwright: 3-5 critical user flows
       ╱──────╲
      ╱ Integr. ╲      ← RTL + Vitest: component interactions
     ╱────────────╲
    ╱  Unit Tests   ╲   ← Vitest: pure logic, hooks, utils
   ╱──────────────────╲
  ╱   Static Analysis   ╲ ← TypeScript + ESLint + Biome
 ╱────────────────────────╲
```

### What to Test Where

| What | Where | Tool |
|------|-------|------|
| Business logic, utils | Unit | Vitest |
| Custom hooks | Unit | Vitest + renderHook |
| Component rendering | Integration | RTL + Vitest |
| User interactions | Integration | RTL + userEvent |
| Complex visual UI | Browser | Vitest Browser Mode |
| Full user flows | E2E | Playwright |
| API integration | Mock | MSW |
| Accessibility | Lint + Integration | jsx-a11y + axe-core |

## Styling Decision

### Choose Tailwind when:
- Starting a new project (fastest velocity)
- Team values consistency and design constraints
- Using Server Components (zero runtime cost)
- Working with component libraries like Radix/shadcn

### Choose CSS Modules when:
- Extending existing codebase with separate CSS
- Team prefers pure CSS control
- Complex animations that are easier in plain CSS

### Choose vanilla-extract when:
- Want type-safe CSS with zero runtime
- Need theme tokens and design system contracts
- TypeScript-first team

## Next.js Static Export Guidance

### When to Use Static Export
- Content-focused site deployed to simple hosting (FTP, CDN)
- No server-side API routes needed
- No ISR (Incremental Static Regeneration) needed
- SEO from pre-rendered HTML is sufficient

### PWA Integration Approach
1. **Post-build step**: Use workbox-cli or workbox-build script to scan output directory
2. **Alternative**: Serwist for tighter Next.js integration
3. **Manifest**: Place in `public/manifest.webmanifest`
4. **SW registration**: In root layout or `_app` client component
5. **basePath handling**: Set paths in manifest relative to basePath

### Limitations
- No middleware (runs at request time)
- No Server Actions (need server)
- No API routes
- No ISR/revalidation
- Image optimization requires external service or `unoptimized: true`

## Performance Budgets

### Recommended Targets

| Metric | Target | Why |
|--------|--------|-----|
| Total JS (compressed) | < 200KB | Fast parse + execution |
| LCP | < 2.5s | Google "good" threshold |
| INP | < 200ms | Google "good" threshold |
| CLS | < 0.1 | Google "good" threshold |
| Lighthouse Performance | > 90 | Industry standard |
| Lighthouse PWA | 100% | All criteria met |
| Time to Interactive | < 3.8s | 3G mobile target |

### Optimization Priority
1. Reduce JS bundle (code split, tree shake)
2. Precache app shell (instant repeat visits)
3. Optimize images (WebP/AVIF, lazy load)
4. Inline critical CSS
5. Virtualize long lists
6. Use React Compiler or manual memoization
