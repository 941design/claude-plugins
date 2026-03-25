---
name: implement-full
description: Orchestrates full feature implementation by invoking /feature repeatedly until all features are complete or escalated.
argument-hint: <@feature-backlog.md> OR (none - scans for pending features)
allowed-tools: Task, Read, Write, Edit, Bash, AskUserQuestion, Skill
model: sonnet
---

# Full Feature Implementation Orchestrator

**Purpose**: Execute all pending features by invoking `/feature` for each one, sequentially, until completion.

## Key Principles

1. **Strictly sequential**: Process ONE feature at a time — `/feature` creates its own team per invocation
2. **Context isolation**: Each feature runs in its own `/feature` session with its own team
3. **Progress tracking**: Maintain state in `implementation-state.json`
4. **Crash recovery**: Resume from last known state on restart

---

## Input Detection

```
IF argument provided:
    feature_source = argument (file with feature list)
ELSE:
    feature_source = scan for:
        1. specs/*.md files (feature specs not yet in epics)
        2. specs/epic-*/epic-state.json with status != "done"
        3. feature-backlog.md if exists
```

---

## State File: implementation-state.json

Create/update in project root:

```json
{
  "started_at": "timestamp",
  "updated_at": "timestamp",
  "status": "running | paused | done | error",
  "features": [
    {
      "id": "01",
      "source": "specs/user-auth.md",
      "epic_dir": "specs/epic-user-auth/",
      "status": "pending | in_progress | done | escalated | error",
      "started_at": null,
      "completed_at": null,
      "error": null
    }
  ],
  "summary": {
    "total": 5,
    "pending": 3,
    "in_progress": 1,
    "done": 1,
    "escalated": 0,
    "error": 0
  }
}
```

---

## Workflow

### Phase 1: Discovery

1. **Scan for features** based on input:
   - Find spec files not yet in epics
   - Find in-progress epics (status != "done")
   - Use backlog file order if provided

2. **Build feature list** — prioritize:
   - In-progress epics first (resume)
   - Then pending specs in order

3. **Initialize state file** if not exists

4. **Present plan to user**:
   ```
   Found {N} features to implement:

   IN PROGRESS:
     1. specs/epic-user-auth/ (story 2/5)

   PENDING:
     2. specs/payment-integration.md
     3. specs/notifications.md

   Proceed with implementation? [Y/n]
   ```

### Phase 2: Execution Loop

**CRITICAL: ONE FEATURE AT A TIME**

```
WHILE features remain with status in [pending, in_progress]:

    1. SELECT next feature:
       - First: any with status="in_progress" (resume)
       - Then: first with status="pending"

    2. UPDATE state:
       - Set feature status="in_progress", started_at=now
       - Write implementation-state.json

    3. INVOKE /feature:
       - For new specs: /feature @{spec_file}
       - For in-progress epics: /feature {epic_dir}
       - /feature creates its own agent team internally
       - Wait for /feature to complete

    4. CAPTURE result:
       - Read epic-state.json for the feature's epic directory
       - Extract: status (done/escalated), completed stories, test counts

    5. UPDATE state:
       - Set feature status based on epic-state.json
       - Set completed_at=now (if done or escalated)
       - Update summary counts
       - Write implementation-state.json

    6. LOG progress:
       Feature {id}: {status}
         Epic: {epic_dir}
         Stories: {completed} done, {escalated} escalated
       Overall: {done}/{total} complete

    7. CONTINUE to next feature

END WHILE
```

### Phase 3: Completion

1. **Generate summary**:
   ```
   ===============================================
   IMPLEMENTATION COMPLETE
   ===============================================

   Total features: {N}
   Completed:      {done}
   Escalated:      {escalated}
   Errors:         {error}

   COMPLETED FEATURES:
     - specs/epic-user-auth/
     - specs/epic-payment-integration/

   ESCALATED (require human intervention):
     - specs/epic-notifications/ - {reason}

   ERRORS:
     (none)
   ===============================================
   ```

2. **Update state file**: status="done", completed_at=now

---

## Error Handling

### Feature Failure
If `/feature` fails or escalates:
1. Mark feature as `escalated` or `error` with details
2. Log the issue
3. Continue to next feature (don't block others)

### Crash Recovery
On restart:
1. Read `implementation-state.json`
2. Find feature with status="in_progress"
3. Check epic-state.json for actual status
4. Resume or restart that feature
5. Continue loop

---

## Success Criteria

Implementation is complete when:
- [ ] All features have status in [done, escalated, error]
- [ ] No features remain pending or in_progress
- [ ] `implementation-state.json` has status="done"
- [ ] Summary presented to user
