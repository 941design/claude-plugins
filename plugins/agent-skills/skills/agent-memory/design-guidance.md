# Memory System Design Guidance

## Pattern Selection by Use Case

### Simple agent, single user, local
- **Storage**: SQLite with hybrid search
- **Embedding**: text-embedding-3-small or BGE-M3
- **Retrieval**: Hybrid (vector 0.7 + keyword 0.3)
- **Persistence**: File-based backup
- **Why**: Low complexity, good performance, no external dependencies

### Production agent, cross-session personalization
- **Framework**: Mem0 or custom hybrid
- **Storage**: Postgres + vector index
- **Memory types**: Episodic (conversation logs) + semantic (extracted facts)
- **Consolidation**: Periodic extraction from episodic → semantic
- **Why**: Proven accuracy improvements, compliance-ready

### Enterprise agent, relationship-heavy domain
- **Framework**: Zep (temporal KG) or Neo4j + GraphRAG
- **Storage**: Knowledge graph + vector index
- **Retrieval**: Graph traversal + semantic similarity
- **Why**: Temporal reasoning, entity relationships, structured queries

### Research/prototyping
- **Storage**: ChromaDB (embedded, simple API)
- **Embedding**: BGE-M3 (free, multi-retrieval)
- **Why**: Fast iteration, no infra overhead

## Scale-Based Recommendations

| Scale | Vector Store | Embedding | Index | Notes |
|---|---|---|---|---|
| <10K entries | SQLite + FAISS | text-embedding-3-small | FLAT | Simple, exact search |
| 10K-1M | SQLite + hybrid | text-embedding-3-small | HNSW | Good default zone |
| 1M-10M | Qdrant or pgvector | BGE-M3 or text-embedding-3-large | HNSW | Purpose-built |
| 10M-100M | Qdrant or Milvus | BGE-M3 | HNSW or IVF-PQ | Distributed recommended |
| 100M+ | Milvus distributed | Domain-specific | IVF-PQ | Requires cluster ops |

## Cost-Quality Tradeoffs

### Low budget
- Free embeddings (BGE-M3, Nomic)
- SQLite or ChromaDB (no server costs)
- Keyword-only retrieval as fallback

### Medium budget
- OpenAI text-embedding-3-small ($0.02/M tokens)
- Hybrid search (vector + BM25)
- Self-hosted Qdrant

### High budget
- Cohere embed-v4 or text-embedding-3-large
- Reranking pass (Cohere Rerank)
- Managed vector DB (Pinecone, Weaviate Cloud)
- Graph RAG for global reasoning

## Context Engineering Patterns from Coding Agents (2025-2026)

### Repo Map (Aider)
Tree-sitter parsing + PageRank algorithm to build a ranked map of the most relevant code in a repository. Fits entire repo context into token budget by prioritizing high-connectivity code. AST-aware — understands function/class boundaries, not just text.

### Isolated Container Context (OpenAI Codex)
Each task runs in an isolated container pre-loaded with the full repository. Internet disabled during execution — agent can only work with provided code and pre-installed dependencies. Eliminates context management complexity by giving each task its own complete copy.

### Full-Stack VM Context (Google Jules)
Clone entire codebase into a dedicated Google Cloud VM. Agent has full-stack access: install tools, run build systems, execute tests. Full project understanding across all files, dependencies, and history.

### Persistent Cross-Channel Memory (OpenClaw)
Persistent background process maintains memory across 20+ chat channels (Slack, Discord, Telegram, etc.). Single agent keeps context across platforms — same conversation can span WhatsApp and Slack. Memory persists across restarts; no browser dependency.

### LSP Integration (OpenCode)
Language Server Protocol integration provides code intelligence (go-to-definition, find-references, diagnostics) as memory/context for the agent. Richer than text search — understands type relationships and code navigation.

## Anti-Patterns

1. **Store everything, retrieve nothing useful**: Without relevance filtering, more memories = more noise. Use min_relevance_score thresholds.

2. **Flat memory dump**: Raw conversation transcripts without extraction. Grows unboundedly, retrieval quality degrades.

3. **No forgetting**: Indiscriminate storage degrades performance by up to 10%. Implement decay or pruning.

4. **Single retrieval method**: Dense-only misses keywords; sparse-only misses semantics. Use hybrid.

5. **Ignoring the write path**: Slow write-time processing is fine; slow read-time processing kills UX.

6. **Over-engineering early**: Start with simple (SQLite + hybrid), scale only when metrics justify.
