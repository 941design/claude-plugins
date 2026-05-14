# Bug Report: verifier-cannot-distinguish-pre-existing

## Description

The `base:verification-examiner` cannot distinguish pre-existing diff hunks (uncommitted
changes already present in the working tree before `/base:feature` started) from
story-introduced changes. This causes false-positive scope violations: the examiner sees
a modified file it believes should be untouched, raises a severity-7 scope violation, and
forces lead-side reconciliation even when the story implementation is entirely correct.

## Expected Behavior

Verification examiners should only flag changes that were introduced by the story being
verified. Pre-existing uncommitted hunks in files that were modified before the epic
started must be excluded from scope-boundary AC checks.

## Actual Behavior

Both S2 and S3 verifiers in epic-base-next raised severity-7 scope violations against
pre-existing uncommitted hunks in `plugins/base/commands/bug.md`. The lead had to
manually reconcile these findings twice, explaining that the hunks were pre-existing. The
examiner had no mechanism to exclude them.

## Reproduction Steps

1. Start a `/base:feature` run with uncommitted changes already present in the working tree
   (i.e., modified files with staged or unstaged hunks that predate the epic).
2. The story implementation does not touch those pre-existing modified files.
3. The `base:verification-examiner` scores scope-boundary ACs (e.g., "only files in the
   story contract were modified") — it raises a violation because it sees the pre-existing
   hunks.
4. Lead must manually intervene to explain the pre-existing context.

## Impact

- Lead-side reconciliation burden: 2+ manual explanations per epic with a dirty working tree.
- Severity-7 false positives block fast-path acceptance, triggering ESCALATE or manual ACCEPT overrides.
- Examiners receive no baseline context so cannot make scope-boundary determinations correctly.

## Anchor

`plugins/base/commands/feature.md` — startup phase of the feature workflow where the
working-tree snapshot should be captured and persisted to `epic-state.json`.

## Source

BACKLOG.md finding promoted 2026-05-14.
Finding: `verifier-cannot-distinguish-pre-existing-diff` [scope:base-plugin]
