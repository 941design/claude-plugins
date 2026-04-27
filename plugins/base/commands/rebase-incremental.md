---
name: rebase-incremental
description: Stage a rebase across semantic baselines on the target branch — test, fix, and tag between increments. Use when a long-lived branch has drifted far from main/master and a single rebase would be too risky.
argument-hint: [<target-branch>] [--no-adopt]
allowed-tools: Task, Read, Write, Edit, Bash, AskUserQuestion, Skill
model: opus
---

# Incremental Rebase — Agent Team Blueprint

You are the **team lead**. Your job is to rebase the user's current branch onto the target in stages: pick semantic milestones on the target, advance to each one in its own subagent context, run tests between stages, and tag every checkpoint so the history stays inspectable.

## Input: $ARGUMENTS

`$ARGUMENTS` accepts:
- A target branch name (`origin/master`, `upstream/main`, `develop`, etc.). If omitted, auto-detect: prefer `origin/master`, then `origin/main`, then `main`, then `master`.
- `--no-adopt`: opt out of automatic ref adoption on a fully-green run. By default, when every iteration returns `ok`, the lead stamps a safety tag on the original branch tip and then moves the user's branch ref to the rebased commit (Step 5). Pass this flag to keep the legacy "print the command, don't run it" behavior.

---

## Step 1: Setup

### Language detection
Detect project language from config files (`pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle.kts`) and consult `skills/languages/{language}.md` for test commands.

### Resolve target & validate state
```
target = $ARGUMENTS or auto-detect (origin/master → origin/main → main → master)
git rev-parse --verify "$target"        # must succeed
branch_name = git rev-parse --abbrev-ref HEAD
original_sha = git rev-parse HEAD
```

**Working-tree check (tracked changes only).** Untracked files cannot affect a separate worktree, so they MUST NOT block. Refuse only on tracked modifications:
```
tracked_dirty = $(git status --porcelain --untracked-files=no)
untracked     = $(git ls-files --others --exclude-standard)
```
- If `tracked_dirty` is non-empty → refuse with a clear error listing the modified/staged paths.
- If `untracked` is non-empty → report the count (and first ~5 paths) as an FYI and continue.

**Fetch with explicit fallback.** Only relevant if `$target` is a remote-tracking ref:
```
remote = remote-of-target (e.g. "origin" for "origin/master")
git fetch "$remote" --prune       # attempt
```
- On success: continue.
- On failure (network, SSH host key, auth): compute the cached ref's age:
  ```
  cached_age = $(git log -1 --format=%cr "$target")     # e.g. "3 days ago"
  ```
  Report literally: `fetch from <remote> failed: <stderr summary>; current <target> is <cached_age> — proceed with cached ref or fix and retry?` and ask via `AskUserQuestion` (options: `proceed-with-cached`, `abort-and-fix`). Do NOT silently fall back.

```
merge_base       = git merge-base HEAD "$target"
commits_in_range = git rev-list --count --first-parent "$merge_base..$target"
```

The `--first-parent` count matches how baselines are actually selected (Tier-1 candidates walk the first-parent chain). Report this number to the user verbatim — a plain `--count` returns total commits including merged-in side branches, which produces a misleadingly larger figure than the analyzer's candidate pool.

If `commits_in_range == 0`: branch is already at or ahead of target — nothing to do. Report and exit.
If `commits_in_range < 5`: warn that a plain `git rebase` is probably simpler; ask via `AskUserQuestion` whether to continue.

### Pre-flight overlap detection

Before any baseline analysis, check how many of the user's commits are already in the target (squash-merged, cherry-picked, or independently re-introduced upstream):
```
git cherry "$target" HEAD "$merge_base"
```
Lines beginning with `-` are commits whose patch-id already exists upstream (will be dropped by rebase); lines beginning with `+` will be replayed. If any `-` lines exist, report:
- `N of M of your commits already exist on <target> by patch-id — they will be dropped during rebase.`
- List the first ~5 dropped subjects so the user can sanity-check.

This reframes expectations *before* the staged work begins. Do not block on overlap — just surface it. If `N == M` (every commit is already upstream), warn that the rebase will produce an empty branch and ask whether to continue.

### Compute paths
```
git_dir       = git rev-parse --git-common-dir
branch_slug   = branch_name with / → -
worktree_path = $git_dir/rebase-incremental/$branch_slug/worktree
state_path    = $git_dir/rebase-incremental/$branch_slug.json
scratch_branch = rebase-incremental/$branch_slug/stage
```

