# PWA Best Practices

## 1. Service Worker Strategies

### Caching Strategies

| Strategy | Use For | How It Works |
|---|---|---|
| **Cache-First** | App shell, fonts, static assets, images | Check cache first, fall back to network. Best for versioned/immutable files |
| **Network-First** | API calls, dynamic data feeds | Try network, fall back to cached copy. Keeps data fresh; tolerates offline |
| **Stale-While-Revalidate** | Semi-dynamic assets (e.g., feed JSON) | Serve from cache immediately, fetch update in background for next load |
| **Network-Only** | Analytics pings, one-time POSTs | Never cache |
| **Cache-Only** | Precached app shell after install | Only serve from cache. Used for offline shell |

### App Shell Model
- Precache the app shell (HTML, JS/CSS bundles, key images) at SW install time
- Runtime-cache API responses and dynamic images with SWR or Network-First
- For static exports: precache generated HTML + hashed static assets

### Offline Support
- Serve dedicated offline fallback page when both cache and network fail
- Use `navigator.onLine` + `online`/`offline` events for detection (unreliable — test actual reachability with lightweight fetch)
- Background Sync API (`sync` event) for deferred offline actions
- Periodic Background Sync for background content refresh (requires engagement score in Chrome)

### Pitfalls
- Not versioning cached assets (content-hashed builds handle this automatically)
- Cross-origin opaque responses consume ~7MB each in cache storage
- Monitor storage with `navigator.storage.estimate()`, request persistence with `navigator.storage.persist()`

## 2. Web App Manifest

### Required Fields for Installability
- `name` or `short_name`
- `start_url`
- `display`: `standalone`, `minimal-ui`, `fullscreen`, or `window-controls-overlay`
- Icons: at least 192x192 and 512x512
- `id` field (recommended since 2024)

### Key Fields
- **`scope`**: Defines which URLs belong to the app
- **`icons`**: Include **maskable** icon for Android adaptive icons; SVG where supported
- **`screenshots`**: At least one for richer Android install UI (Chrome 117+). Use `form_factor: "wide"` / `"narrow"`
- **`shortcuts`**: Quick actions from home screen long-press
- **`share_target`**: Let users share content to your PWA
- **`launch_handler`**: Control behavior when launched while already open
- **`handle_links`**: Declare PWA should handle links to its scope (2025)

### basePath / Static Export
Set `start_url`, `scope`, and icon `src` paths relative to basePath.

### Pitfalls
- Missing maskable icon — Android crops into circle and looks broken
- `theme_color` mismatch between manifest and `<meta name="theme-color">`
- Use `.webmanifest` extension for proper MIME type

## 3. Push Notifications

### Architecture
1. Request permission after user action (never on page load)
2. Subscribe via `pushManager.subscribe()` with VAPID key
3. Server sends push via Web Push protocol (RFC 8030)
4. SW receives `push` event, shows notification
5. Handle clicks in `notificationclick` event

### Best Practices
- Ask at contextually relevant moment; show pre-prompt explaining value
- Keep payloads < 4KB, encrypt (Web Push handles this)
- Use `tag` to collapse related notifications
- Set appropriate TTL for time-sensitive content
- Every push must show a notification (no silent pushes)
- Handle `pushsubscriptionchange` for subscription rotation

### iOS Support
- Web Push works on iOS 16.4+ but only when PWA is installed (added to home screen)
- No Background Sync, Periodic Sync, or Badging API on iOS

### Static Export / No Server
Push requires external push service: OneSignal, FCM, or serverless function endpoint.

## 4. Performance (Core Web Vitals)

### Thresholds (2025)

| Metric | Good | Needs Improvement | Poor |
|---|---|---|---|
| **LCP** (Largest Contentful Paint) | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| **INP** (Interaction to Next Paint) | ≤ 200ms | ≤ 500ms | > 500ms |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

INP replaced FID as a Core Web Vital in March 2024.

### LCP
- Precache critical resources in SW
- `<link rel="preload">` for LCP image
- Inline critical CSS
- `fetchpriority="high"` on LCP element

### INP
- Break long tasks with `scheduler.yield()` or `setTimeout(0)`
- `React.startTransition` for non-urgent state updates
- `content-visibility: auto` for off-screen content
- Virtualize long lists

