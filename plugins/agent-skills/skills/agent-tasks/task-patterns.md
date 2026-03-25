# Agent Task Patterns

## Task Decomposition

### Hierarchical Task Networks (HTN)
**Definition**: Decompose high-level tasks into subtasks using predefined methods, recursively until reaching primitive actions.

**Classical HTN**: Formal planning with operators and methods; provably correct plans.
**LLM-Augmented HTN**: LLM generates decomposition methods; 50%+ reduction in LLM calls via method reuse.

### Goal Decomposition
LLM breaks a goal into subgoals. Simpler than HTN but less formal.
- **Flat**: All subtasks at the same level
- **Tree**: Hierarchical parent-child relationships
- **DAG**: Tasks with shared dependencies (most realistic)

### Recursive Decomposition
Repeatedly decompose until each subtask is small enough for a single agent turn.
Pattern: `decompose(task) → if simple: execute, else: decompose(subtask) for each subtask`

---

## Task Planning

### Classical Planning (STRIPS, PDDL)
Formal state-space search with preconditions and effects.
- Provably optimal when model is correct
- Brittle when domain model is incomplete
- Still beats LLMs for well-defined domains with known state spaces

### LLM-Based Planning
LLM generates a plan in natural language or structured format.
- Flexible, handles novel domains
- Plans may be wrong; need verification and replanning
- Plan-and-Solve prompting (Wang et al.): "Let's first understand the problem and devise a plan"

### Adaptive Replanning
Execute plan steps; after each step (or on failure), decide whether to replan.
- Best reliability for complex tasks
- Higher cost (replan decision = extra LLM call per step)

### MCTS for Planning (LATS, RAP)
Monte Carlo Tree Search with LLM value functions.
- **LATS**: MCTS + ReAct — systematic exploration of action space
- **RAP**: Reasoning via Planning — world model guides tree search
- 3-5x cost but higher success rate on complex tasks

---

## Execution Strategies

### Sequential
Execute tasks one at a time, in order.
- Simplest; each task can use results of previous tasks
- Slowest for independent tasks

### Parallel (Fan-out / Fan-in)
Execute independent tasks simultaneously, aggregate results.
- Fastest for independent work
- Requires clear independence between tasks
- Need aggregation strategy for results

### Pipeline
Stream data through processing stages, each stage processes as data arrives.
- Good for data transformation workflows
- Lower latency than full sequential (stages overlap)

### Speculative Execution
Start multiple approaches in parallel, use the first successful result.
- Higher cost (wasted computation on failed approaches)
- Lower latency (don't wait for failures before trying alternatives)

### Checkpoint-and-Resume
Persist state at milestones; resume from last checkpoint on failure.
- Essential for tasks > 5 minutes
- Trade-off: checkpoint overhead vs restart cost

---

## State Management

### Task Status FSM
```
pending → in_progress → completed
              ↓
          blocked (waiting on dependency)
              ↓
          failed (max retries exceeded)
```

### Dependency Resolution
- **Topological sort**: Execute tasks respecting dependency order
- **Critical path**: Identify longest dependency chain (determines minimum completion time)
- **Dynamic scheduling**: Re-evaluate dependencies as tasks complete

---

## Task Verification

### Programmatic Guards
Test passes, file exists, API returns 200. Most reliable.

### LLM-Judged Guards
Separate LLM evaluates whether the task output meets the done condition.
- Good for subjective quality criteria
- Default: max 3 guard iterations before escalating

### Human-in-the-Loop
Present results for human review. Necessary for high-stakes decisions.

---

## Delegation Patterns

### Manager/Worker
Central manager decomposes and assigns tasks to specialized workers.
- Clear authority; easy to add workers
- Manager is bottleneck

### Auction-Based
Workers bid on tasks based on capability/availability.
- Good for dynamic workloads
- Complex to implement

### Skill-Based Routing
Match task requirements to worker capabilities.
- Most efficient allocation
- Requires capability registry

### Handoff Protocols
Explicit transfer of responsibility between agents.
- Clear ownership at every point
- Handoff overhead

## Sources
- HuggingGPT: arxiv:2303.17580
- Voyager: arxiv:2305.16291
- Plan-and-Solve: arxiv:2305.04091
- LATS: arxiv:2310.04406
- Self-Refine: arxiv:2303.17651
- Reflexion: arxiv:2303.11366
