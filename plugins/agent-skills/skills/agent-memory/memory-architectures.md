# Agent Memory Architectures

## The Four Memory Types

### Episodic Memory
**What**: Records of specific past experiences and events.
**Cognitive Science**: Tulving's episodic memory — "what happened, when, where"
**AI Implementation**: Conversation logs, interaction histories, event records
**Example**: "Last session, the user asked about RAG patterns and preferred hybrid search"

### Semantic Memory
**What**: General knowledge and facts, decoupled from when they were learned.
**Cognitive Science**: Tulving's semantic memory — world knowledge
**AI Implementation**: Extracted facts, user preferences, domain knowledge
**Example**: "The user prefers Python over JavaScript for backend work"

### Procedural Memory
**What**: Learned skills and routines — "how to do things."
**Cognitive Science**: Implicit memory — motor skills, habits
**AI Implementation**: Tool usage patterns, prompt templates, workflow routines
**Example**: "To deploy this project, run make build && make deploy"

### Working Memory
**What**: The current context — what the agent is actively reasoning about.
**Cognitive Science**: Baddeley's model — central executive + subsystems
**AI Implementation**: The context window itself — recent conversation + relevant retrieved context
**Key Insight**: The LLM context window IS working memory. Its finite size is the fundamental constraint.

### Causal/Evolution Memory
**What**: Records of what strategies were tried, why, and whether they worked — enabling self-improvement.
**Cognitive Science**: Metacognition — "thinking about thinking," self-monitoring and self-regulation
**AI Implementation**: Causal chains (Signal → Hypothesis → Attempt), anti-pattern bans, epigenetic marks
**Example**: "Error signal X triggered repair gene Y, which produced capsule Z with 85% confidence — logged as successful evolution event"
**Notable Implementation**: Evolver (github.com/EvoMap/evolver) — mandatory causal memory chain where every evolution cycle must record its reasoning or be halted. Failed strategies are auto-banned.

## Cognitive Science Mappings

### Atkinson-Shiffrin Model (1968)
```
Sensory Input → Short-term Memory → Long-term Memory
                    (working memory)    ↓
                                    Episodic
                                    Semantic
                                    Procedural
```

### CoALA Formalization (2023)
Agent memory modeled as: M = (working_memory, long_term_memory)
- Working memory = context window contents
- Long-term memory = external storage (vector DB, files, knowledge graph)

## Memory Lifecycle

### Write Path
```
New Information → Importance Scoring → Storage Decision → Write to Store
                       ↓
              Below threshold? → Discard
```

### Read Path (Retrieval)
```
Query → Embedding → Similarity Search → Reranking → Context Injection
                  + Keyword Search (hybrid)
```

### Consolidation (Short-term → Long-term)
```
Episodic memories → Periodic extraction → Semantic facts
                  → Summarization       → Compressed episodes
                  → Decay/deletion      → Forgotten
```

## Importance Scoring Approaches

| System | Method | Signal |
|---|---|---|
| **Generative Agents** | LLM rates 1-10 importance | Novelty, emotional salience |
| **CrewAI** | Agent assigns during storage | Task relevance |
| **Mem0** | Hybrid scoring | Recency + relevance + frequency |
| **A-MAC** | Multi-agent consensus | Agreement among agents |

## Memory Value: What to Store

### High Value
- User corrections and preferences
- Task-specific insights not derivable from code
- External knowledge discovered via search
- Patterns that differ from defaults

### Low Value / Noise
- Raw conversation transcripts (store summaries instead)
- Information derivable from the codebase (file paths, function names)
- Ephemeral state (current task progress)
- Duplicate information

## Sources
- Park et al., "Generative Agents" (2023): arxiv:2304.03442
- Packer et al., "MemGPT" (2023): arxiv:2310.08560
- Sumers et al., "CoALA" (2024): arxiv:2309.02427
