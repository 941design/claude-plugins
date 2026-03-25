# Agent Loop Patterns

## ReAct (Reason + Act)

### Definition
Interleaves reasoning traces ("thoughts") with actions in a cyclic loop:
**Thought → Action → Observation → Thought → ... → Final Answer**

### Flow
```
User Message
    ↓
[LLM: Reason about what to do] ─── Thought
    ↓
[LLM: Choose action / tool call] ─── Action
    ↓
[Execute tool, get result] ─── Observation
    ↓
[LLM: Reason about result] ─── back to Thought
    ↓ (when done)
[LLM: Emit final response] ─── Answer
```

### Key Findings (Yao et al. 2022, ICLR 2023)
- Reasoning traces help "induce, track, and update action plans as well as handle exceptions"
- Actions "interface with external sources to gather additional information"
- On HotpotQA and Fever: overcomes hallucination/error propagation vs CoT
- Token cost: ~9,795 tokens on HotpotQA (vs ~2,000 for ReWOO — 5x difference)

### Strengths
- Simple, human-mimicking problem-solving
- Naturally adapts to unexpected results
- Easy to implement and debug (linear trace)
- Most widely adopted pattern

### Weaknesses
- Multiple LLM calls increase token overhead and latency
- Context window grows with each iteration (tool responses = 67.6% of tokens)
- Can get stuck in loops (mitigated by dedup guards and iteration limits)

### Variants
- **ReAct with streaming**: Tool results streamed incrementally
- **ReAct with approval gates**: Human-in-the-loop before tool execution
- **ReAct with dedup**: Prevent repeated identical calls (consecutive-pair dedup)
- **ReAct with routing**: Different models per query type
- **Code-as-action ReAct**: Generate executable code instead of JSON tool calls (Smolagents — 30% fewer steps)

### The Canonical Baseline
"An agent is a while loop that makes tool calls." ReAct wins "for the same reason as UNIX pipes and React components: it's simple, composable, and flexible enough to handle complexity without becoming complex itself."

---

## Plan-and-Execute

### Definition
Two-phase pattern: first generate a complete plan, then execute steps sequentially with optional replanning.

### Flow
```
Input → [Planner LLM: Generate plan] → Plan (ordered steps)
                                            ↓
        [Executor: Step 1] → Result 1 → [Replan?] → [Step 2] → ...
```

### When to Use
- Multi-file refactoring, system migrations
- Tasks with predictable structure and long horizon
- When upfront planning improves overall quality

### Trade-offs
- Pros: Structured, inspectable plan; replan on failure; good for long tasks
- Cons: Planning step adds latency/cost; rigid if not replanning; plan may be wrong

---

## ReWOO (Reasoning Without Observation)

### Definition
All tool calls planned upfront with placeholders, executed in parallel, then reasoned about together.

### Flow
```
Input → [Planner: Generate all calls with #E1, #E2 placeholders]
      → [Execute all tools in parallel]
      → [Solver: Synthesize answer from all observations]
```

### Key Finding
5x cheaper than ReAct on HotpotQA (~2,000 tokens vs ~9,795)

### Trade-offs
- Pros: Lowest token cost, parallelizable execution
- Cons: Cannot adapt mid-execution; commits to plan; fragile if plan is wrong

---

## Tree-of-Thoughts (ToT)

### Definition
BFS/DFS search over reasoning space, exploring multiple solution paths with evaluation at each node.

### Key Finding
74% on Game of 24 vs 4% with CoT

### When to Use
- Complex reasoning with multiple solution paths
- Mathematical/logical problems
- When brute-force exploration is justified by task difficulty

### Trade-offs
- Pros: Explores solution space systematically
- Cons: Exponential branching factor; highest token cost; hard to debug

---

## Multi-Agent Orchestration

