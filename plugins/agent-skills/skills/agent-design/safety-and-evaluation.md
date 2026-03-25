# Agent Safety, Evaluation, and Observability

## Sandboxing

### Execution Isolation
Restrict agent's environment to limit blast radius of errors or malicious actions.

| Sandbox | Mechanism | Overhead | Security Level | OS |
|---|---|---|---|---|
| **Firejail** | Namespace isolation | Low | Medium | Linux |
| **Bubblewrap** | User namespace sandbox | Low | Medium-High | Linux |
| **Docker** | Container isolation | Medium | High | Cross-platform |
| **Landlock** | Kernel-level access control | Very low | High | Linux 5.13+ |

## Permission Systems

### Deny-by-Default
Agent can't do anything unless explicitly allowed. Most secure starting point.

### Action Budgets
- Rate limiting: N actions per time period
- Token budget: Max tokens per task
- Iteration cap: Max tool calls per loop (typical default: 10)

### Autonomy Levels
- **Read-only**: Can read/search but not modify (guard agents, verification)
- **Supervised**: Can modify with human approval
- **Autonomous**: Can modify freely within policy bounds
- **Full**: Unrestricted (dangerous, for development only)

## Human-in-the-Loop (HITL)

### Approval Gates
- Per-tool approval (e.g., approve each shell command)
- Per-phase approval (e.g., approve plan before execution)
- Exception-only (e.g., only ask for destructive operations)

### Review Points
- Before executing generated code
- Before making external API calls
- Before modifying files in protected directories
- Before sending messages on behalf of user
- When confidence is below threshold

## Guardrails

### NeMo Guardrails (NVIDIA)
Programmable rails for LLM applications — input, output, and dialog rails.
Colang language for conversation policies.

### Guardrails AI
Input/output validation — PII, toxicity, SQL injection, prompt injection.
Schema-based output validation.

### Credential Scrubbing
Scrub tool output with regex-based redaction before returning to LLM.
Prevents accidental credential exposure in LLM context.

## Network Isolation (OpenAI Codex, 2025)
Cut off internet access during agent execution as a security primitive:
- Dependencies pre-installed via setup script before network disabled
- Prevents data exfiltration, supply-chain attacks, prompt injection via web
- Trade-off: agent cannot browse docs or install packages mid-task
- Strongest security guarantee for autonomous coding agents

## Constitutional AI (Anthropic)
Train models with principles-based self-improvement:
1. Generate response → 2. Critique against principles → 3. Revise → 4. Train on revisions

## Audit Trails

### What to Log
- Every tool call with inputs and outputs
- Every LLM request/response with token counts
- Permission decisions (approved/denied)
- State transitions (task status changes)
- Security events (sandbox violations, rate limit hits)

---

## Agent Evaluation Benchmarks

| Benchmark | What It Measures | Key Metrics |
|---|---|---|
| **SWE-bench** | Real GitHub issue resolution | % resolved (Verified subset: ~50% SOTA) |
| **GAIA** | General AI assistants (web, files, reasoning) | % correct across 3 difficulty levels |
| **AgentBench** | Multi-environment agent performance | Average score across 8 environments |
| **WebArena** | Web browsing tasks | Task completion rate |
| **ToolBench** | Tool use across 16,000+ APIs | Pass rate, tool selection accuracy |
| **HumanEval** | Code generation | pass@k (k=1,10,100) |
| **MATH** | Mathematical reasoning | % correct (competition problems) |

### Evaluation Frameworks
- **RAGAS**: RAG-specific metrics (faithfulness, relevance, precision, recall)
- **AgentEval**: Multi-dimensional evaluation of agent capabilities
- **Red-teaming**: ART (Automated Red Teaming), AgentVigil

### pass@k vs pass^k
- **pass@k**: Probability of at least one correct solution in k attempts
- **pass^k**: Probability of k consecutive correct solutions (reliability metric)

## Observability Platforms

| Platform | Focus | Key Feature |
|---|---|---|
| **LangSmith** | LangChain ecosystem | End-to-end tracing, evaluation |
| **Langfuse** | Open source | Self-hostable, prompt management |
| **Arize Phoenix** | ML observability | Tracing + traditional ML monitoring |
| **AgentOps** | Agent-specific | Session replay, cost tracking |
| **Maxim** | Enterprise | Advanced evaluation, monitoring |

### Key Observability Practices
- **Trace every LLM call**: Request, response, tokens, latency
- **Token accounting**: Track cost per task, per session, per user
- **Conversation logging**: Full conversation state for debugging
- **Structured events**: Use typed events, not free-form logs

## Sources
- Constitutional AI: arxiv:2212.08073
- NeMo Guardrails: github.com/NVIDIA/NeMo-Guardrails
- Guardrails AI: github.com/guardrails-ai/guardrails
- OWASP Top 10 for LLMs: owasp.org/www-project-top-10-for-large-language-model-applications/
