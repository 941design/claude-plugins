---
name: bug
description: Fix bugs through a systematic team workflow — reproduction, analysis, minimal fix, verification. ALWAYS use this for ALL bug fixes.
argument-hint: <@bug-report-file> OR <bug-description>
allowed-tools: Task, Read, Write, Edit, Bash, AskUserQuestion, Skill
model: opus
---

# Bug Fix — Agent Team Blueprint

You are the **team lead**. Your job is to coordinate a small team that fixes a bug surgically: minimal changes, root cause focus, regression-tested.

## Input: $ARGUMENTS

---

## Step 1: Understand the Bug

### Language Detection

Detect project language from config files (pyproject.toml, package.json, go.mod, Cargo.toml, pom.xml, build.gradle.kts) and consult `skills/languages/{language}.md` for build/test commands throughout.

### Gather Details

```
IF argument is a .md file path or starts with @:
    Read the bug report file
    Validate: has description, expected/actual behavior, reproduction steps, impact
    If gaps: use AskUserQuestion, update file
ELSE:
    Gather details via AskUserQuestion:
    - What is the symptom?
    - Steps to reproduce?
    - Expected vs actual behavior?
    - Any error messages?
    Write bug report to bug-reports/{slug}-report.md
```

### Explore the Codebase

Use the Agent tool with `subagent_type: base:code-explorer` to launch 2 explorers in parallel (both Agent calls in a single message):
- **Agent 1**: Bug symptoms — error messages, affected components, recent changes
- **Agent 2**: Architecture — dependencies, integration points, similar past bugs

Read 5-10 key files to understand the affected area.

### Generate Verification Questions

Based on bug complexity, generate verification questions:
- **LOW** (single component, clear fix): 4-5 questions
- **MEDIUM** (multiple components, some ambiguity): 6-8 questions
- **HIGH** (cross-cutting, multiple root causes possible): 8-12 questions

### Create State File

Write `bug-reports/{slug}-state.json`:
```json
{
  "bug_name": "{slug}",
  "bug_report_file": "bug-reports/{slug}-report.md",
  "created_at": "{timestamp}",
  "updated_at": "{timestamp}",
  "phase": "INITIALIZED",
  "complexity": "{low|medium|high}",
  "verification_questions": [...],
  "baseline": null,
  "fix": null,
  "verification_rounds": [],
  "phase_history": [
    {"phase": "INITIALIZED", "timestamp": "{timestamp}", "trigger": "workflow_start"}
  ]
}
```

---

## Step 2: Create the Team

Create an agent team with two roles:

**Fixer** (1 teammate)
> You fix bugs surgically: minimal changes, root cause focus, regression-tested. Your workflow:
> 1. Read the bug report the lead sends you
> 2. Detect project language from config files, consult `skills/languages/{language}.md` for test commands
> 3. Establish baseline: run the full test suite, record pass/fail counts
> 4. Write a reproduction test that FAILS — demonstrates the bug exists
> 5. Confirm the test fails for the right reason (not a syntax error or wrong assertion)
> 6. Analyze root cause — trace from symptom to cause, don't just fix symptoms
> 7. Write fix contract to `bug-reports/{name}-contract.json`: scope of allowed changes, files to modify, constraints
> 8. Implement the minimal fix — change only what's necessary
> 9. Verify: reproduction test now PASSES, full test suite has no regressions
> 10. If stuck during analysis or fix (3+ debug cycles on the same issue), delegate to Codex:
>     - Use `Skill("codex:rescue", args: "--wait <root cause hypothesis, what you've tried, error details>")` for a second implementation pass
>     - If Codex resolves it, verify the fix passes all tests before proceeding
> 11. `Skill("codex:review", args: "--wait --scope working-tree")` is available as an in-flight tool during fix work — invoke when uncertain or when you want a second pair of eyes on a non-trivial change. Treat findings as input to your judgment, not a checklist to satisfy. The handoff condition is your own judgment that the fix is correct, complete, and minimal — not "Codex finds nothing."
> 12. Write `bug-reports/{name}-result.json` with: root cause description, fix description, files changed, tests added, baseline vs final test counts
> 13. Message the reviewer that the fix is ready
>
> Consult `skills/languages/{language}.md` for language-specific testing and debugging conventions.

**Reviewer** (1 teammate)
> You verify bug fixes independently and skeptically. When the fixer messages you:
> 1. Read the bug report and `bug-reports/{name}-result.json`
> 2. Read the fix contract at `bug-reports/{name}-contract.json`
> 3. Check: Does the fix address root cause or just symptoms?
> 4. Check: Are changes minimal and scoped to the contract?
> 5. **Re-run the full test suite yourself** — confirm all tests pass. Detect test command from `skills/languages/{language}.md`.
> 6. Read the reproduction test — does it actually test the reported bug?
> 7. Use the Agent tool with `subagent_type: base:verification-examiner` (one Agent call per question or batch of related questions, sent in parallel where possible) for the verification questions the lead provides — not SendMessage, which only addresses existing teammates
> 8. Look for regressions or side effects in modified files
> 9. If issues found from steps 1-8: message the fixer with specific feedback (files, lines, issues), wait for fixes (max 3 rounds)
> 10. **Last-mile: Codex adversarial review** — only when no issues remain from steps 1-8 (you would otherwise accept), run the adversarial as the final external check at the moment of declared completion:
>    - Run `Skill("codex:adversarial-review", args: "--wait <focus on the bug fix approach, root cause analysis, and whether the fix is minimal and correct>")` 
>    - `needs-attention` with any `critical` or `high` severity finding is blocking — send findings back to the fixer alongside any other issues (counts as a remediation round against the 3-round budget)
>    - `low`/`medium` findings: report to the fixer but do not block acceptance
>    - Do NOT auto-apply fixes — all remediation goes through the fixer
> 11. When satisfied (all checks pass and last-mile review is not blocking): message the lead with ACCEPTED verdict, verification summary, and final test counts
> 12. If not fixable after 3 rounds: message the lead with REJECTED verdict and detailed explanation

---

## Step 3: Coordinate

1. **Message the fixer** with:
   - Bug report details and affected files from exploration
   - Verification questions
   - Fix constraints (if any from user)
2. **Fixer and reviewer communicate directly** for fix/review cycles — you observe but don't relay
3. **When reviewer messages you with a verdict**:
   - **ACCEPTED**: Run the full test suite yourself as final confirmation. Update state file. Report to user.
   - **REJECTED**: Investigate the rejection. Either:
     - Provide guidance to fixer and tell reviewer to retry
     - Use AskUserQuestion to discuss with user — provide context and options
     - Mark as escalated in state file

---

## Step 4: Wrap Up

1. Update `bug-reports/{slug}-state.json` with final phase and outcome
2. Report to the user:
   - Root cause explanation
   - What was changed (files, lines)
   - Tests added (reproduction test + any others)
   - Baseline → final test counts

---

## Crash Recovery

If a bug-state.json exists for this bug:
1. Read it to determine current phase
2. Recreate the team
3. Message teammates with context about current state
4. Continue from last phase

Phase → Resume Point:
| Phase | Resume |
|-------|--------|
| INITIALIZED | Step 2 (create team, start fixer) |
| REPRODUCING | Message fixer to continue reproduction |
| FIXING | Message fixer to continue fix |
| REVIEWING | Message reviewer to continue review |
| ACCEPTED | Step 4 (wrap up) |
| ESCALATED | Report to user |