### CLS
- Set explicit `width`/`height` on images and iframes
- Reserve space for dynamic content
- `font-display: swap` with font preloading

## 5. PWA Installability

### Chrome Requirements (2025)
1. HTTPS (or localhost)
2. Manifest with required fields
3. Service worker with `fetch` event handler
4. Not already installed
- No engagement heuristic since 2023 — immediate install possible

### Install Promotion
- Stash `beforeinstallprompt` event, show custom install button
- iOS: No `beforeinstallprompt` — show manual instructions, detect with `navigator.standalone`
- Prompt only after engagement; dismissible banner, not modal
- After dismissal, wait ≥ 2 weeks to re-prompt

## 6. Workbox and Tooling

### Workbox v7+ Modules
- `workbox-precaching`: Precache manifest with versioning
- `workbox-routing`: Route registration with strategies
- `workbox-strategies`: CacheFirst, NetworkFirst, StaleWhileRevalidate
- `workbox-expiration`: Max entries/age per cache
- `workbox-cacheable-response`: Only cache specific status codes
- `workbox-background-sync`: Queue + replay failed requests
- `workbox-window`: Client-side registration, update detection

### Integration Approaches
1. **workbox-cli (generateSW)**: Post-build step scanning output directory — simplest
2. **workbox-build (injectManifest)**: Custom SW with injected precache manifest
3. **Serwist**: Community successor to `next-pwa`, designed for Next.js
4. **Vite PWA Plugin**: Zero-config PWA for Vite projects

### Other Tools
- PWABuilder: Generate SW, manifest, package for app stores
- Lighthouse CI: Automated PWA auditing in CI

## 7. Storage APIs

### IndexedDB
- Best for structured data, large datasets, offline stores
- Use `idb-keyval` for simple key-value, `idb` for complex schemas
- Quota: ~50-80% available disk

### Cache API
- HTTP response caching in service workers
- Let Workbox manage it — manual management is error-prone
- Opaque responses stored with ~7MB padding

### localStorage
- Small synchronous key-value (< 5MB)
- Not available in service workers
- Use only for quick preference reads

### Modern APIs
- **OPFS (Origin Private File System)**: File-system-like storage for large binaries
- **Storage Buckets API** (2025): Named buckets with different eviction policies
- Request persistent storage with `navigator.storage.persist()`

## 8. PWA Lifecycle

### SW Update Flow
1. Browser checks for updates on navigation (every 24h minimum)
2. New SW installs in background
3. New SW enters `waiting` state
4. Activates when all tabs close or `skipWaiting()` called

### Update Patterns
- **Prompt user (recommended)**: workbox-window detects waiting SW → show "Update available" toast → user clicks → skipWaiting + reload
- **Auto-update**: skipWaiting in install event — simpler but risks mixed-version assets
- **Auto with claim**: skipWaiting + clients.claim for instant activation

### Versioning
- Hash precache manifest (Workbox does automatically)
- Version cache names (e.g., `app-v2`), delete old in `activate`
- Serve `sw.js` with `Cache-Control: no-cache` or `max-age=0`
- Clean old caches in `activate` event

## 9. Security

### HTTPS
- Mandatory for service workers (except localhost)
- Use HSTS headers

### CSP
- `worker-src 'self'` required for SW registration
- `connect-src` must allow API origins
- For static export: set via `<meta>` tag or server headers

### SW Security
- Place `sw.js` at root for full scope
- No `eval()` in service workers
- Validate push payloads before display
- Use `workbox-cacheable-response` to only cache `200` responses

### Credential Storage
- Never store auth tokens in localStorage (XSS-accessible)
- Use httpOnly cookies or encrypted IndexedDB

## 10. Mobile Patterns

### iOS
- No `beforeinstallprompt` — manual install instructions needed
- `<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">`
- Apple-touch-startup-image for splash screens
- ~1GB storage limit; WebKit may evict after 7 days non-use

### Android
- TWA for Google Play distribution (PWABuilder/Bubblewrap)
- `shortcuts` in manifest for long-press actions
- `navigator.setAppBadge(count)` for unread count

### Responsive
- `env(safe-area-inset-*)` for notch/dynamic island
- Minimum 48x48px touch targets
- `overscroll-behavior-y: contain` to prevent default pull-to-refresh
- `overscroll-behavior: none` on scroll containers
