---
name: agent-design-update
description: >-
  Maintenance skill that refreshes the agent design knowledge base by fetching
  the latest research, framework updates, and benchmark results. Updates agent
  memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific topic to update, e.g. 'safety' or 'frameworks']"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: agent-design-expert
---

## Knowledge Refresh Task

You are running a knowledge refresh for the agent design knowledge base.
This is a maintenance task — do NOT answer user questions, only update your
agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Use WebFetch and WebSearch to find the latest developments in agent design:

**Topics to check:**
- New agent frameworks or major version releases
- New architecture patterns or design approaches
- Updated benchmark results (SWE-bench, GAIA, AgentBench)
- New safety tools, guardrails, or sandboxing approaches
- New observability platforms or tracing tools
- MCP and A2A protocol updates
- Anthropic, OpenAI, Google agent research publications

### 2. Search for Recent Developments

Use WebSearch for:
- "AI agent architecture 2025 2026" — new patterns
- "agent framework comparison" — updated reviews
- "LLM agent safety guardrails" — new safety tools
- "agent evaluation benchmark" — new benchmarks
- "MCP model context protocol" — protocol updates

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Summary of what changed since last fetch
- New frameworks, patterns, or tools discovered

**Topic files** — update or create as needed:
- Pattern files for new architecture patterns
- Framework comparison updates
- New benchmark results
- Safety and evaluation updates

### 4. Report

Output a concise summary of what was found:
- Key changes since last refresh
- New frameworks or patterns
- Updated benchmark results
- Any corrections to the shipped supporting documents
- Issues encountered (404s, missing data, etc.)
