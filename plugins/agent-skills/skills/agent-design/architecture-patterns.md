# Architecture Patterns

## Router/Dispatcher Pattern

### Definition
Classify incoming requests and route to the appropriate specialist handler.

### Architecture
```
Input → Classifier → Route A (specialist)
                   → Route B (specialist)
                   → Route C (general fallback)
```

### Variants
- **Model-Based Routing**: Route by complexity — simple → cheap model, complex → capable model
- **Skill-Based Routing**: Route by required capability — code, search, analysis
- **Topic-Based Routing**: Route by domain — medical, legal, general

### When to Use
- Multiple distinct task types with different optimal handlers
- Want to optimize cost (cheap model for simple, expensive for complex)
- Need predictable routing (not emergent multi-agent behavior)
- **Important**: Only when routing controls model selection alone, not tool access

### Trade-offs
- Pros: Simple, predictable, cost-efficient, easy to add new routes
- Cons: Classification errors → wrong handler, classifier is single point of failure

### Five Criticisms of Pre-Routing Classification
1. **Classification accuracy collapse** — Dangerous when routing controls tool access
2. **Model routing implies tool selection** — For specialized work, model choice and tool choice are coupled
3. **Tool usage semantics change mid-conversation** — Follow-up messages need same tools but don't mention the topic
4. **Classifier assumes superior knowledge** — Inverts the competence hierarchy
5. **Context is disregarded** — Classifier sees only current message, not history

### When Pre-Routing Is Appropriate
1. Routing controls **only** model selection (all models see all tools) — acceptable
2. Routing controls **tool access** — reject pre-routing; use strong supervisor
3. Cost difference is **>100x** and misrouting risk acceptable — possible but fragile

---

## Supervisor/Worker Pattern

### Definition
Central supervisor receives tasks, decomposes, delegates to specialized workers, aggregates results.

### Architecture
```
User → Supervisor → Worker A (code)
                  → Worker B (search)
                  → Worker C (analysis)
     ← Aggregated Result ←
```

### Key Design Decisions
- **Fixed vs dynamic workers**: Pre-defined set vs spawn on demand
- **Communication**: Direct message passing vs shared state
- **Error handling**: Supervisor retries, reassigns, or escalates
- **Result aggregation**: Concatenation, voting, scoring, hierarchical merge

### Framework Implementations
- **CrewAI**: Manager agent creates crew, delegates to role-based agents
- **AutoGen**: GroupChat with manager routing to specialists
- **MetaGPT**: CEO → CTO → PM → Engineer hierarchy
- **LangGraph**: Supervisor node with conditional edges to worker subgraphs
- **Claude Code**: Main conversation spawns subagents for isolated tasks

### Strong Supervisor Variant
The strongest model always sees every message first and decides whether to delegate:
- **Competence hierarchy preserved** — Most capable model makes delegation decisions
- **Full conversation context** — Complete context when making delegation decisions
- **Cost concern addressed** — Strong model reads every message (cheap input tokens), delegates response generation (expensive output tokens) to cheaper specialists

### Trade-offs
- Pros: Clear authority, centralized error handling, easy to add workers
- Cons: Supervisor is bottleneck/SPOF, must understand all task types, extra LLM calls

---

## Evaluator-Optimizer Pattern

### Definition
Agent produces output, separate evaluator judges quality, optimizer refines if below threshold.

### Architecture
```
Input → Generator → Output
                      ↓
                  Evaluator → Pass? → Return
                      ↓ (Fail)
                  Optimizer → Refined Output → Evaluator
```

### Key Design Decisions
- **Evaluation criteria**: Programmatic (test passes) vs LLM-judged (quality rating)
- **Threshold**: When is "good enough"? Fixed score vs adaptive
- **Max iterations**: Prevent infinite loops (typically 2-5)
- **Feedback format**: Score only vs detailed critique

### When to Use
- Output quality is critical and variable
- Clear evaluation criteria exist
- Cost of bad output > cost of extra LLM calls

---

## Pipeline/Chain Pattern

### Definition
Sequential processing stages, each transforming the data.

### Architecture
```
Input → Stage 1 (extract) → Stage 2 (process) → Stage 3 (format) → Output
```

### When to Use
- Clear sequential steps with well-defined inputs/outputs
- Each stage has a single responsibility
- Predictable processing flow

---

## Blackboard Pattern

### Definition
Shared state space where multiple specialist agents read/write concurrently.

### Architecture
```
       Blackboard (shared state)
      ↗     ↑     ↑      ↖
Agent A  Agent B  Agent C  Agent D
```

### When to Use
- Multiple specialists contribute to a shared artifact
- Non-linear collaboration
- Need flexible, emergent coordination

---

## Ensemble/Voting Pattern

### Definition
Multiple agents solve the same problem independently, aggregate results by voting or scoring.

### When to Use
- High-stakes decisions where single-agent confidence is insufficient
- Different models/approaches may have complementary strengths
- Can afford N× cost for higher reliability

