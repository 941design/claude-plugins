# End-to-End Testing

## Overview

ShopHop's e2e suite is a **Playwright + Next.js + strfry** harness that exercises the full collaboration stack: real browsers, a real Next.js dev server, a real Nostr relay (strfry running in Docker), and real MLS handshakes between simulated participants. There are ~70 spec files covering identity, list CRUD, multi-party collaboration, invite flows, offline behavior, signer integration, scanning, and more.

Tests run **single-worker, sequential** (`fullyParallel: false`, `workers: 1`) because they share relay state. A full run takes ~45 minutes.

## Stack

| Layer | Component | Why |
|---|---|---|
| Test runner | `@playwright/test` | Multi-context browser automation, network interception, fixtures |
| Browser | Headless Chromium (`chromium-headless-shell`) | Single browser → predictable behavior; matches deployed-PWA target |
| App server | `next dev` on port 3000 | Webserver auto-starts via `playwright.config.ts` `webServer` block |
| Relay | strfry (`dockurr/strfry:latest`) on port 7777 | Nostr relay; in-memory `tmpfs` so each test run starts clean |
| Compose file | `docker-compose.test.yml` | Defines the strfry service + ephemeral DB volume |
| Container name | `shophop-strfry` | Stable name so helper scripts can address it directly |

## Layout

```
e2e/
├── 01-identity.spec.ts          ← numbered spec files, run in order
├── 02-list-crud.spec.ts
├── ... (~70 files)
├── 58b-r5-no-remote-traffic-when-local.spec.ts
├── global-setup.ts              ← starts strfry before any test runs
├── global-teardown.ts           ← stops strfry after the run
├── preflight.mjs                ← npm `pretest:e2e` hook; checks port 3000
├── strfry.conf                  ← relay config (in-memory DB, generous limits)
└── helpers/
    ├── relay.ts                 ← startRelay / stopRelay (Docker lifecycle)
    ├── relay-query.ts           ← query published events from the relay
    ├── participant.ts           ← multi-context participant pattern
    └── actions.ts               ← high-level UI actions shared across specs
```

### Numbered spec files

Files are prefixed with a 2-digit number that loosely corresponds to the development epic that introduced them. Playwright doesn't enforce ordering between files (each is its own suite), but the numbering helps reading the suite chronologically and makes failure reports more navigable. Newer epics use 50+, sub-letters (`58a`, `58b`) for stories within an epic.

## Lifecycle

```
make test-e2e
   └─ npm run test:e2e
        ├─ pretest:e2e → e2e/preflight.mjs           ← fails early if port 3000 stale
        └─ npx playwright test
             ├─ webServer.command: npm run dev       ← starts Next on :3000 (or reuses)
             ├─ globalSetup → startRelay()           ← starts strfry on :7777 (or reuses)
             ├─ run spec files in order              ← 1 worker, sequential
             └─ globalTeardown → stopRelay()         ← stops strfry IF we started it
```

### Port reuse, not port grab

Both the dev server (`reuseExistingServer: !CI`) and the relay (port-probe in `helpers/relay.ts`) **detect existing instances and reuse them** instead of failing or double-starting. This makes local development friction-free: leave `make dev` running, leave `make relay-up` running, then re-run individual specs as you iterate.

The teardown logic mirrors this: if `startRelay()` reused an already-running relay, `stopRelay()` leaves it alone. Only relays that *this process* started get torn down. The same applies to the dev server (Playwright handles the webServer side).

### Preflight

`e2e/preflight.mjs` runs as the `pretest:e2e` npm hook before Playwright. It probes port 3000 and, if the port is held but not actually serving HTTP, prints a remediation hint (`lsof -t -i :3000 | xargs -r kill -9`) and exits 1. This catches the common "stale `next dev` zombie" failure mode before it manifests as a confusing test error.

### strfry config

`e2e/strfry.conf` is mounted into the container at `/etc/strfry.conf`. Key settings for testing:

- `db = "./strfry-db/"` — the container's `/app/strfry-db` is `tmpfs`, so the DB is wiped on every container restart.
- `rejectEventsNewerThanSeconds = 900` / `rejectEventsOlderThanSeconds = 94608000` — generous time windows for clock skew between host and VM.
- `ephemeralEventsLifetimeSeconds = 300` — ephemeral kinds (NIP-46 24133, etc.) live 5 min, comfortably longer than any single test.
- `maxFilterLimit = 500`, `maxSubsPerConnection = 20` — generous but bounded; high enough that no test should hit them.

## The participant pattern

Multi-party tests (collaboration, invites, group lifecycle) need multiple **isolated identities** that connect to the same relay but don't share localStorage/IndexedDB. The pattern:

```ts
import { createParticipant, closeParticipants } from "./helpers/participant";

test("Alice invites Bob", async ({ browser }) => {
  const alice = await createParticipant(browser, "Alice");
  const bob = await createParticipant(browser, "Bob");

  // ... drive alice.page and bob.page ...

  await closeParticipants(alice, bob);
});
```

`createParticipant`:

1. Spawns a fresh `BrowserContext` (= fresh storage partition).
2. Injects `localStorage["shophop-relays"] = ["ws://localhost:7777"]` via `addInitScript` so the app talks to the local strfry, not the production relay.
3. Navigates to `/`, waits for React effects to run (`useIdentityStore.initialize()` creates a key on first visit).
4. Sets the display name via the settings page so the participant has a stable handle in subsequent assertions.

Three-party tests (`04-three-participants.spec.ts`, `10-three-party-collaboration.spec.ts`) just call `createParticipant` three times. The pattern scales linearly until you start hitting test-runtime limits.

