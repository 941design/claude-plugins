# Agent Design Guidance

## Architecture Pattern Decision Tree

```
Is this a single-task agent (one type of work)?
├── Yes → Augmented LLM (simple tool-calling loop)
└── No → Do tasks have distinct types requiring different handling?
    ├── Yes → Router pattern (classify → route to specialist)
    └── No → Does the work require multiple collaborating specialists?
        ├── Yes → Are roles predefined?
        │   ├── Yes → Supervisor/worker (CrewAI, MetaGPT style)
        │   └── No → Conversation-based (AutoGen style)
        └── No → Is output quality critical with high variance?
            ├── Yes → Evaluator-optimizer (generate → evaluate → refine)
            └── No → Pipeline (sequential processing stages)
```

## Anthropic's Recommendation

From "Building Effective Agents" (Dec 2024):
> "The most successful implementations use simple, composable patterns rather than complex frameworks."

**Start with**: Augmented LLM (model + retrieval + tools)
**Add complexity only when**: Simple loop provably insufficient for the use case

## Anti-Patterns

### 1. Framework Worship
Adopting a heavy framework before understanding the problem.
**Fix**: Start with a simple loop. Add framework features one at a time as needed.

### 2. Premature Multi-Agent
Creating multiple agents when one would suffice.
**Fix**: Use router pattern to specialize within a single agent first.

### 3. Ignoring Cost
Building sophisticated architectures without tracking token costs.
**Fix**: Instrument from day one. Track cost per task, per session, per user.

### 4. Security Afterthought
Adding safety controls after the agent is deployed.
**Fix**: Deny-by-default from day one. Sandbox by default. Budget by default.

### 5. Over-Logging
Logging everything without structured observability.
**Fix**: Define key metrics upfront. Use typed events and structured tracing.

### 6. Monolithic Prompts
Putting everything in the system prompt (instructions, examples, tools, context).
**Fix**: Layer context: system prompt (always) → rules (path-specific) → skills (on-demand) → memory (retrieved).

### 7. Tool Sprawl
Adding tools without considering context budget cost.
**Fix**: Each tool description costs context tokens. Audit tool set, remove unused tools, use tool discovery for large sets.

### 8. Pre-Routing Classifier for Tool Access
Using a cheap LLM to classify queries before the main agent sees them, especially when classification controls tool access (not just model selection).
**Fix**: Use strong supervisor pattern — let the strongest model see every message and decide delegation. Pre-routing classifiers invert the competence hierarchy (weak model decides what strong model does), break conversational continuity, and are dangerous when routing controls tool sandboxes.

### 9. Dual Config Surfaces
Having separate config sections that control the same underlying concerns (e.g., model selection in two different places).
**Fix**: Unify or eliminate the redundant surface. Audit for accidental config duplication.

## Cost-Quality-Latency Triangle

| Optimization | Improves | Worsens |
|---|---|---|
| **Cheaper model** | Cost | Quality |
| **More iterations** | Quality | Cost, Latency |
| **Prompt caching** | Cost, Latency | (nothing) |
| **Model routing** | Cost | Complexity |
| **Parallel execution** | Latency | Cost |
| **Response caching** | Cost, Latency | Freshness |

### Sweet Spots
- **Most agents**: Sonnet-class model + simple ReAct loop + prompt caching
- **High quality**: Opus-class model + evaluator-optimizer + reflection
- **High volume**: Haiku-class model + aggressive caching + router for complex cases

## Design Principles

| Principle | Implementation |
|---|---|
| KISS | Simple ReAct loop, not complex graph |
| YAGNI | Tools added only when needed, no speculative features |
| SRP | Each component = one concern |
| Fail Fast | Error on unsupported states, never silently broaden |
| Secure by Default | Deny-by-default policy, sandbox, credential scrubbing |
| Determinism | Dedup guard prevents repeated tool calls |
| Reversibility | Small changes, clear rollback paths |
| Strong Supervisor | Strongest model sees all messages, delegates to specialists |
| Tool Allowlisting | Sub-agents get curated tool subset from parent |

## Sources
- Anthropic, "Building Effective Agents" (Dec 2024)
- Anthropic, "Effective Context Engineering for AI Agents" (2025)
