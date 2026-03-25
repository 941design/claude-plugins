# RAG, Retrieval, Vector Stores, and Embeddings

## RAG Architecture Variants

### Naive RAG
Query → Retrieve top-k chunks → Stuff into prompt → Generate answer.
- Simplest, fastest to implement
- Fails on complex multi-hop queries, global/thematic questions

### Advanced RAG
Adds pre-retrieval (query rewriting, HyDE), retrieval (hybrid search, reranking), post-retrieval (compression).
- Better accuracy through query optimization and result refinement

### Modular RAG
Separates pipeline into swappable modules: retriever, reranker, generator, router.
- Maximum flexibility, can swap components independently

### Agentic RAG
LLM acts as reasoning engine that decides its own search strategy, reformulates queries, iterates.
- Self-correcting, handles complex queries; higher latency and cost

### Graph RAG (Microsoft, 2024)
Constructs entity-relation knowledge graphs, uses Leiden community detection, generates community summaries.
- Uniquely capable for global/thematic questions
- High indexing cost (LLM call per chunk for entity extraction)

### RAG Pipeline Decision Tree
```
Is this a global/thematic question?
├── Yes → Graph RAG (expensive but uniquely capable)
└── No → Is this a simple factual lookup?
    ├── Yes → Naive RAG (fast, cheap)
    └── No → Is the query ambiguous or multi-hop?
        ├── Yes → Agentic RAG (self-correcting, iterative)
        └── No → Advanced RAG (query rewriting + reranking)
```

---

## Chunking Strategies

| Strategy | How It Works | Best For | Cost |
|---|---|---|---|
| **Fixed-size** | Split at N tokens with overlap | Baseline, fast | Low |
| **Recursive** | Split on paragraphs → sentences → chars | General purpose (start here) | Low |
| **Semantic** | Group sentences by embedding similarity | High-precision needs | Medium |
| **Document-aware** | Split on document structure (headings, tables) | Structured documents | Medium |
| **Cluster-based** | Cluster embeddings, group similar content | Cross-document dedup | High |

**Best practice**: Start with recursive at 400-512 tokens with 10-20% overlap.
**Context rot**: Response quality drops at ~2,500 tokens per chunk (Chroma research).

### Chunking Decision Tree
```
Is content structured (code, markdown, tables)?
├── Yes → Document-aware chunking (respect structure boundaries)
└── No → Is precision critical?
    ├── Yes → Semantic chunking
    └── No → Recursive chunking at 400-512 tokens with 10-20% overlap
```

---

## Retrieval Methods

### Dense Retrieval
Embed query and documents, find nearest neighbors via cosine similarity.
- Good for semantic matching; misses exact keywords

### Sparse Retrieval (BM25)
Traditional keyword matching with TF-IDF scoring.
- Good for exact keywords; misses semantic equivalence

### Hybrid Retrieval
Weighted combination of dense + sparse scores.
- Best of both worlds: `final_score = 0.7 * cosine_sim + 0.3 * bm25`
- Most production systems use hybrid

### Reranking
After initial retrieval, cross-encoder model reranks results.
- Significantly improves top-k precision; adds latency
- Models: Cohere Rerank, BGE Reranker, ColBERT

---

## Vector Stores

| Store | Type | Best For | Key Feature |
|---|---|---|---|
| **Qdrant** | Purpose-built | Production workloads | Best performance at scale |
| **Milvus** | Purpose-built | Massive scale (100M+) | Distributed, GPU-accelerated |
| **Weaviate** | Purpose-built | Hybrid search | Native BM25 + vector |
| **ChromaDB** | Embedded | Prototyping | Simplest API, in-process |
| **Pinecone** | Managed | Zero-ops | Fully managed cloud |
| **pgvector** | Extension | Existing Postgres | No new infra needed |
| **FAISS** | Library | Research/embedded | Facebook, exact search |

### Indexing Algorithms
- **HNSW**: Best recall-speed tradeoff for most use cases
- **IVF-PQ**: Better for very large datasets (100M+), lower memory
- **FLAT**: Exact search, best for small datasets (<10K)

---

## Embedding Models

| Model | Dimensions | MTEB Score | Cost | Notes |
|---|---|---|---|---|
| **OpenAI text-embedding-3-small** | 1536 | Good | $0.02/M tokens | Default recommendation |
| **OpenAI text-embedding-3-large** | 3072 | Better | $0.13/M tokens | Higher quality |
| **Cohere embed-v4** | 1024 | Excellent | $0.12/M tokens | Multimodal |
| **BGE-M3** | 1024 | Good | Free | Open-source, multi-retrieval |
| **Nomic embed** | 768 | Good | Free | Open-source |
| **Voyage** | Various | Excellent | $0.02-0.12/M | Domain-specific variants |

---

## RAGAS Evaluation Metrics

| Metric | What It Measures | Target |
|---|---|---|
| **Faithfulness** | All claims supported by retrieved context? | >0.8 |
| **Answer Relevance** | Does the answer address the question? | >0.8 |
| **Context Precision** | Relevant chunks ranked higher? | >0.8 |
| **Context Recall** | All necessary information retrieved? | >0.8 |

## Sources
- Engineering the RAG Stack (arxiv, Jan 2026)
- Microsoft GraphRAG: microsoft.github.io/graphrag/
- RAGAS: docs.ragas.io
- Chroma research on context rot (July 2025)
