---
name: agent-loops-update
description: >-
  Maintenance skill that refreshes the agent loop knowledge base by fetching
  the latest research, framework updates, and loop pattern developments.
  Updates agent memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific topic to update, e.g. 'react' or 'frameworks']"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: agent-loop-expert
---

## Knowledge Refresh Task

You are running a knowledge refresh for the agent loop knowledge base.
This is a maintenance task — do NOT answer user questions, only update your
agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Use WebFetch and WebSearch to find the latest developments in agent loops:

**Topics to check:**
- New loop patterns or variants (ReAct, Plan-Execute, etc.)
- Framework loop implementation changes
- New cognitive architecture research
- Termination and guard strategies
- Multi-agent orchestration patterns

### 2. Search for Recent Developments

Use WebSearch for:
- "AI agent loop architecture 2025 2026" — new patterns
- "react agent pattern" — updates and variants
- "agent framework comparison" — loop implementations
- "cognitive architecture AI agent" — academic research
- "multi-agent orchestration" — coordination patterns

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Summary of what changed since last fetch
- New patterns or frameworks discovered

### 4. Report

Output a concise summary of what was found.
