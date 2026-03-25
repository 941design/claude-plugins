---
name: agent-design
description: >-
  Expert knowledge on AI agent design patterns — architecture, multi-agent
  coordination, tool use, prompt engineering, evaluation, safety, observability,
  and deployment. Covers router, supervisor, blackboard patterns, MCP, agent
  evaluation benchmarks, guardrails, observability platforms, and
  implementations across Claude Code, LangGraph, CrewAI, AutoGen, Semantic
  Kernel, and more. Use when designing, evaluating, or architecting agent
  systems.
argument-hint: "[question about agent design, architecture, safety, or evaluation]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: agent-design-expert
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Fetch the latest
research on agent design patterns, framework updates, and new benchmarks.
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
2. For each category (architecture, safety, evaluation, frameworks), show a brief summary of what's available
3. Suggest example questions the user could ask

## Example Questions

- "When should I use a router pattern vs supervisor pattern for my agent?"
- "Compare MCP vs A2A for inter-agent communication"
- "How should I implement human-in-the-loop approval gates?"
- "What benchmarks should I use to evaluate my agent? (SWE-bench, GAIA, etc.)"
- "Compare LangSmith vs Langfuse vs Arize Phoenix for agent observability"
- "What are the key anti-patterns in agent design?"
- "How should I implement provider failover and model routing?"
- "What's the best approach for agent cost optimization?"
- "Compare CrewAI vs AutoGen vs LangGraph for multi-agent orchestration"

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [design-guidance.md](design-guidance.md) | Architecture decision trees, anti-patterns, cost-quality tradeoffs |
| [architecture-patterns.md](architecture-patterns.md) | Router, supervisor, pipeline, blackboard, evaluator-optimizer patterns |
| [prompt-engineering.md](prompt-engineering.md) | System prompt design, position effects, context engineering |
| [safety-and-evaluation.md](safety-and-evaluation.md) | Sandboxing, guardrails, HITL, benchmarks, observability |
| [framework-comparison.md](framework-comparison.md) | 13+ framework comparison table and design philosophy analysis |

Read the relevant documents to handle the user's request. Consult your agent
memory for additional context and prior findings.

## Important

- The knowledge base grows over time. After each invocation, the agent updates memory with new findings.
- If the agent doesn't have information in memory, it should use web search to find it and then persist the findings.
- Always ground answers in specific implementations and source code when possible.
