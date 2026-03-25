---
name: agent-loops
description: >-
  Expert knowledge on AI agent loop architectures, control flow patterns, and
  framework comparisons. Covers ReAct, Plan-Execute, ReWOO, Tree-of-Thoughts,
  multi-agent patterns, cognitive architectures, and implementations in Claude
  Code, LangGraph, CrewAI, AutoGen, and more. Use when designing, comparing, or
  debugging agent loops.
argument-hint: "[question about agent loops, patterns, or frameworks]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: agent-loop-expert
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Fetch the latest
research on agent loop patterns and framework updates.
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
2. For each category (patterns, frameworks, research), show a brief summary of what's available
3. Suggest example questions the user could ask

## Example Questions

- "What is the ReAct pattern and how do popular frameworks implement it?"
- "Compare Plan-and-Execute vs ReAct for a multi-file refactoring task"
- "Which agent loop pattern should I use for a research task?"
- "What papers should I read about agent architectures?"
- "Compare CrewAI vs AutoGen for multi-agent orchestration"
- "What's the difference between vertical and horizontal multi-agent patterns?"
- "How do cognitive architectures (BDI, SOAR) relate to modern agent loops?"
- "What are the guard-based termination strategies for agent loops?"

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [loop-patterns.md](loop-patterns.md) | ReAct, Plan-Execute, ReWOO, ToT, multi-agent, cognitive architectures |
| [design-guidance.md](design-guidance.md) | Pattern selection decision trees, trade-offs, anti-patterns |
| [framework-comparison.md](framework-comparison.md) | 25+ framework loop implementations compared |

Read the relevant documents to handle the user's request. Consult your agent
memory for additional context and prior findings.

## Important

- The knowledge base grows over time. After each invocation, the agent updates memory with new findings.
- If the agent doesn't have information in memory, it should use web search to find it and then persist the findings.
- Always ground answers in specific implementations and source code when possible.