---

## Agent-Computer Interface (ACI) Pattern

### Definition (SWE-agent, NeurIPS 2024)
Design a custom abstraction layer between the LLM and the computer that's optimized for LLM capabilities rather than reusing human-designed interfaces.

### Key Insight
"ACIs tailored specifically for LMs outperform existing UIs designed for human users." The interface design is the key variable — more impactful than model choice.

### Design Principles
- Small set of simple, composable actions (not the full Linux shell)
- Guardrails to prevent common mistakes
- Concise, specific feedback at every turn
- Constrained action space reduces errors

### Performance
12.5% pass@1 on SWE-bench, 87.7% on HumanEvalFix — far exceeding non-interactive approaches.

### When to Use
- Agent interacts with complex systems (OS, IDE, browser)
- Default interfaces (shell, APIs) cause frequent errors
- Custom commands can reduce action space and add guardrails

---

## Network Isolation as Security Primitive

### Definition (OpenAI Codex, 2025)
Deliberately cut off internet access during agent execution. All dependencies must be pre-installed via setup script before network is disabled.

### Key Properties
- Agent cannot exfiltrate code or data to external services
- Prevents supply-chain attacks via malicious package downloads at runtime
- Eliminates prompt injection via fetched web content
- Trade-off: limits agent capability (cannot browse docs, install new packages mid-task)

### When to Use
- Security is paramount (enterprise codebases, sensitive IP)
- All dependencies are known in advance
- Agent doesn't need to research or browse during execution

---

## Agent Configuration as Code (AGENTS.md)

### Definition (OpenAI Codex, Goose)
Place agent configuration files in the repository itself (e.g., `AGENTS.md`, `codex.md`, `.github/copilot-instructions.md`) to give agents persistent instructions about project conventions, build commands, and coding standards.

### Key Properties
- Version-controlled alongside the code
- Shared across all team members and agent instances
- Repo-specific: each project gets its own agent configuration
- Linux Foundation AAIF adopted AGENTS.md as a standard alongside MCP and Goose

### When to Use
- Teams using autonomous coding agents across repositories
- Need consistent agent behavior aligned with project conventions
- Want agent instructions to evolve with the codebase

---

## Plan/Act Dual-Mode Pattern

### Definition (Cline)
Agent operates in two distinct modes: **Plan** (research, analyze, strategize) and **Act** (execute changes). User controls transitions between modes.

### Architecture
```
User Request → [Plan Mode: Read files, analyze, propose plan]
                    ↓ (user approves or modifies)
              [Act Mode: Edit files, run commands, make changes]
```

### Key Design Decisions
- Plan mode has read-only tools; Act mode has write tools
- Transition can be manual (user switches) or automatic (YOLO mode)
- Plan serves as implicit approval gate

### When to Use
- Tasks where research and execution are clearly separable
- User wants to review approach before changes are made
- Safety-critical codebases where blind execution is risky

---

## Structured Code Representation Pattern

### Definition (Moderne/Moddy)
Use structured code representations (Lossless Semantic Trees, not raw text) as the basis for agent analysis and transformation.

### Key Innovation
LSTs go beyond ASTs: type-attributed, format-preserving, cross-repository dependency-aware. Equivalent to IDE internal representation but serializable.

### Architecture
```
Source Code → LST Builder → Structured Representation
                                    ↓
LLM + Deterministic Tools (OpenRewrite recipes) → Code Changes
```

### When to Use
- Multi-repository analysis at enterprise scale (billions of LOC)
- Deterministic code transformations that must be correct
- When text-based approaches lack the precision needed

---

## Decentralized Agent Coordination Pattern

### Definition (Clawstr, DVMCP/ContextVM)
Agents coordinate via decentralized protocols (Nostr) rather than centralized servers, owning their own cryptographic identities.

### Architecture
```
Agent A (Nostr key) → Nostr Relay ← Agent B (Nostr key)
                         ↓
              Tool Discovery via DVM (Data Vending Machines)
              Payment via Lightning Network
```

### Key Properties
- No central authority can suspend or control agents
- Agents own cryptographic keys (self-sovereign identity)
- Tool discovery via Nostr relays (no centralized registry)
- Native micropayments via Bitcoin Lightning
- MCP tools exposed as Nostr DVMs for decentralized access

### When to Use
- Autonomous agents requiring censorship resistance
- Agent marketplaces without centralized platforms
- Cross-organization agent coordination without shared infrastructure

## Sources
- Anthropic, "Building Effective Agents" (Dec 2024)
- Wang et al., "A Survey on LLM-based Agents" (2024)
- SWE-agent ACI: arxiv:2405.15793 (NeurIPS 2024)
- Cline Plan/Act: cline.bot/blog/plan-smarter-code-faster
- Moderne LSTs: docs.moderne.io
- Clawstr: github.com/clawstr/clawstr
- DVMCP: github.com/gzuuus/dvmcp
