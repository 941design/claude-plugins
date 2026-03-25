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

## Sources
- MemGPT: arxiv:2310.08560
- Mem0: mem0.ai
- Zep: getzep.com
- Cognee: cognee.ai
