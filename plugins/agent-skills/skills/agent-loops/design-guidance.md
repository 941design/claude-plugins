# Design Guidance: Choosing Agent Loop Patterns

## Decision Framework

### Start Simple, Iterate Up

```
Simple task? ──yes──> Single ReAct loop
    |no
Predictable steps? ──yes──> ReWOO or Plan-Execute
    |no
Multiple skill domains? ──yes──> Multi-agent (hierarchical or handoff)
    |no
Complex reasoning needed? ──yes──> Tree-of-Thoughts or LATS
    |no
Real-time adaptation? ──yes──> OODA-inspired ReAct with fast cycles
```

### Pattern Selection by Task Type

| Task Type | Recommended Pattern | Why |
|-----------|-------------------|-----|
| Single-turn Q&A with tools | ReAct | Simple, adaptive, one loop |
| Multi-file code refactoring | Plan-Execute | Predictable structure, long horizon |
| Multi-hop research | ReWOO or Plan-Execute | Multiple known data sources |
| Bug investigation | ReAct with reflection | Needs adaptive exploration |
| Code review | Multi-agent (reviewer + author) | Distinct roles |
| Complex math/logic | Tree-of-Thoughts | Multiple solution paths |
| Chatbot with tools | ReAct | Interactive, needs adaptability |
| Pipeline data processing | ReWOO | Known steps, no inter-step reasoning |
| System migration | Plan-Execute + Multi-agent | Long horizon, multiple subsystems |

## Key Trade-offs

### Token Efficiency
- **Most efficient**: ReWOO (2 LLM calls total)
- **Moderate**: Plan-Execute (1 plan + N execute + optional replan)
- **Least efficient**: Multi-agent (inter-agent communication), ToT (branching factor)
- **ReAct**: Proportional to number of tool iterations

### Latency
- **Lowest**: ReWOO (parallel tool execution after single plan)
- **Moderate**: ReAct (sequential LLM calls but each is simple)
- **Highest**: ToT (exponential branching), Multi-agent (coordination overhead)

### Reliability
- **Most reliable**: Plan-Execute with replanning (recovers from bad plans)
- **Good**: ReAct with dedup and iteration limits
- **Variable**: Multi-agent (depends on orchestration quality)
- **Fragile**: ReWOO (commits to plan, can't adapt mid-execution)

### Debuggability
- **Easiest**: ReAct (linear trace of thought-action-observation)
- **Moderate**: Plan-Execute (plan is inspectable, execution is linear)
- **Hardest**: Multi-agent (distributed reasoning), ToT (tree traversal)

## General Guidance

1. **Default to ReAct**: Most tasks should use a simple tool-calling loop. Most widely adopted for good reason.

2. **Use query classification for routing**: Instead of multi-agent, route different query types to different models. Simpler, cheaper.

3. **Tune iteration limits**: Default 10 is reasonable. Raise for complex tasks, lower for simple Q&A.

4. **Leverage dedup guards**: Consecutive-pair dedup catches genuine loops while allowing legitimate retries after state changes.

5. **Memory injection matters**: Design memories to be concise and high-signal to avoid context bloat.

6. **Skills over multi-agent**: Prompt injection (skills) is simpler and cheaper than spawning separate agents. Use skills for domain knowledge, save multi-agent for truly parallel workloads.

### Pattern Selection: Production Coding Agents (2025-2026)

| Scenario | Recommended Pattern | Example |
|---|---|---|
| Quick code edit, single file | ReAct | Aider, Claude Code |
| Multi-file feature, user wants control | Plan/Act dual-mode | Cline |
| Background task from issue/ticket | Async background execution | Jules, Copilot Agent |
| Parallel features, same repo | Parallel worktrees | OpenAI Codex |
| Enterprise multi-repo migration | LLM + deterministic tools | Moderne/Moddy |
| Agent needs custom tool interface | ACI + ReAct | SWE-agent |
| Always-on assistant across chat apps | Persistent ReAct | OpenClaw |
| Extensible, any-LLM agent | MCP-native ReAct | Goose |

## Anti-Patterns

1. **Over-engineering the loop**: Most tasks need simple ReAct. Don't use ToT or multi-agent for straightforward tool use.
2. **Unbounded iterations**: Always set a hard limit.
3. **No dedup protection**: Without dedup, models can loop indefinitely on the same failed tool call.
4. **Ignoring token growth**: Each iteration adds to context. Monitor usage and compact when needed.
5. **Premature multi-agent**: Adding agents adds complexity. Only use when task naturally decomposes into independent roles.
