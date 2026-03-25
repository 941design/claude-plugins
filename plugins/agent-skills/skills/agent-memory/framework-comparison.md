# Memory Framework Comparison

## MemGPT / Letta
**Architecture**: LLM-as-OS paradigm with virtual context management.
- 3-tier memory: core (always loaded), recall (searchable history), archival (long-term vector store)
- Autonomous write-back cycles — LLM decides when to read/write to memory
- First framework to treat memory management as a first-class agent concern
- 21k+ GitHub stars

**Key Innovation**: The LLM itself manages memory via tool calls (memory_insert, memory_search, etc.)

## Mem0
**Architecture**: Hybrid vector + graph memory layer.
- 26% accuracy improvement reported vs no memory
- Combines vector similarity with knowledge graph relationships
- Simple API: add memories, search memories
- Good for cross-session personalization

## Zep
**Architecture**: Temporal knowledge graph.
- 94.8% accuracy on DMR benchmark
- Graphiti: temporal knowledge graph engine
- Tracks entity relationships over time
- Best for relationship-heavy domains

## Cognee
**Architecture**: 6-stage knowledge pipeline.
- Ingestion → Chunking → Enrichment → Entity Extraction → Graph Construction → Querying
- $7.5M seed funding
- Knowledge engine approach (beyond simple memory)

## LangChain / LangGraph
**Architecture**: Checkpointing + memory types.
- ConversationBufferMemory, ConversationSummaryMemory (deprecated legacy)
- LangGraph: checkpointing for state persistence, time-travel debugging
- Cross-thread memory for multi-conversation sharing

## CrewAI
**Architecture**: Unified Memory class.
- Short-term (conversation context) + long-term (persistent) + entity (relationship tracking)
- Automatic memory extraction during crew execution
- Memory accessible across all agents in a crew

## AutoGen
**Architecture**: Teachability pattern.
- Agents learn from interactions via explicit "teach" mechanism
- Store key-value pairs for future reference
- Less sophisticated than dedicated memory frameworks

## Claude Code
**Architecture**: File-based memory.
- MEMORY.md index file (first 200 lines loaded at session start)
- Topic files loaded on demand
- Three scopes: user (~/.claude/), project (.claude/), local (.claude-local/)
- No vector search — relies on file organization and agent judgment

## Comparison Table

| Framework | Memory Types | Persistence | Retrieval | Distinguishing Feature |
|---|---|---|---|---|
| **MemGPT/Letta** | Core/Recall/Archival | Vector DB | LLM-managed | Virtual context management |
| **Mem0** | Hybrid | Vector + Graph | Similarity + graph | Cross-session personalization |
| **Zep** | Temporal KG | Knowledge graph | Graph traversal | Temporal relationship tracking |
| **Cognee** | Knowledge pipeline | Multi-store | Pipeline query | 6-stage enrichment pipeline |
| **LangGraph** | Checkpoints | Configurable | Key-based | Time-travel debugging |
| **CrewAI** | Short/Long/Entity | Built-in | Unified search | Multi-agent shared memory |
| **AutoGen** | Teachable | Key-value | Lookup | Explicit teaching interface |
| **Claude Code** | File-based | Filesystem | Agent reads files | Simplest, no dependencies |

## Decision Guide

| Need | Best Fit | Why |
|---|---|---|
| Simplest possible | Claude Code (file-based) | No dependencies, works everywhere |
| Cross-session personalization | Mem0 | Proven accuracy gains, simple API |
| Relationship-heavy domain | Zep | Temporal KG, entity tracking |
| Virtual context management | MemGPT/Letta | LLM manages its own memory |
| Enterprise knowledge pipeline | Cognee | Rich enrichment, structured output |
| Within existing LangChain/Graph | LangGraph checkpointing | Native integration |
| Multi-agent shared memory | CrewAI | Built-in crew memory |
| Agent self-improvement | Evolver | Causal memory for autonomous evolution |
| Semantic search over markdown | Memsearch | Adds vectors to file-based memory |

## Evolver (EvoMap)
**Architecture**: Meta-learning evolution engine — consumes memory signals, produces improvement directives.
- NOT a traditional memory system — orthogonal/complementary to memory frameworks above
- Brain/Hand separation: Brain analyzes signals and selects strategies, Hand executes changes
- Genome Evolution Protocol (GEP): genes (repair templates), capsules (validated fixes), mutations (encoded intent)
- Mandatory causal memory chain: Signal → Hypothesis → Attempt (every cycle recorded or halted)
- Anti-pattern memory: auto-bans gene/capsule combos with >60% signal overlap and 2+ failures
- Epigenetic marks: platform/architecture-specific performance boosts stored as context-dependent memory weights
- Population genetics drift: `intensity = 1/sqrt(Ne)` for exploration vs exploitation
- PRM-inspired 8-dimension solidification gate before committing changes
- A2A protocol for network-scale evolution sharing (one agent learns, others inherit)
- Node.js, MIT license, ~v1.39 (March 2026), very active

**Key Innovation**: Uses memory as input (logs, errors, session transcripts) to autonomously evolve agent prompts/strategies — a form of procedural memory specialized for self-improvement.

**When to use**: When you need agents that systematically improve their own behavior over time without retraining. Complementary to any memory framework above.

- GitHub: github.com/EvoMap/evolver, npm: @evomap/evolver

## Memsearch (Semantic Memory Search for File-Based Systems)
**Architecture**: Vector-powered search layer over markdown memory files.
- Documented in awesome-openclaw-usecases (27k+ stars community reference)
- Hybrid search: dense vectors + BM25 over existing markdown memory files
- SHA-256 deduplication, live file watching for auto-indexing
- Multiple embedding providers: OpenAI, Google, Voyage, Ollama
- Treats vector index as a "derived cache" — can be rebuilt from authoritative markdown files
- Adds semantic retrieval to file-based memory without replacing it

**Key Innovation**: Bridges the gap between simple file-based memory (Claude Code's approach) and full vector store systems. The markdown files remain the source of truth.

**When to use**: When file-based memory grows beyond what agent judgment alone can navigate, but you don't want to migrate to a full vector DB.

## Updated Comparison Table

| Framework | Memory Types | Persistence | Retrieval | Distinguishing Feature |
|---|---|---|---|---|
| **MemGPT/Letta** | Core/Recall/Archival | Vector DB | LLM-managed | Virtual context management |
| **Mem0** | Hybrid | Vector + Graph | Similarity + graph | Cross-session personalization |
| **Zep** | Temporal KG | Knowledge graph | Graph traversal | Temporal relationship tracking |
| **Cognee** | Knowledge pipeline | Multi-store | Pipeline query | 6-stage enrichment pipeline |
| **LangGraph** | Checkpoints | Configurable | Key-based | Time-travel debugging |
| **CrewAI** | Short/Long/Entity | Built-in | Unified search | Multi-agent shared memory |
| **AutoGen** | Teachable | Key-value | Lookup | Explicit teaching interface |
| **Claude Code** | File-based | Filesystem | Agent reads files | Simplest, no dependencies |
| **Evolver** | Causal graph + signals | JSONL + filesystem | Signal extraction | Autonomous self-improvement |
| **Memsearch** | File-based + vectors | Markdown + vector index | Hybrid (dense+BM25) | Semantic search over markdown |

## Sources
- MemGPT: arxiv:2310.08560
- Mem0: mem0.ai
- Zep: getzep.com
- Cognee: cognee.ai
- Evolver: github.com/EvoMap/evolver
- awesome-openclaw-usecases: github.com/hesamsheikh/awesome-openclaw-usecases
