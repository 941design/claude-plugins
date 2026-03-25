---
name: agent-tasks-update
description: >-
  Maintenance skill that refreshes the agent task systems knowledge base by
  fetching the latest research, framework updates, and task pattern
  developments. Updates agent memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific topic to update, e.g. 'planning' or 'delegation']"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: agent-task-expert
---

## Knowledge Refresh Task

You are running a knowledge refresh for the agent task systems knowledge base.
This is a maintenance task — do NOT answer user questions, only update your
agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Use WebFetch and WebSearch to find the latest developments in agent tasks:

**Topics to check:**
- New task decomposition or planning approaches
- Framework task system updates (LangGraph, CrewAI, MetaGPT)
- Execution strategy innovations
- Delegation and multi-agent task patterns
- Guard/verification system approaches
- Task planning benchmarks

### 2. Search for Recent Developments

Use WebSearch for:
- "AI agent task planning 2025 2026" — new approaches
- "hierarchical task network LLM" — HTN updates
- "agent task decomposition" — new patterns
- "multi-agent task delegation" — coordination
- "MCTS agent planning" — tree search approaches

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Summary of what changed since last fetch
- New frameworks, patterns, or approaches discovered

### 4. Report

Output a concise summary of what was found.
