# Task Framework Comparison

## BabyAGI
**Architecture**: Task-driven autonomous agent with creation/prioritization/execution loop.
- Original minimal agent loop (~100 lines of Python)
- Three phases: Execute task → Generate new tasks → Prioritize task list
- 22k+ stars; evolved to self-building functions
- **Key insight**: Simple task queue + LLM is surprisingly capable
- **Limitation**: Infinite task generation without convergence

## LangGraph
**Architecture**: Task graphs with checkpointing and state machines.
- Explicit state graphs model task dependencies
- Checkpoint-and-resume for long-running tasks
- Conditional edges for dynamic task routing
- Time-travel debugging for task execution analysis
- **Best for**: Complex workflows with explicit state management

## CrewAI
**Architecture**: Task assignment and delegation via role-based crews.
- Tasks assigned to agents based on role expertise
- Hierarchical delegation: manager → specialist agents
- Event-driven Flows for workflow orchestration
- Built-in task output validation
- **Best for**: Teams of agents with clear role boundaries

## MetaGPT
**Architecture**: SOP-driven role-based pipeline.
- Models real software development workflows
- CEO → CTO → PM → Engineer → QA hierarchy
- Standardized Operating Procedures define task flow
- ICLR 2025 oral paper
- **Best for**: Complex multi-role development tasks

## AutoGen / AG2
**Architecture**: Conversable agents with group chat.
- Tasks emerge from agent conversations
- Group chat manager routes between agents
- Teachability: agents learn from interactions
- TaskWeaver: code-generating task execution
- **Best for**: Flexible, conversation-driven task resolution

## SWE-agent / OpenHands
**Architecture**: Software engineering task execution.
- SWE-agent: ReAct + Agent-Computer Interface (NeurIPS 2024)
- OpenHands: 77.6% on SWE-Bench Verified
- Multi-agent delegation hierarchy
- Specialized for code generation and bug fixing
- **Best for**: Software engineering tasks (issues, PRs, code changes)

## Claude Agent SDK
**Architecture**: ReAct tool-use loop.
- Anthropic's official agent SDK
- Reference implementation for Claude-based agents
- Simple tool-calling loop with message management
- **Best for**: Building Claude-powered agents from scratch

## Google ADK
**Architecture**: Event loop with A2A protocol.
- Agent-to-Agent (A2A) communication standard
- LlmAgent transfer for dynamic routing
- LiteLLM integration for 100+ providers
- **Best for**: Multi-agent systems in Google ecosystem

## AWS Strands
**Architecture**: Event loop with AWS service integration.
- Deep integration with AWS services
- Multi-agent coordination
- **Best for**: AWS-native agent deployments

## Comparison Table

| Framework | Decomposition | Planning | Execution | Verification | Multi-Agent |
|---|---|---|---|---|---|
| **BabyAGI** | LLM-based | Queue priority | Sequential | None built-in | Single agent |
| **LangGraph** | Graph nodes | State machine | Graph traversal | Checkpoint | Subgraphs |
| **CrewAI** | Role-based | Manager assigns | Sequential/parallel | Output validation | Role-based crews |
| **MetaGPT** | SOP-driven | Role pipeline | Pipeline | Phase gates | Role hierarchy |
| **AutoGen** | Conversational | Emergent | Message passing | Agent consensus | Group chat |
| **SWE-agent** | ReAct steps | Implicit | Sequential | Test execution | Single + delegation |
| **Claude SDK** | Tool-calling | Implicit | ReAct loop | Programmatic | Via spawn |

## Autonomous Coding Agents (2025-2026)

| Agent | Task Model | Decomposition | Verification | Unique Feature |
|---|---|---|---|---|
| **Devin** | Interactive planning → execution | LLM plans before executing; user can modify plan | Self-reviewing PRs, test execution | Plan is checkpoint, not gate |
| **OpenAI Codex** | Parallel worktree tasks | Each task isolated in Git worktree | Iterative testing in sandbox | Multiple tasks on same repo simultaneously |
| **Google Jules** | Async background tasks | Full project understanding → plan → execute | Presents diff + reasoning for review | Async: developer works while agent runs |
| **GitHub Copilot Agent** | Issue → PR pipeline | Explores repo from issue context | CI/CD in Actions runner | Platform-native: branch protection + review gates |
| **Aider** | Interactive edit-test loop | Single-turn edits with repo map context | Auto-lints + runs tests after each edit | AST-aware context via tree-sitter |
| **Cline** | Plan/Act dual-mode | Plan mode researches; Act mode executes | User reviews plan before execution | Explicit mode separation |
| **Devika** | Sub-agent pipeline | Planner → Researcher → Formatter → Coder | Code generation from researched context | Specialized sub-agents per phase |
| **Moderne/Moddy** | LLM + deterministic recipes | LLM interprets intent → selects OpenRewrite recipes | Deterministic transformations (LSTs) | Multi-repo at billions of LOC |

## Sources
- BabyAGI: github.com/yoheinakajima/babyagi
- SWE-agent: swe-agent.com (NeurIPS 2024)
- OpenHands: github.com/All-Hands-AI/OpenHands
- MetaGPT: arxiv:2308.00352 (ICLR 2025)
- Devin 2.0: devin.ai
- OpenAI Codex: developers.openai.com/codex
- Google Jules: jules.google
- GitHub Copilot Agent: docs.github.com/en/copilot
- Moderne/Moddy: moderne.ai