### Patterns
- **Vertical**: Manager delegates to specialists (supervisor/worker)
- **Horizontal**: Peer agents with handoff protocols (OpenAI Swarm)
- **Conversation**: Agents debate/discuss (AutoGen)
- **Pipeline**: Sequential processing by specialists (MetaGPT)

### Finding
Leadership agent improves performance by ~10% (coordination matters)

---

## Cognitive Architectures

### BDI (Beliefs-Desires-Intentions)
Reasoning cycle: perceive → update beliefs → deliberate desires → form intentions → act

### SOAR
Production rules + chunking: perception → proposal → decision → application → learning

### CoALA (Cognitive Architectures for Language Agents)
Academic formalization: Agent = <S, O, M, T, π> (POMDP)

### Reflexion
Self-reflection stored as memory for retry: 91% on HumanEval (vs 80% baseline)

### LATS (Language Agent Tree Search)
MCTS + ReAct: tree search with LLM value functions for systematic exploration

---

## Guard-Based Termination

### Taxonomy
- **Hard limits**: Max iterations, token budget, time budget
- **LLM self-termination**: Model decides when done
- **Sub-agent evaluators**: Separate agent verifies completion
- **External verification**: Programmatic checks (tests pass, file exists)
- **Condition-checked loops**: Guard conditions evaluated per iteration
- **Heartbeat signals**: Periodic liveness checks

---

## Plan/Act Dual-Mode (Cline, 2025)

### Definition
Explicit separation of agent operation into Plan mode (read-only research/analysis) and Act mode (write/execute). User controls transitions.

### Flow
```
[Plan Mode] → Read files, search, analyze, propose plan
      ↓ (user approves)
[Act Mode] → Edit files, run commands, execute changes
      ↓ (can return to Plan)
[Plan Mode] → Re-analyze, adjust approach
```

### Key Innovation
Plan mode acts as an implicit approval gate. YOLO mode enables automatic Plan → Act transition when the agent determines readiness.

### Adoption
Cline: 59.3k stars, 5M+ developers. Plan/Act pattern adopted by Roo Code and other forks.

---

## Interactive Planning (Devin, 2025)

### Definition
Agent proactively researches the codebase and develops a detailed plan before execution. The plan is a checkpoint, not a gate — agent proceeds unless the user intervenes.

### Key Innovation
Shifts planning from implicit (hidden in ReAct reasoning) to explicit (visible, editable artifact). Users can modify the plan before, during, and after execution.

---

## Agent-Computer Interface Loop (SWE-agent, NeurIPS 2024)

### Definition
Replace the standard shell/API interface with a custom ACI designed for LLM capabilities: small action set, built-in guardrails, concise feedback.

### Key Finding
ACI design is more impactful than model selection. Custom interfaces outperform human-designed UIs (Linux shell) for LLM agents. 12.5% pass@1 on SWE-bench.

---

## Async Background Execution (Jules, Copilot Agent, 2025)

### Definition
Agent operates asynchronously in the background, executing tasks in isolated environments while the developer works on other things. Results delivered as draft PRs or diffs.

### Pattern
```
User assigns task (issue, chat, Slack) → Agent clones repo into VM/container
    → Agent works independently (minutes to hours)
    → Agent delivers: draft PR + diff + reasoning log
    → User reviews and merges
```

### Adoption
Google Jules (Cloud VM), GitHub Copilot Agent (Actions runner), Devin (cloud sandbox). Becoming standard for production coding agents.

## Sources
- Yao et al., "ReAct" (2022, ICLR 2023): arxiv:2210.03629
- Xu et al., "ReWOO" (2023): arxiv:2305.18323
- Yao et al., "Tree of Thoughts" (2023): arxiv:2305.10601
- Shinn et al., "Reflexion" (2023): arxiv:2303.11366
- Zhou et al., "LATS" (2023): arxiv:2310.04406
- SWE-agent ACI (NeurIPS 2024): arxiv:2405.15793
- Cline Plan/Act: cline.bot
- Devin 2.0: devin.ai
