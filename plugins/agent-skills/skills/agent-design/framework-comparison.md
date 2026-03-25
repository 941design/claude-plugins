# Agent Framework Comparison

## Overview Table

| Framework | Language | Loop Type | Multi-Agent | Key Differentiator | Stars |
|---|---|---|---|---|---|
| **Claude Code** | TypeScript | ReAct + hooks | Subagents | Minimal loop, hook system, 200k+ stars | 200k+ |
| **LangGraph** | Python/JS | State graph | Subgraphs | Checkpointing, time-travel, visual | 26k+ |
| **CrewAI** | Python | Sequential/hierarchical | Role-based crews | Simple multi-agent, built-in memory | 46k+ |
| **AutoGen** | Python/C#/TS | Conversation | Group chat | Flexible agent conversations | 55k+ |
| **Semantic Kernel** | C#/Python/Java | Plugin pipeline | Multi-agent | Microsoft ecosystem, enterprise | 27k+ |
| **Vercel AI SDK** | TypeScript | Streaming | Middleware | Best web/streaming DX, edge-ready | 22k+ |
| **Google ADK** | Python | Event loop | A2A protocol | Google ecosystem, Gemini-optimized | New |
| **AWS Strands** | Python | Event loop | Multi-agent | AWS service integration | New |
| **OpenAI Agents SDK** | Python | Tool loop | Handoffs | Simple API, tracing, guardrails | New |
| **Pydantic AI** | Python | Agent function | Multi-agent | Type-safe, Pydantic validation | 8k+ |
| **DSPy** | Python | Compiler/optimizer | Module pipeline | Prompt optimization, no prompt eng | 32k+ |
| **Haystack** | Python | DAG pipeline | Component-based | Production RAG, modular | 18k+ |
| **OpenHands** | Python/TS | Step-based (CodeAct) | Multi-agent | 77.6% SWE-Bench | 69k+ |
| **SWE-agent** | Python | ReAct + ACI | — | Agent-Computer Interface (NeurIPS 2024) | 18k+ |
| **MetaGPT** | Python | SOP-driven role-based | Role pipeline | Software company metaphor (ICLR 2025) | 65k+ |
| **Smolagents** | Python | Code-generating ReAct | — | ~1000-line core; 30% fewer steps | 26k+ |
| **Letta/MemGPT** | Python | Memory-augmented loop | — | First-class memory management | 21k+ |

### Autonomous Coding Agents (2025-2026)

| Agent | Type | Loop | Sandbox | Key Differentiator | Stars |
|---|---|---|---|---|---|
| **Devin** | Cloud SaaS | Plan → Execute → Verify | Cloud VM (shell+editor+browser) | Interactive planning, multi-instance parallel, Slack/Teams integration | Closed |
| **OpenAI Codex** | Cloud SaaS | o3-based reasoning | Isolated container (no internet) | Parallel worktrees, codex-1 model, desktop app command center | Closed |
| **Google Jules** | Cloud SaaS | Plan → Execute (async) | Google Cloud VM | Async background execution, Gemini 2.5 Pro, full-stack VM access | Closed |
| **GitHub Copilot Agent** | Platform-native | Issue → PR pipeline | GitHub Actions runner | Native GitHub integration, branch protection, CI/CD gating | Closed |
| **OpenClaw** | Self-hosted runtime | ReAct + hooks | Local machine | 20+ chat channels (Slack/Discord/Telegram/etc.), persistent memory, any LLM | 200k+ |
| **Aider** | Terminal CLI | ReAct + repo map | Local machine | Tree-sitter repo map + PageRank context, SOTA SWE-bench | 30k+ |
| **Cline** | VS Code extension | Plan/Act dual-mode | Local machine | Plan mode (research) → Act mode (execute), 5M+ developers | 59k+ |
| **Goose** | Desktop + CLI | ReAct + MCP | Local machine | MCP-native extensibility, Linux Foundation AAIF member, any LLM | 15k+ |
| **OpenCode** | Terminal TUI (Go) | ReAct + persistent server | Local machine | 75+ LLM providers, persistent sessions (survives disconnects), LSP integration | 95k+ |
| **Devika** | Web UI | Plan → Research → Code | Local machine | Sub-agent pipeline (Planner → Researcher → Formatter → Coder) | 18k+ |
| **Moderne/Moddy** | Enterprise SaaS | LLM + deterministic tools | Cloud | Lossless Semantic Trees (LSTs), multi-repo at billions of LOC scale | Closed |

