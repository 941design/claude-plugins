---
name: rebase-incremental
description: Stage a rebase across semantic baselines on the target branch — test, fix, and tag between increments. Use when a long-lived branch has drifted far from main/master and a single rebase would be too risky.
argument-hint: [<target-branch>]
allowed-tools: Task, Read, Write, Edit, Bash, AskUserQuestion, Skill
model: opus
---

# Incremental Rebase — Agent Team Blueprint

You are the **team lead**. Your job is to rebase the user's current branch onto the target in stages: pick semantic milestones on the target, advance to each one in its own subagent context, run tests between stages, and tag every checkpoint so the history stays inspectable.

## Input: $ARGUMENTS

`$ARGUMENTS` may name a target branch (`origin/master`, `upstream/main`, `develop`, etc.). If empty, auto-detect: prefer `origin/master`, then `origin/main`, then `main`, then `master`.

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
git status --porcelain                   # MUST be empty — refuse with a clear error if not
git fetch <remote-of-target>             # only if target is a remote-tracking ref
merge_base = git merge-base HEAD "$target"
commits_in_range = git rev-list --count "$merge_base..$target"
```

If `commits_in_range == 0`: branch is already at or ahead of target — nothing to do. Report and exit.
If `commits_in_range < 5`: warn that a plain `git rebase` is probably simpler; ask via `AskUserQuestion` whether to continue.

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
   - `PREVIOUS_ANCHOR` = `{kind: "tag", ref: "<prev-tag>"}` for `i > 1`, else `{kind: "sha", ref: "<original_sha>"}`. The worker uses this as a hard rollback target if the iteration fails partway.
3. Wait for the worker's JSON result.
4. Append the result to `iterations[]` in the state file with timestamps.
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
Report to the user:
- N tags created, listed with their short SHAs and test summaries.
- Total files changed across the staged rebase.
- Worktree location.
- Final tag name (e.g. `rebase/<branch_slug>/05-abc1234`).
- **Adoption command** (do NOT run automatically — destructive on a named ref). Always peel the tag to its commit; `git update-ref` with a tag-object SHA would point the branch at the tag object, not the commit:
  ```
  final_commit=$(git rev-parse "rebase/<branch_slug>/<NN>-<sha>^{commit}")
  git update-ref refs/heads/<branch> "$final_commit"
  git worktree remove <worktree_path>
  git branch -D rebase-incremental/<branch_slug>/stage   # scratch branch cleanup
  ```
- **Cleanup command** for the staging tags (only after the user is satisfied):
  ```
  git tag -l "rebase/<branch_slug>/*" | xargs -r git tag -d
  ```

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
- **Never auto-run** the `git update-ref refs/heads/<branch> ...` command — that overwrites the user's branch. Always print it for them to run.
- **Worktree is sacred.** All git mutations go through it. The user's main checkout is read-only from this command's perspective.
- **No silent abort on dirty working tree** at Step 1 — refuse with a clear message and exit.