The user's branch is **never checked out** in the second worktree (Git rejects that). Instead we operate on a dedicated scratch branch that starts at `original_sha` and walks forward through the baselines. Adoption (Step 5) moves the user's branch to the scratch branch's final commit.

### Crash recovery check
If `state_path` already exists:
- Read it. If `branch == branch_name` and `worktree_path` still exists → resume from `phase` (table at the bottom of this file).
- If stale (different branch): ask the user whether to delete and start fresh.

### Create dedicated worktree + scratch branch
```
mkdir -p "$git_dir/rebase-incremental/$branch_slug"
git worktree add --detach "$worktree_path" "$original_sha"
git -C "$worktree_path" checkout -b "$scratch_branch"
git -C "$worktree_path" config rerere.enabled true
git -C "$worktree_path" config rerere.autoUpdate true
```
The worktree starts detached at `original_sha`, then a fresh `$scratch_branch` is created and checked out — this avoids the "branch already checked out elsewhere" error and keeps the user's branch ref untouched until adoption. `rerere` is scoped to the worktree config so conflict resolutions from earlier iterations are reused automatically when the same hunks reappear later.

### Install dependencies once

Per-iteration `install --frozen-lockfile` is wasteful — a clean install is typically 20–60s and the lockfile rarely changes mid-rebase. Install **once** here; workers re-install only when the lockfile actually changes.

