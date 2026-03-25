---
name: agent-memory
description: >-
  Expert knowledge on AI agent memory systems, architectures, and
  implementations. Covers episodic/semantic/procedural memory, RAG, vector
  stores, embeddings, context window management, knowledge graphs, memory
  persistence, and implementations in MemGPT/Letta, LangChain, CrewAI, Mem0,
  Zep, Cognee, and more. Use when designing, comparing, or debugging agent
  memory systems.
argument-hint: "[question about agent memory, RAG, vector stores, or persistence]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: agent-memory-expert
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Fetch the latest
research on agent memory architectures and framework updates.
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
2. For each category (architectures, RAG, frameworks, research), show a brief summary of what's available
3. Suggest example questions the user could ask

## Example Questions

- "What are the four types of agent memory and how do they map to cognitive science?"
- "Compare MemGPT/Letta vs Mem0 vs Zep for production memory"
- "What chunking strategy should I use for a RAG pipeline?"
- "Compare Qdrant vs pgvector vs ChromaDB for my use case"
- "How does GraphRAG work and when should I use it?"
- "What papers should I read about agent memory architectures?"
- "What's the best embedding model for semantic search?"
- "How should I implement memory consolidation (short-term to long-term)?"
- "How does Claude Code's file-based memory system work?"

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [memory-architectures.md](memory-architectures.md) | Episodic, semantic, procedural, working memory; cognitive science mappings |
| [rag-and-retrieval.md](rag-and-retrieval.md) | RAG variants, chunking, retrieval methods, vector stores, embeddings, evaluation |
| [design-guidance.md](design-guidance.md) | Pattern selection by use case, scale-based recommendations, anti-patterns |
| [framework-comparison.md](framework-comparison.md) | MemGPT, Mem0, Zep, Cognee, LangChain, CrewAI memory implementations |

Read the relevant documents to handle the user's request. Consult your agent
memory for additional context and prior findings.

## Important

- The knowledge base grows over time. After each invocation, the agent updates memory with new findings.
- If the agent doesn't have information in memory, it should use web search to find it and then persist the findings.
- Always ground answers in specific implementations and source code when possible.
