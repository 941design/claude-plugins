# agent-skills

AI agent design expertise plugin for Claude Code. Four specialist agents with persistent knowledge bases covering agent architecture, loop patterns, memory systems, and task systems.

## Skills

| Skill | Description |
|---|---|
| `/agent-design` | Architecture patterns, multi-agent coordination, safety, evaluation, deployment |
| `/agent-loops` | Loop architectures (ReAct, Plan-Execute, ReWOO, ToT), framework comparisons |
| `/agent-memory` | Memory systems, RAG, vector stores, embeddings, knowledge graphs |
| `/agent-tasks` | Task decomposition, planning, execution strategies, delegation |

### Update Skills

| Skill | Description |
|---|---|
| `/agent-design-update` | Refresh agent design knowledge base from latest research |
| `/agent-loops-update` | Refresh agent loop knowledge base from latest research |
| `/agent-memory-update` | Refresh agent memory knowledge base from latest research |
| `/agent-tasks-update` | Refresh agent task knowledge base from latest research |

## Agents

| Agent | Model | Description |
|---|---|---|
| `agent-design-expert` | Opus | Agent architecture, safety, evaluation, frameworks |
| `agent-loop-expert` | Opus | Loop patterns, control flow, orchestration |
| `agent-memory-expert` | Opus | Memory architectures, RAG, vector stores |
| `agent-task-expert` | Opus | Task decomposition, planning, execution |

Each agent maintains a persistent knowledge base in `~/.claude/agent-memory/` that grows over time through web research and user interactions.

## Usage

```bash
# Install the plugin
claude plugins add ./plugins/agent-skills

# Ask about agent design
/agent-design "When should I use a router pattern vs supervisor pattern?"

# Ask about loop patterns
/agent-loops "Compare ReAct vs Plan-and-Execute for multi-file refactoring"

# Ask about memory systems
/agent-memory "Which vector DB should I use for 1M entries?"

# Ask about task systems
/agent-tasks "How should I implement checkpoint-and-resume?"

# Refresh knowledge bases
/agent-design-update
/agent-loops-update
```

## Supporting Documents

Each skill includes read-only reference documents consolidated from research:

**agent-design**: design-guidance, architecture-patterns, prompt-engineering, safety-and-evaluation, framework-comparison

**agent-loops**: loop-patterns, design-guidance, framework-comparison

**agent-memory**: memory-architectures, rag-and-retrieval, design-guidance, framework-comparison

**agent-tasks**: task-patterns, design-guidance, framework-comparison

## Coverage

- **13+ frameworks**: Claude Code, LangGraph, CrewAI, AutoGen, Semantic Kernel, Vercel AI SDK, Google ADK, AWS Strands, OpenAI Agents SDK, Pydantic AI, DSPy, MetaGPT, OpenHands
- **8+ loop patterns**: ReAct, Plan-Execute, ReWOO, ToT, LATS, Reflexion, multi-agent, cognitive architectures
- **7+ memory approaches**: Episodic, semantic, procedural, working, RAG variants, knowledge graphs, vector stores
- **6+ task strategies**: HTN, MCTS, plan-and-execute, parallel, checkpoint-resume, guard-evaluated
- **20+ academic papers** cited with arXiv IDs
