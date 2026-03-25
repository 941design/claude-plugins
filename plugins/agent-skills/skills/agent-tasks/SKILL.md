---
name: agent-tasks
description: >-
  Expert knowledge on AI agent task systems — decomposition, planning,
  scheduling, execution, state management, guard conditions, and delegation.
  Covers HTN, plan-and-execute, MCTS planning, BabyAGI, LangGraph, CrewAI,
  MetaGPT, guard-evaluated tasks, and more. Use when designing, comparing, or
  debugging agent task systems.
argument-hint: "[question about agent tasks, planning, decomposition, or execution]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: agent-task-expert
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Fetch the latest
research on agent task systems and framework updates.
Write all findings to your **agent memory only** — never modify plugin files.

If memory is fresh, proceed directly to answering the question.

## User Request

$ARGUMENTS

## Modes

### Default (with arguments)

Answer the question using your knowledge base:

1. Load your memory (MEMORY.md and referenced knowledge files)
2. Answer using stored knowledge + reasoning
3. Update memory if you learned something new (from web search or analysis)

### No arguments

Show the knowledge base summary:

1. Read your MEMORY.md
2. For each category (decomposition, planning, execution, frameworks), show a brief summary of what's available
3. Suggest example questions the user could ask

## Example Questions

- "What is Hierarchical Task Network planning and how do LLMs augment it?"
- "Compare sequential vs parallel vs speculative task execution strategies"
- "What's the best approach for task dependency resolution in an agent?"
- "Compare BabyAGI vs MetaGPT vs CrewAI for task-driven agents"
- "How should I implement checkpoint-and-resume for long-running tasks?"
- "What papers cover LLM-based task planning?"
- "When should I use MCTS vs greedy planning for agent tasks?"
- "How do multi-agent systems delegate and aggregate task results?"
- "How should I implement guard-evaluated done conditions?"

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [task-patterns.md](task-patterns.md) | Decomposition (HTN, recursive, DAG), planning (classical, LLM, MCTS), execution strategies |
| [design-guidance.md](design-guidance.md) | Decision trees, verification strategies, anti-patterns, cost-quality tradeoffs |
| [framework-comparison.md](framework-comparison.md) | BabyAGI, LangGraph, CrewAI, MetaGPT, SWE-agent task implementations |

Read the relevant documents to handle the user's request. Consult your agent
memory for additional context and prior findings.

## Important

- The knowledge base grows over time. After each invocation, the agent updates memory with new findings.
- If the agent doesn't have information in memory, it should use web search to find it and then persist the findings.
- Always ground answers in specific implementations and source code when possible.
