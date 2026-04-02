# UX Patterns for PWAs and React

## 1. PWA-Specific UX

### App-Like Navigation
- Bottom tab bars for primary navigation (mobile) — 78% of mobile PWA manifests use `standalone` display
- Swipe gestures for card navigation (left/right dismiss, up/down scroll) — swipes are ~5x faster than button taps
- Gesture conflicts: avoid conflicting with browser back/forward swipe
- `overscroll-behavior: contain` prevents accidental pull-to-refresh
- Always provide discoverability hints for gestures (peek animations, tooltip on first use)

### Offline UX
- **Never show generic browser offline page** — always provide custom offline experience
- Show compact connectivity indicator (top bar or status chip) + per-item sync states
- Queue actions silently with visual confirmation ("Saved offline, will sync when connected")
- Empty states: distinguish "no data" from "no connection"
- Never block UI for network mutations — persist locally, show "queued" / "syncing" state
- Use plain language: "You're offline — items will send when connection returns"
- Show sync progress when reconnecting

### Install Promotion
- Prompt only after engagement (read 2+ articles, used a feature)
- Use dismissible banner or in-menu option, never a modal
- Explain benefit: "Install for offline reading and faster access"
- After dismissal, wait ≥ 2 weeks before re-prompting
- iOS: Show step-by-step "Add to Home Screen" instructions with screenshots

### Update UX
- Show non-intrusive toast: "New version available" with refresh button
- Never force-refresh without warning (user may lose in-progress work)
- For critical updates: show persistent banner with urgency explanation

### Loading States
- Skeleton screens feel **20-30% faster** than spinners; reduce abandonment by up to 30%
- Match skeleton shape to actual content layout
- Use CSS animation (pulse/shimmer) on skeletons
- Show content progressively as it loads (avoid full-page skeleton)
- <300ms: show nothing (avoid flicker). 300ms-10s: skeleton or spinner. >10s: progress bar with steps
- In Next.js 15+: drop `loading.tsx` alongside route for automatic Suspense-based skeleton streaming

### Pull-to-Refresh
- Disable browser default: `overscroll-behavior-y: contain`
- Implement custom with visual feedback (pull indicator, spinner)
- Haptic feedback on trigger threshold (if available)
- Clear "updating..." state with automatic dismissal

### Splash Screens
- Keep < 2 seconds; use for branding only
- Match background_color in manifest to first paint background
- iOS: Provide `apple-touch-startup-image` link tags

## 2. Mobile UX Patterns

### Touch Gestures
- **Swipe**: Card dismiss, tab switching, action reveal
- **Long-press**: Context menu, selection mode
- **Pinch**: Zoom (avoid conflicting with browser pinch-to-zoom)
- Minimum touch target: 48x48px (Google), 44x44px (Apple)
- Gesture affordances: show hints on first use

### Swipe-to-Action Patterns
- Reveal background icons/actions behind swiped element
- Short swipe = reveal actions; full swipe = execute default action
- Spring-back animation if swipe doesn't reach threshold
- Visual feedback: color change, icon scale, haptic
- Confirm destructive actions (delete) with undo toast, not modal
- Different colors for different actions (red=delete, yellow/gold=star, green=archive)

### Haptic Feedback (Web)
- Vibration API: `navigator.vibrate(ms)` — Chrome, Firefox, Opera (NOT Safari/iOS)
- Requires sticky user activation (user must have interacted first)
- Patterns: single integer (ms) or array alternating vibrate/pause durations
- Max vibration: 10,000ms. Max pattern length: 10 entries
- Best uses: destructive action confirmation, pull-to-refresh threshold, swipe completion
- Trigger precisely when visual event occurs — even small delays feel unnatural

### Bottom Sheets / Drawers
- Use for contextual actions and detail views — more native-feeling than modals on mobile
- Draggable handle at top for resize/dismiss
- Snap points (half, full, closed)
- Backdrop dimming with tap-to-dismiss
- Libraries: **Vaul** (used by shadcn/ui Drawer), **react-modal-sheet**, **Base UI Drawer**

### Thumb Zone Optimization
- Primary actions in bottom third of screen
- Navigation at bottom (thumb-reachable)
- Secondary actions at top (less frequent)
- FAB (Floating Action Button) for primary action

### Safe Area Handling
- Use `viewport-fit=cover` in meta viewport, then manage with `env(safe-area-inset-*)`
- Common pattern: `padding-bottom: max(16px, env(safe-area-inset-bottom))`
- Apply to fixed/sticky elements (headers, tab bars, FABs)
- Dynamic Island (iPhone 14 Pro+): account for `env(safe-area-inset-top)`
- Use modern viewport units (`svh`, `lvh`, `dvh`) for reliable full-height layouts
- Browser support: 96.78%

