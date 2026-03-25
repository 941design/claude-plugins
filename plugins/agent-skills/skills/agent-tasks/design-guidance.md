# Task System Design Guidance

## Decomposition Decision Tree

```
Is the task domain well-defined and recurring?
├── Yes → HTN (formal decomposition with reusable methods)
└── No → Is the task a single-step operation?
    ├── Yes → Direct execution (no decomposition needed)
    └── No → Is the task complex enough for tree search?
        ├── Yes → LATS/MCTS (3-5x cost but higher success rate)
        └── No → LLM plan-and-execute (good default)
```

## Execution Strategy Decision Tree

```
Are subtasks independent?
├── Yes → Parallel execution (fan-out/fan-in)
└── No → Is ordering strict?
    ├── Yes → Sequential execution
    └── No → Pipeline (streaming where possible)

Is the task long-running (>5 min)?
├── Yes → Checkpoint-resume (persist state at milestones)
└── No → Simple execution (crash = retry from start)

Is success uncertain (first attempt often fails)?
├── Yes → Iterative with reflection (Reflexion pattern)
│   └── High stakes? → MCTS/LATS (systematic exploration)
└── No → Single attempt (with retry on transient failure)
```

## Verification Strategy

```
Can success be checked programmatically?
├── Yes → Programmatic guard (test passes, file exists, API returns 200)
└── No → Is the output objectively evaluable?
    ├── Yes → LLM guard (guard-evaluated done condition)
    └── No → Human-in-the-loop review
```

## Anti-Patterns

### 1. Infinite Task Generation
BabyAGI-style agents that generate more tasks than they complete.
**Fix**: Cap task list size, require tasks to map back to original goal.

### 2. Plan Rigidity
Executing a detailed plan rigidly even when execution reveals problems.
**Fix**: Replan after each step or after failures. Use adaptive replanning.

### 3. No Verification
Executing tasks without checking if they actually succeeded.
**Fix**: Guard conditions, test-driven verification, programmatic checks.

### 4. Over-Decomposition
Breaking simple tasks into too many subtasks.
**Fix**: Start with direct execution. Only decompose when direct attempt fails.

### 5. Unbounded Iteration
Retrying failed tasks indefinitely.
**Fix**: Max attempts, max guard iterations, token budget, time budget. Reasonable defaults: 1 attempt, 3 guard iterations, 300s timeout.

### 6. Ignoring Dependencies
Executing tasks in parallel when they have implicit dependencies.
**Fix**: Explicit dependency graph. Topological sort for execution order.

## Cost-Quality Tradeoffs

| Approach | LLM Calls | Quality | Latency | Cost |
|---|---|---|---|---|
| Direct execution | 1 | Baseline | Low | Low |
| Plan-and-execute | 2-5 | +20% | Medium | Medium |
| Plan + reflection | 3-8 | +30% | Medium-High | Medium-High |
| MCTS/LATS | 5-20 | +40% | High | High |
| Multi-agent | 5-30 | +30-50% | High | High |

### Budget Recommendations
- **Token-constrained**: Direct execution or single-pass plan-and-execute
- **Quality-focused**: Reflexion (retry with self-feedback) — best quality/cost ratio
- **Mission-critical**: LATS or multi-agent with verification — highest quality, highest cost

## Production Coding Agent Task Patterns (2025-2026)

### Issue → PR Pipeline (GitHub Copilot Agent)
```
GitHub Issue assigned → Agent explores repo → Plans implementation
    → Writes code + tests → Runs CI → Opens draft PR
    → Pushes to copilot/* branch → Human reviews → Merge
```
Constraints: write access required, branch protection enforced, CI requires human approval.

### Parallel Worktree Tasks (OpenAI Codex)
Multiple agents work the same repository simultaneously, each in an isolated Git worktree. Tasks stay independent — no merge conflicts during execution. "Completing weeks of work in days."

### Async Background Tasks (Google Jules, Devin)
User assigns task via chat/Slack → Agent works in background VM → Returns diff + reasoning when done. Multiple tasks can run concurrently. User reviews results asynchronously.

### Sub-Agent Pipeline (Devika)
```
User prompt → Planner agent (step-by-step plan)
    → Researcher agent (web search, keyword extraction)
    → Formatter agent (clean extracted information)
    → Coder agent (generate code from plan + research)
```
Each sub-agent is a specialized Python class with its own Jinja2 prompt template.

### Multi-Repo Deterministic Tasks (Moderne/Moddy)
LLM interprets intent → selects deterministic OpenRewrite recipes → applies across thousands of repositories. Lossless Semantic Trees ensure correctness at scale. Handles billions of lines of code simultaneously.

## General Guidance

- Use guard-evaluated done conditions for any task where success isn't trivially verifiable
- Set max guard iterations to 3 — beyond 3, the task likely needs a different approach
- Use cron/scheduling for recurring tasks rather than re-creating each time
- For tasks that modify code: include "tests pass" in done condition
- Start with direct execution; add decomposition only when needed