## Design Philosophy Comparison

### Minimal Loop (Claude Code)
- Simple tool-calling loop with minimal overhead
- Extension via tools/skills/hooks, not framework abstractions
- Philosophy: "The LLM IS the control flow"

### Graph-Based (LangGraph)
- Explicit state machine with typed state, edges, conditional routing
- Maximum control over execution flow
- Philosophy: "Define the graph, let state flow through it"

### Role-Based (CrewAI, MetaGPT)
- Agents have roles, tasks assigned based on expertise
- Natural for team-like collaboration
- Philosophy: "Model it like a team of specialists"

### Conversation-Based (AutoGen)
- Agents collaborate through conversation
- Flexible, emergent coordination
- Philosophy: "Let agents talk it out"

### Compiler-Based (DSPy)
- Treat prompts as programs, optimize via compilation
- No manual prompt engineering
- Philosophy: "Optimize the prompts automatically"

## Routing vs Delegation Convergence

Systems that started with preloading/routing eventually added delegation. The winning pattern: "routing decision triggers specialized agent with curated tools."

| Framework | Routing Mechanism | Delegation Mechanism |
|-----------|-------------------|---------------------|
| **Claude Code** | Skills (preloading) + model aliases | Subagents (delegation) |
| **LangGraph** | Conditional edges + classifier nodes | Subgraphs as nodes/tools |
| **CrewAI** | Role-based task assignment | Hierarchical manager delegation |
| **AutoGen** | Pattern-based speaker selection | Group chat + handoffs |
| **Semantic Kernel** | FunctionChoiceBehavior.Auto() | Multi-agent with per-kernel plugins |
| **OpenAI Agents SDK** | Handoffs ARE tool calls | Routing and delegation unified |

**Industry convergence**: The distinction between "routing" and "delegation" is collapsing. In mature systems, routing IS delegation.

## Trend Analysis (2024-2026)

### Convergence
- All major frameworks adding tool calling, memory, multi-agent
- MCP becoming standard for tool integration
- A2A emerging for agent-to-agent communication

### Simplification Trend
- Move away from complex orchestration frameworks
- "Just write code" approach gaining favor
- Anthropic: simple loops > complex graphs for most use cases

### Autonomous Coding Agent Wave (2025-2026)
- Cloud-sandboxed agents (Devin, Codex, Jules) vs local-first agents (Aider, Cline, Goose, OpenCode)
- Platform-native agents (GitHub Copilot Agent) deeply integrated with existing workflows
- Async/background execution becoming standard (Jules, Devin, Copilot Agent)
- Multi-channel persistent agents (OpenClaw) as always-on virtual coworkers
- MCP as the universal extensibility layer (Goose → Linux Foundation AAIF)
- Structured code representations (Moderne LSTs) enabling multi-repo scale

### Decentralized Agent Coordination (Nostr)
- **Clawstr**: Reddit-style social network where only AI agents can post; agents own cryptographic keys via Nostr
- **DVMCP/ContextVM**: MCP servers exposed as Nostr Data Vending Machines — decentralized tool discovery without registries
- **Nostr MCP Bridge**: AI agents discover and use MCP tools by querying Nostr relays, no centralized server needed
- Pattern: Nostr provides decentralized identity + discovery + payment (Lightning) for autonomous agents

### Key Insight
"An agent is a while loop that makes tool calls." — Braintrust
Tool responses = 67.6% of total tokens; system prompts = 3.4%. Tool output quality dominates.

## Sources
- Framework GitHub repositories and documentation
- Braintrust agent engineering blog
- Gartner multi-agent inquiry data (1,445% growth Q1 2024 → Q2 2025)
- SWE-agent NeurIPS 2024: arxiv:2405.15793
- Devin 2.0 technical design: medium.com/@takafumi.endo
- OpenAI Codex: developers.openai.com/codex
- Google Jules: jules.google
- GitHub Copilot Agent: docs.github.com/en/copilot
- Clawstr: github.com/clawstr/clawstr
- DVMCP: github.com/gzuuus/dvmcp