Detect package manager from lockfile:
| Lockfile present | Install command | Store-dir flag |
|---|---|---|
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile --store-dir "$worktree_path/.pnpm-store"` | yes |
| `yarn.lock` | `yarn install --frozen-lockfile --cache-folder "$worktree_path/.yarn-cache"` | yes |
| `package-lock.json` | `npm ci --cache "$worktree_path/.npm-cache"` | yes |
| `Cargo.lock` | `cargo fetch` | uses `CARGO_HOME=$worktree_path/.cargo` |
| `poetry.lock` | `poetry install --no-root` | venv inside worktree |
| `uv.lock` | `uv sync --frozen` | uses worktree `.venv` |
| `go.sum` | `go mod download` | uses `GOMODCACHE` if set |
| `Gemfile.lock` | `bundle install --path "$worktree_path/.bundle"` | yes |
| `build.gradle.kts` / `pom.xml` | none — let workers run their build | n/a |

**Always direct the package-manager store into the worktree** (via `--store-dir`, `--cache`, env vars, etc.) so nothing leaks back into the main checkout's `.gitignore` view. If no lockfile is present, skip this step.

Capture the lockfile hash for the change-detection contract:
```
lockfile_hash = sha256 of the chosen lockfile (or "" if none)
install_command = <command from table>     # may be ""
```
Persist `lockfile_path`, `lockfile_hash`, and `install_command` to the state file. Workers receive these and skip install when the hash is unchanged.

### Initialize state
Write the state file to `$state_path` (under `.git/`, so the user's checkout stays clean):
```json
{
  "branch": "<branch_name>",
  "branch_slug": "<branch_slug>",
  "scratch_branch": "<scratch_branch>",
  "target": "<target>",
  "original_sha": "<original_sha>",
  "merge_base": "<merge_base>",
  "worktree_path": "<worktree_path>",
  "state_path": "<state_path>",
  "language": "<language>",
  "test_command": null,
  "install_command": "<install_command or empty>",
  "lockfile_path": "<path or empty>",
  "lockfile_hash": "<sha256 or empty>",
  "adopt": true,
  "phase": "INITIALIZED",
  "phase_history": [{"phase": "INITIALIZED", "timestamp": "<now>"}],
  "candidates": [],
  "selected_baselines": [],
  "iterations": [],
  "current_iteration": 0
}
```

---

## Step 2: Phase 1 — Analyze target history

Spawn a `history-analyzer` subagent:
- Send: `MERGE_BASE`, `TARGET_REF`, `TARGET_HEAD` (resolved SHA), `BRANCH_NAME`, `WORKTREE_PATH`.
- Wait for its JSON response.

Persist the returned candidate list under `candidates` in the state file. Transition phase: `INITIALIZED` → `ANALYZING` → `CANDIDATES_READY`.

### Fallback if Tier-1 was empty
If `candidates` is `[]` and `commits_in_range >= 5`:
- Ask the user via `AskUserQuestion` whether to fall back to **evenly-spaced** chunks (3 evenly-distributed commits along the first-parent chain) or abort.
- If yes: compute the chunked baselines yourself with `git log --first-parent --pretty=%H "$merge_base..$target"` and pick at indices `n/4`, `n/2`, `3n/4`. Label them `even-spaced`.

### Cap & sanity
- If `len(candidates) > 8`: keep the most evenly-distributed 8.
- If `len(candidates) < 2` after fallback: warn, but proceed if the user confirms.

---

## Step 3: Confirm plan with user

Use **two** `AskUserQuestion` prompts (one message, both at once):

1. **Baseline selection.** Show all candidates as a multiSelect (default: all selected). Each option label like `[merge] abc1234 — "Merge pull request #441…"`.
2. **Test command.** Auto-discover the project's canonical test command from `skills/languages/{language}.md` (e.g. `npm test`, `pytest`, `cargo test`, `go test ./...`, `make test`). Single-select with options: confirm the discovered command, edit it (user types a custom one), or skip tests entirely (with a strong warning that the safety net is gone).

Persist `selected_baselines` (ordered oldest→newest) and `test_command` to the state file. Transition phase → `PLAN_CONFIRMED`.

---

## Step 4: Phase 2 — Iterative rebase loop

For each baseline `B_i` (i from 1 to N) in `selected_baselines`:

1. Update `current_iteration = i` and append a `phase_history` entry → `ITERATING`.
2. **Spawn a fresh `rebase-worker` teammate** (a NEW subagent each iteration — do not reuse the previous one; that is the entire point of "own subagent context per iteration"). Send:
   - `BASELINE_SHA`, `BASELINE_INDEX = i`, `BRANCH_SLUG`, `SCRATCH_BRANCH`, `WORKTREE_PATH`
   - `TEST_COMMAND`, `LANGUAGE`
   - `INSTALL_COMMAND`, `LOCKFILE_PATH`, `LOCKFILE_HASH` (from state). Worker re-runs `INSTALL_COMMAND` only when the lockfile's current hash differs from `LOCKFILE_HASH` (post-rebase). Empty `INSTALL_COMMAND` → never install.
   - `PREVIOUS_ANCHOR` = `{kind: "tag", ref: "<prev-tag>"}` for `i > 1`, else `{kind: "sha", ref: "<original_sha>"}`. The worker uses this as a hard rollback target if the iteration fails partway.
3. Wait for the worker's JSON result.
4. Append the result to `iterations[]` in the state file with timestamps. If the worker reports `lockfile_hash_after` and it differs from the stored `lockfile_hash`, update the stored value so subsequent iterations compare against the new baseline.
5. Branch on `status`:
   - **`ok`**: continue to the next baseline.
   - **`stuck`**: invoke `Skill("codex:rescue", args: "--wait Incremental rebase iteration <i> on <branch> stuck at <stage>. Worktree: <path>. Baseline: <sha>. Diagnostics: <copy worker's diagnostics>. Files in conflict: <list>. Test command: <cmd>.")`.
     - If rescue resolves it (working tree clean, tests passing): spawn a **new** `rebase-worker` for the same baseline with a `RESUMING_AFTER_RESCUE` flag and the prior diagnostics for context. If it now returns `ok`, continue.
     - If rescue fails or the re-spawned worker also returns `stuck`: transition phase → `ESCALATED`, stop the loop, jump to Step 5.
   - **`aborted`**: precondition violated — investigate (likely a stale rebase or dirty worktree). If recoverable, retry once; otherwise escalate.

After all baselines processed without escalation: phase → `COMPLETE`.

### Hard rule
The iteration loop runs sequentially. Never parallelize — each rebase depends on the prior iteration's branch state.

---

## Step 5: Wrap up

### On `COMPLETE`

**Adoption decision.** Auto-adopt is the default when every iteration returned `ok`. The combination "stamp safety tag → update-ref → remove worktree" is fully reversible: the user can always `git update-ref refs/heads/<branch> rebase/<branch_slug>/00-original-<sha>` to restore the original tip. Skip auto-adoption only if:
- The user passed `--no-adopt`, OR
- Any iteration returned `stuck` or required rescue (in that case the run already routed through `ESCALATED`, not `COMPLETE` — but double-check `iterations[]` for safety), OR
- The branch's current SHA on disk no longer matches `original_sha` (someone moved it during the run — abort adoption and tell the user).

**Auto-adopt path** (default):
```
# 1. Verify branch hasn't moved since we started
test "$(git rev-parse refs/heads/<branch>)" = "<original_sha>" || ABORT

