# Agent Framework Loop Comparison

## Quick Reference Table

| Framework | Language | Loop Type | Stars | Key Differentiator |
|-----------|----------|-----------|-------|-------------------|
| **Claude Code** | TypeScript | ReAct (minimal while-loop) | 200k+ | Largest open-source agent; 5700+ skills |
| **LangGraph** | Python | Graph-based (any pattern) | 26k+ | Stateful directed graphs with checkpointing |
| **CrewAI** | Python | Sequential/Hierarchical multi-agent | 46k+ | Role-based crews + event-driven Flows |
| **AutoGen** | Python/C#/TS | Message-passing multi-agent | 55k+ | Pattern-agnostic via same infra |
| **OpenHands** | Python/TS | Step-based (CodeAct) | 69k+ | 77.6% SWE-Bench |
| **SWE-agent** | Python | ReAct + ACI | 18k+ | Agent-Computer Interface (NeurIPS 2024) |
| **MetaGPT** | Python | SOP-driven role-based | 65k+ | Real SWE workflows as pipelines |
| **OpenAI Swarm** | Python | Handoff-based | 21k+ | Radical minimalism: agents + handoffs |
| **DSPy** | Python | Declarative compiled | 32k+ | Prompts as compilation targets |
| **Smolagents** | Python | Code-generating ReAct | 26k+ | ~1000-line core; code-as-action |
| **Letta/MemGPT** | Python | Memory-augmented loop | 21k+ | First-class memory management |
| **Semantic Kernel** | Python/C#/Java | Planner + function-calling | 27k+ | Enterprise multi-lang parity |
| **Vercel AI SDK** | TypeScript | Tool-loop + streaming UI | 22k+ | Frontend-first, React hook integration |

## Agent Loop Taxonomy

| Pattern | Representative Projects |
|---------|------------------------|
| **ReAct (Reason+Act)** | Claude Code, SWE-agent, Smolagents, OpenHands |
| **Plan-and-Execute** | BabyAGI, GPT-Researcher, LangGraph |
| **Stateful Graph** | LangGraph |
| **Role-based Multi-Agent** | MetaGPT, CrewAI, CAMEL |
| **Message-Passing Multi-Agent** | AutoGen, OpenAI Swarm |
| **Declarative/Compiled** | DSPy, BAML |
| **Memory-Augmented Loop** | Letta/MemGPT |
| **Code-as-Action** | Smolagents, OpenHands (CodeAct) |
| **SOP-Driven Pipeline** | MetaGPT |
| **Handoff-based** | OpenAI Swarm, Semantic Kernel |

### Autonomous Coding Agents (2025-2026)

| Agent | Loop Type | Key Loop Innovation |
|---|---|---|
| **Devin** | Plan → Execute → Verify (cloud) | Interactive Planning: agent researches codebase and proposes plan before execution; plan is checkpoint, not gate |
| **OpenAI Codex** | o3 reasoning loop (cloud) | Parallel worktrees: multiple isolated agents working same repo simultaneously |
| **Google Jules** | Async Plan → Execute (cloud VM) | Async background execution: tasks run in Cloud VMs while developer works elsewhere |
| **GitHub Copilot Agent** | Issue → Plan → Execute → PR | Platform-native loop: triggered from GitHub issues, executes in Actions, outputs draft PRs |
| **Cline** | Plan/Act dual-mode | Explicit mode separation: Plan mode (read-only research) → Act mode (write execution) with user-controlled transitions |
| **Aider** | ReAct + repo map context | Tree-sitter + PageRank repo map: AST-aware context selection before each LLM call |
| **OpenCode** | ReAct + persistent server | Persistent background server: sessions survive disconnects, LSP integration for code intelligence |
| **Goose** | ReAct + MCP extensions | MCP-native loop: tools discovered and loaded via Model Context Protocol at runtime |
| **Devika** | Pipeline: Plan → Research → Format → Code | Sub-agent pipeline: specialized agents for each phase (Planner, Researcher, Formatter, Coder) |
| **Moderne/Moddy** | LLM + deterministic tools | Hybrid loop: LLM reasons about intent, deterministic OpenRewrite recipes execute transformations |

## Key Architectural Insights

### The Canonical Agent Loop
"An agent is a while loop that makes tool calls." — Braintrust
Tool responses = 67.6% of total tokens; system prompts = 3.4%.

### Inner Loop vs Outer Loop
- **Inner loop**: Domain reasoning + tool execution (ReAct, Plan-Execute, etc.)
- **Outer loop**: Infrastructure — routing, governance, guardrails, budget, observability
- "Goal-directed systems cannot effectively constrain their own behavior." — outer loop handles constraints

### Recent Trends (2024-2026)
- **Context engineering** > prompt engineering
- **Reasoning models** (o1/o3): Internalized inference-time search replaces external tree search
- **Flow engineering**: Explicit workflow graphs over pure autonomous loops
- **MCP**: Universal protocol for agent-tool integration
- **Multi-agent surge**: 1,445% inquiry growth (Gartner)
- **Hybrid patterns dominate**: Pure single-pattern agents increasingly rare in production

## Sources
- Framework GitHub repositories and documentation
- Braintrust agent engineering blog
- Agent loop formalization as POMDP: arxiv:2601.12560
