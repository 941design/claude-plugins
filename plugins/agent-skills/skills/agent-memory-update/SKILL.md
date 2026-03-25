---
name: agent-memory-update
description: >-
  Maintenance skill that refreshes the agent memory systems knowledge base by
  fetching the latest research, framework updates, and memory pattern
  developments. Updates agent memory with new findings and timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific topic to update, e.g. 'rag' or 'vector-stores']"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: agent-memory-expert
---

## Knowledge Refresh Task

You are running a knowledge refresh for the agent memory systems knowledge base.
This is a maintenance task — do NOT answer user questions, only update your
agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Use WebFetch and WebSearch to find the latest developments in agent memory:

**Topics to check:**
- New memory frameworks or major updates (MemGPT/Letta, Mem0, Zep, Cognee)
- New vector stores or embedding models
- RAG pattern developments
- Knowledge graph approaches
- Context window management innovations
- Memory benchmarks and evaluation

### 2. Search for Recent Developments

Use WebSearch for:
- "AI agent memory architecture 2025 2026" — new patterns
- "RAG retrieval augmented generation" — latest developments
- "vector database comparison" — updated benchmarks
- "embedding model MTEB" — new models and scores
- "knowledge graph agent" — GraphRAG and temporal approaches

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Summary of what changed since last fetch
- New frameworks, models, or patterns discovered

### 4. Report

Output a concise summary of what was found.