# 2. Safety tag stamps the pre-rebase tip — the undo button
git tag -a "rebase/<branch_slug>/00-original-<short_sha>" "<original_sha>" \
  -m "Pre-rebase original tip of <branch>; created by /rebase-incremental on <date>"

# 3. Peel the final staging tag to its commit (annotated tag objects are not commits)
final_commit=$(git rev-parse "rebase/<branch_slug>/<NN>-<sha>^{commit}")

# 4. Move the user's branch ref
git update-ref refs/heads/<branch> "$final_commit" "<original_sha>"
#                                                    ^^^^^^^^^^^^^^^
# The trailing oldvalue makes update-ref atomic — refuses if the branch moved.

# 5. Clean up worktree + scratch branch
git worktree remove "<worktree_path>"
git branch -D rebase-incremental/<branch_slug>/stage
```

Then report to the user:
- ✓ Branch `<branch>` adopted at `<final_commit>` (was `<original_sha>`).
- Safety tag: `rebase/<branch_slug>/00-original-<sha>` — to undo: `git update-ref refs/heads/<branch> rebase/<branch_slug>/00-original-<sha>`
- N intermediate tags created (list with short SHAs and test summaries).
- Total files changed across the staged rebase.
- **Cleanup command** for the staging tags (only after the user is satisfied):
  ```
  git tag -l "rebase/<branch_slug>/*" | xargs -r git tag -d
  ```
  (Includes the safety tag — the user should keep that one until they're confident.)

**Manual path** (`--no-adopt` or precondition failed):
Print the same `git update-ref` / `git worktree remove` / `git branch -D` commands and ask the user to run them. Do not run anything destructive. Mention the safety-tag pattern they can use if they want it.

### On `ESCALATED`
- Leave worktree, partial tags, scratch branch, and the state file (under `.git/`) intact for resume.
- Report which iteration failed, the worker's diagnostics, and what codex:rescue returned.
- Tell the user the scratch branch was reset to the previous successful tag (or `original_sha` for iteration 1) before the worker reported `stuck`, so the worktree is at a known-good state matching the last green tag.
- Tell the user they can fix manually inside the worktree and re-run `/rebase-incremental` to resume, or run `git worktree remove --force <worktree_path> && git branch -D <scratch_branch>` to discard.

---

## Crash Recovery

If a state file exists at `$git_dir/rebase-incremental/<branch_slug>.json`:

| Phase | Resume action |
|-------|---------------|
| `INITIALIZED` | Re-run Step 2 (analysis). |
| `ANALYZING` / `CANDIDATES_READY` | Re-run Step 3 (user confirmation). |
| `PLAN_CONFIRMED` / `ITERATING` | Verify worktree exists and the scratch branch is at the last successful tag's commit (`git -C <path> rev-parse HEAD == git rev-parse <last-tag>^{commit}`); resume the loop at `current_iteration`. If the previous iteration's worker never recorded a result, treat it as `stuck` and route to codex:rescue. |
| `ESCALATED` | Show the last diagnostics; ask whether to retry the failing iteration or abort. |
| `COMPLETE` | Re-print the wrap-up summary; do nothing else. |

Before resuming any iteration, verify worktree integrity (`git -C <path> status`, no in-progress rebase) and that the `PREVIOUS_ANCHOR` still resolves to a commit.

---

## Hard rules for the lead

- **Sequential only.** No parallel worker spawning.
- **Never push, never delete user-created tags or branches.**
- **Auto-adopt is allowed only under all of these conditions** (Step 5 default path): every iteration returned `ok`, `--no-adopt` was not passed, the branch ref still matches `original_sha`, the safety tag `rebase/<branch_slug>/00-original-<sha>` was created first, and `git update-ref` is invoked with the trailing `<original_sha>` oldvalue argument so the move is atomic. Outside that exact recipe, `update-ref refs/heads/<branch>` is forbidden — print the command for the user instead.
- **Worktree is sacred.** All git mutations go through it. The user's main checkout is read-only from this command's perspective until the Step 5 adoption (which is the one explicit exception).
- **Tracked-changes-only refusal at Step 1.** Untracked files do not block; modified or staged tracked files do. Refuse with a clear message listing the offending paths.
