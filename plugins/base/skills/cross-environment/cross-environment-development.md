# Cross-Environment Development (host OS + VM/container sharing one project tree)

## Topology

This pattern applies whenever a project tree is developed in parallel from **two architectures that share the same physical files** — typically a macOS host with a Linux VM (or container) mounted onto the same directory:

| Environment | Role | Platform | `$HOME` |
|---|---|---|---|
| Host (e.g. macOS) | Primary dev (IDE, browser testing, deploys) | `darwin-arm64` | `/Users/<user>` |
| VM/container (e.g. Linux) | Secondary dev (CI-like runs, Linux-only checks) | `linux-x64` | `/home/<user>` |

The project directory is mounted into the VM. **Source files, `node_modules`, Playwright browsers, build artifacts — everything under the project tree is the same byte sequence to both environments.** Anything that depends on platform-specific binaries must therefore be partitioned, scoped, or rebuilt at the boundary; otherwise an install on one OS clobbers the other's.

There are three classes of platform-specific state, each with its own handling:

1. Native Node bindings inside `node_modules/`
2. Playwright browser binaries
3. Claude Code session environment variables

---

## 1. Native Node bindings (`node_modules/`)

### Problem

Several npm packages ship per-platform native binaries — `rollup`, `rolldown`, `@next/swc`, `lightningcss`, `esbuild`, etc. Each install resolves the `cpu`/`os` field of optional dependencies to the current host. The resulting `node_modules/` will fail to load on the other architecture (`Cannot find module @next/swc-darwin-arm64` on Linux, or vice versa).

### Solution: platform stamp + Makefile

`node_modules/.platform` records the platform that the current install targeted. Every Make target that depends on `node_modules` checks this stamp and triggers a full reinstall on mismatch:

```make
PLATFORM_STAMP := node_modules/.platform
CURRENT_PLATFORM := $(shell node -e "console.log(process.platform+'-'+process.arch)")

node_modules: package.json package-lock.json
	@if [ -f $(PLATFORM_STAMP) ] && [ "$$(cat $(PLATFORM_STAMP))" != "$(CURRENT_PLATFORM)" ]; then \
		echo "Platform changed ($$(cat $(PLATFORM_STAMP)) → $(CURRENT_PLATFORM)), cleaning node_modules..."; \
		rm -rf node_modules; \
	fi
	npm install
	npx playwright install chromium
	@echo "$(CURRENT_PLATFORM)" > $(PLATFORM_STAMP)
```

An `ifneq` block can force `node_modules` to be re-evaluated as PHONY when the stamp doesn't match the current platform, so the dependency check fires even when the directory exists.

### Rules of engagement

- **Always invoke through `make`.** `make build`, `make test`, `make dev`, etc. all transitively depend on `node_modules` and will reinstall if needed. A bare `npm install` does not refresh the stamp.
- **Never hand-edit `node_modules/.platform`.** If you suspect it's wrong, just delete it — the next `make` run will reinstall and rewrite it.
- **`make distclean` is the nuke option.** Removes `node_modules` outright; useful if a partial install leaves the tree in a corrupt state.

### Symptoms of bad state

- `Error: Cannot find module '@next/swc-<platform>-<arch>'` when running `next dev`/`next build`.
- `Error: Cannot find module @rollup/rollup-<platform>-<arch>`.
- Any "module not found" error mentioning `darwin`/`linux`/`arm64`/`x64` in the package name.

Recovery: `rm node_modules/.platform && make node_modules` (or just `make` whatever target you needed).

---

## 2. Playwright browser binaries

### Problem

Playwright downloads platform-specific Chromium builds (`chrome-mac-arm64`, `chrome-linux`, etc.). If both environments install browsers into the same shared path, the second install **silently overwrites** the first. The next test run on the original platform fails with:

```
Error: browserType.launch: Executable doesn't exist at .../chrome-headless-shell-mac-arm64/chrome-headless-shell
```

even though `npx playwright install` reports the browser is already installed (the directory exists, but contains the wrong-OS binary).

### Solution: per-OS default cache (do NOT use `PLAYWRIGHT_BROWSERS_PATH=0`)

Playwright's default behavior is to install browsers into a per-user, per-OS cache:

| OS | Default cache |
|---|---|
| macOS | `~/Library/Caches/ms-playwright/` |
| Linux | `~/.cache/ms-playwright/` |
| Windows | `%USERPROFILE%\AppData\Local\ms-playwright\` |

Because `$HOME` differs between the host and the VM, **the two caches are fully isolated.** Each environment sees only its own browsers; switching architectures requires zero reinstall once both caches are populated.

The Makefile and `package.json` scripts therefore deliberately **omit** any `PLAYWRIGHT_BROWSERS_PATH` setting:

```make
node_modules: package.json package-lock.json
	...
	npx playwright install chromium      # ← installs to per-OS cache
```

```json
"scripts": {
	"test:e2e": "npx playwright test",
	"test:e2e:ui": "npx playwright test --ui",
	"test:e2e:headed": "npx playwright test --headed"
}
```

### Anti-pattern: `PLAYWRIGHT_BROWSERS_PATH=0`

Setting `PLAYWRIGHT_BROWSERS_PATH=0` forces Playwright to install browsers into `node_modules/playwright-core/.local-browsers/` — i.e. **inside the shared project tree**. This is the bug that motivates this entire section. Do not reintroduce it. If you need a project-local install for some other reason (e.g. pre-bundling browsers in CI), pick a path *outside* `node_modules` and suffix it with the platform: `.playwright-browsers/<platform>-<arch>/`.

### Symptoms of bad state

- `Executable doesn't exist at .../chrome-headless-shell-<wrong-platform>/chrome-headless-shell`
- A `node_modules/playwright-core/.local-browsers/` directory exists (it shouldn't — that's the legacy `=0` location).
- `npx playwright install` produces no output but tests still fail with the missing-binary error (the directory exists, contents are wrong-OS).

### Recovery

```bash
rm node_modules/playwright-core/.local-browsers      # delete legacy shared dir
npx playwright install chromium                       # repopulate per-OS cache
```

If the per-OS cache itself is corrupt (rare):

```bash
rm -rf ~/Library/Caches/ms-playwright/chromium*       # macOS
rm -rf ~/.cache/ms-playwright/chromium*               # Linux
npx playwright install chromium
```

First-time install on a fresh machine downloads ~250 MB. Subsequent invocations (and architecture switches) are no-ops.

---

## 3. Claude Code session environment

### Problem

When Claude Code starts, the harness reads `$HOME` and freezes derived absolute paths (`CLAUDE_PLUGIN_DATA`, plugin state directories, etc.) into the session's environment. These do **not** update when the underlying filesystem becomes the VM (or back). Any plugin that resolves state directories from `CLAUDE_PLUGIN_DATA` — Codex is the canonical example — will fail with `ENOENT` because the path baked into the session points at the originating OS's home directory, not the current one.

### Solution

**After switching machines, restart Claude Code.** Not just the shell — the entire CLI session. A fresh session re-reads `$HOME` from the current OS and recomputes all derived paths.

### Workarounds (not persistent)

For a single command, you can override:

```bash
CLAUDE_PLUGIN_DATA=/correct/path node ...
```

This does not persist past the command. There is no in-session way to re-derive the harness env vars; only a fresh session resolves them cleanly.

### Symptoms

- Codex (or another plugin) errors with `ENOENT: no such file or directory, ... CLAUDE_PLUGIN_DATA/...`
- Plugin state seems to "reset" or "lose memory" after switching environments
- Slash commands or hooks that read absolute paths produce the wrong contents

---

## Quick checklist when switching environments

Going host → VM (or VM → host):

1. **In the new environment**, restart any Claude Code session that was open (`/quit` then re-`claude`).
2. Run any `make` target you need. The platform stamp will trip and `node_modules` will be rebuilt automatically.
3. First time only: `npx playwright install chromium` will download the per-OS browser cache (the Makefile already runs this as part of `node_modules`).
4. Verify with a quick smoke test (e.g. `npx playwright test e2e/<smallest-spec>.spec.ts --max-failures=1`).

If anything misbehaves, walk back through sections 1–3 above in order — that's roughly the order of likelihood.

---

## What you should never do

- Hand-edit `node_modules/.platform`.
- Set `PLAYWRIGHT_BROWSERS_PATH=0` (anywhere — Makefile, package.json, shell, `.env`).
- Run `npm install` directly when switching platforms — use `make` so the stamp logic fires.
- Try to "fix" Claude Code env vars in-session — restart the CLI.
- Commit `node_modules/`, `node_modules/.platform`, `.playwright-browsers/`, or any browser binaries.