### Native-Like Transitions
- **View Transitions API**: Baseline Newly Available (Oct 2025) — Chrome 111+, Edge 111+, Firefox 133+, Safari 18+
- React `<ViewTransition>` component (canary, close to stable) integrates with Suspense/useDeferredValue
- Next.js: enable `viewTransition: true` in next.config.js for automatic navigation transitions
- Shared element transitions via `view-transition-name` for hero animations
- Spring-based animations feel more natural than linear
- 60fps target — use CSS transforms, avoid layout triggers
- Interop 2025 focus: `document.startViewTransition()`, `view-transition-class`, auto-naming

## 3. React-Specific UX

### Optimistic UI (React 19)
- `useOptimistic` for immediate feedback on actions
- Auto-reverts on server error
- Show subtle indicator that action is pending ("Saving...")
- For lists: immediately move/remove item, revert on failure
- Always provide error recovery path

### Suspense Boundaries
- Place boundaries at meaningful UI units (page, section, widget)
- Don't wrap every component — too many skeletons is worse than one
- Nested Suspense for progressive loading (shell → content → details)
- `startTransition` to avoid showing fallback for fast loads

### Error Boundary UX
- Show contextual error message, not generic "Something went wrong"
- Provide retry button that re-renders the failed subtree
- Log errors for debugging (error boundary + error reporting service)
- Graceful degradation: show stale content if available

### Page Transitions (View Transitions API)
- `document.startViewTransition()` for cross-page animations
- Combine with React Router or Next.js navigation
- Name elements with `view-transition-name` for shared transitions
- Fallback: instant navigation for unsupported browsers

### Progressive Disclosure
- Show essential info first, details on demand
- Expandable sections, "Show more" patterns
- Lazy-load heavy components below the fold
- Prioritize above-fold content rendering

## 4. Usability Fundamentals

### Perceived Performance
- Skeleton screens feel 20-30% faster than spinners; reduce abandonment by up to 30%
- The actual wait is less significant than perception — engagement during loading reduces perceived duration
- Progress indicators for actions > 1 second
- Instant feedback for all interactions (touch highlight, state change)
- Prefetch on hover/focus for anticipated navigation
- Combine streaming SSR + skeleton screens: flush HTML progressively

### Nielsen Heuristics for PWAs
- PWAUH: 15 PWA-specific usability heuristics addressing hybrid native/web nature
- Key applications: connectivity indicators (system status), familiar gestures (real-world match), undo for destructive actions (user control), larger tap targets (error prevention)

### Micro-Interactions
- Button press: scale down slightly (0.95-0.97)
- Success: checkmark animation, green flash
- Error: shake animation, red highlight
- Loading: pulsing dots or shimmer
- Toggle: smooth slide with color transition
- Keep animations under 300ms for responsiveness, 300-500ms for emphasis

### Dark Mode
- Respect `prefers-color-scheme` media query
- Provide manual toggle that overrides system preference
- Store preference in localStorage for instant application
- Use CSS custom properties for theme values
- Match `theme-color` meta tag to current theme

### Responsive Typography
- Use `clamp()` for fluid font sizes: `clamp(1rem, 0.5rem + 1.5vw, 1.5rem)` — browser support 91.4%
- Apply fluid spacing too: `padding-inline: clamp(1rem, 4vw, 4.5rem)`
- Never use `vw` alone for font sizes (breaks zoom) — always include rem/em component
- Minimum body text: 16px (prevents iOS zoom on input focus)
- Line height: 1.5 for body text, 1.2 for headings
- Max line width: 65-75 characters for readability
- Max font size no more than 2.5x minimum for WCAG SC 1.4.4

## 5. Design Systems and Component Libraries

### Radix UI + Tailwind (shadcn/ui pattern)
- Radix provides accessible, unstyled primitives
- Tailwind for styling — zero runtime, design-constrained
- Copy-paste components (shadcn/ui) — full ownership, no dependency
- Best combination for custom design systems in 2026

### Headless UI Approach
- Separation: behavior (Radix/React Aria) + styling (Tailwind/CSS)
- Full control over appearance while getting accessibility for free
- Reusable across projects with different visual designs

### Motion Libraries
- **Motion** (formerly Framer Motion): ~32KB gzipped. Best for complex gesture-driven/orchestrated animations. Import from `motion/react` (renamed 2025)
- **Motion One** (motion.dev): ~3.8KB gzipped. Built on WAAPI. Better for performance-critical PWAs
- **View Transitions API**: Zero-JS page transitions. Browser-native, hardware-accelerated. Baseline Oct 2025
- **CSS Animations**: Prefer for simple transitions (hover, focus, toggle states)
- Decision: View Transitions for navigation, Motion One for lightweight, Motion for complex/gesture-driven
- Respect `prefers-reduced-motion` — always provide reduced/no-motion alternative