### Test relay override

The single most important e2e contract: **all tests must talk to the local strfry, never the production relay.** This is enforced by injecting `localStorage["shophop-relays"]` before any page load. New helpers that bypass `createParticipant` must replicate this injection — otherwise the test will silently hit `relay.shophop.941design.de` (or whatever default ships) and pollute production state.

## Running tests

### Full suite

```bash
make test-e2e          # runs preflight + full Playwright suite
```

### Single file (fastest iteration)

```bash
npx playwright test e2e/01-identity.spec.ts
```

### Single test in a file

```bash
npx playwright test e2e/09-shared-collaboration.spec.ts -g "Late joiner"
```

### Headed (watch the browser)

```bash
npm run test:e2e:headed
```

### UI mode (interactive picker)

```bash
npm run test:e2e:ui
```

## Fail-fast strategy

**For any run covering more than ~10 tests, use `--max-failures=1`:**

```bash
npx playwright test e2e/ --max-failures=1
```

Why: the suite is 45 minutes single-worker. When a regression lands, downstream tests typically fail for the same root cause. Letting the run continue past the first failure burns 40+ minutes of CI/dev time confirming what 5 minutes of triage would tell you. Stop on the first failure, fix it, then resume from where you stopped (or rerun the full suite if the fix is broad enough that earlier passes might now be invalid).

This is enshrined in user feedback and is the default expectation for any "run the e2e suite" instruction.

## Common failure modes

### `Executable doesn't exist at .../chrome-headless-shell-mac-arm64/...`

**Cause:** Playwright browsers were installed for the wrong OS (or into the shared `node_modules/playwright-core/.local-browsers/` legacy path).

**Fix:** see [`cross-environment-development.md`](./cross-environment-development.md), section 2. TL;DR:

```bash
rm node_modules/playwright-core/.local-browsers   # if it exists
npx playwright install chromium
```

### `Port 3000 is held but not responding`

**Cause:** A stale `next dev` process is holding the port without serving HTTP.

**Fix (the preflight tells you this):**

```bash
lsof -t -i :3000 | xargs -r kill -9
```

### Test passes locally but fails in `make test`

**Cause:** Usually a state leak — a previous spec left the relay or browser in an unexpected state. Single-worker sequential ordering means earlier specs influence later ones.

**Triage:** run the failing spec in isolation (`npx playwright test path/to/spec.ts`). If it passes solo, scan the specs that ran immediately before it for state they didn't clean up.

### Collaboration test times out at 2 min

**Cause:** MLS handshakes between participants are slow. The 2-minute per-test timeout in `playwright.config.ts` accounts for this, but if a participant fails to publish their KeyPackage (relay unreachable, identity-store bug), the partner waits the full timeout.

**Triage:** check the relay logs (`docker logs shophop-strfry`) for the participant's KeyPackage publish during the test window. If it never arrived, the bug is in the publishing identity, not the receiving one.

### Tests fail with `relay [...] is held` or `Cannot connect to relay`

**Cause:** Docker isn't running, or the strfry container crashed.

**Fix:**

```bash
docker ps                      # is shophop-strfry running?
docker logs shophop-strfry     # any panics?
make relay-down && make relay-up
```

### All tests fail with `0ms` runtime

**Cause:** Playwright failed to launch the browser at all (missing binary). The 0ms means the test never ran — the failure happened before `test()` body started.

**Fix:** see browser-binary section above.

## Helpers

### `helpers/relay.ts`

Bracketed lifecycle: `startRelay()` / `stopRelay()`. Tracks `startedByUs` so a relay reused from a prior session is left alone on teardown. Uses bash's `/dev/tcp` for port probing (no dependency on `nc`, which isn't on minimal Linux dev VMs).

### `helpers/relay-query.ts`

Direct relay queries from inside tests. Useful for asserting "Alice's KeyPackage is on the relay" or "no kind:24133 events were published" (R5 invariant in spec 58b).

### `helpers/participant.ts`

The multi-context pattern described above. Constants: `TEST_RELAY = "ws://localhost:7777"`. Helpers: `createParticipant`, `closeParticipants`, `goHome`.

### `helpers/actions.ts`

Higher-level UI verbs shared across specs (create list, add item, send invite, etc.). When a UI selector or flow changes, fix it once here rather than across every spec.

## Test data attributes

Use `data-testid` attributes for stable selectors. Text-based selectors are brittle against copy changes; CSS-class selectors are brittle against styling refactors. The codebase has been progressively migrated to `data-testid` (see `specs/epic-e2e-collaboration-testing/S1-test-data-attributes/`); follow the established pattern when adding new components.

## What e2e tests do NOT cover

- **Push notifications** — require service worker + browser permission flows that are flaky in headless. Tested manually.
- **Real Nostr relays** — by design. Production relay is for production traffic only.
- **iOS/Android-specific PWA install flows** — Chromium only. Mobile-specific behavior (e.g. iOS standalone-mode quirks) is verified manually on device.
- **Camera-based barcode scanning** — Playwright can't open a real camera. There's a stub harness for the scan flow, but the actual ZXing decode is unit-tested.

## Cross-references

- Browser binary management across host/VM: [`cross-environment-development.md`](./cross-environment-development.md), section 2.
- Spec-by-spec acceptance criteria: `specs/epic-e2e-collaboration-testing/acceptance-criteria.md`.
- Playwright config: [`../playwright.config.ts`](../playwright.config.ts).
- Strfry config: [`../e2e/strfry.conf`](../e2e/strfry.conf).
- Compose file: [`../docker-compose.test.yml`](../docker-compose.test.yml).
