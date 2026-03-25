# Prompt Engineering for Agents

## 1. Section Ordering and Position Effects

### The "Lost in the Middle" Problem
LLMs exhibit a U-shaped attention curve: information at the beginning and end receives the most attention; middle information is under-attended.
- Liu et al. (2024, TACL): 30%+ accuracy drop when relevant info moved from position 1 to position 10
- A 10,000-token prompt may effectively operate on just the last ~2,000 tokens

### Recommended Section Order
1. **Identity + critical constraints** (beginning — primacy zone)
2. **Capabilities and tool descriptions** (early-middle)
3. **Detailed guidelines and examples** (middle — lowest attention)
4. **Output format + key reminders** (end — recency zone)
5. **Repeat the single most critical instruction** at both beginning and end

Use structural delimiters (XML tags, markdown headers) to create attention anchors.

## 2. Instruction Density and Prompt Length

### Compliance vs. Instruction Count
- **10 instructions**: 94-100% accuracy
- **100 instructions**: 43-98% accuracy (model-dependent)
- **500 instructions**: Best performers reach only 51-63% accuracy

### The Minimum Effective Dose (Anthropic)
"The smallest possible set of high-signal tokens that maximize the likelihood of some desired outcome."
- Minimal does NOT mean short — it means every token earns its place
- Move reference material to retrievable documents rather than stuffing into system prompt

### Practical Thresholds
- **Under ~2,000 tokens**: Reliable adherence for most models
- **2,000-8,000 tokens**: Works well with good structure
- **8,000-16,000 tokens**: Requires aggressive prioritization
- **16,000+ tokens**: Diminishing returns; prefer RAG/retrieval

## 3. Positive vs. Negative Framing

- **Lead with positive framing**: "Write responses in formal English" > "Don't use informal language"
- **Use negative framing sparingly** for hard safety boundaries
- **Pair negatives with positive alternatives**: "Don't summarize. Instead, explain the specific bug."
- **Avoid long "don't" lists**: Models lose track; consolidate into positive specification
- Claude-specific: Forceful "don't" instructions can backfire via reverse psychology effect

## 4. Redundancy and Repetition

### When Repetition Helps
- Google Research: Repeating the input prompt improved performance in 47/70 tests with 0 losses
- Optimal count: 2 repetitions work best; 3 helps on list indexing and pattern matching
- Critical safety instructions (beginning + end placement)
- In long conversations: reiterating task instructions restores up to 85% of lost accuracy

### When Repetition Hurts
- Short prompts (under ~1,000 tokens) — wastes budget
- When it creates contradiction (slightly different wording)
- Excessive repetition (4+ times) confuses rather than reinforces

### Rule
Repeat your 1-3 most critical instructions at beginning and end. State everything else once with structural emphasis.

## 5. Cognitive Architecture in Prompts

### What to Put in System Prompt
- ReAct scaffolding (for models without native tool-calling)
- Output structure requirements
- Decision heuristics: "If uncertain, ask rather than guessing"
- Error handling patterns

### What to Let Emerge
- Chain-of-thought (frontier models do this naturally)
- Tool selection logic (well-described tools are selected correctly)
- Complex multi-step planning (over-specifying creates rigidity)

### Reasoning Model Caveat
Reasoning can hurt performance by over-focusing on high-level content and neglecting simple constraints. For instruction-following tasks, explicit step-by-step reasoning is sometimes counterproductive.

## 6. Model-Specific Tuning

### Claude (Anthropic)
- Trained with XML tags; use `<example>`, `<document>`, `<instructions>` for structure
- Vulnerable to reverse-psychology effect with forceful "don't" instructions
- Strength: Careful reasoning, fewer hallucinations, long-context coherence
- Failure mode: Can be overly cautious/verbose when over-constrained

### GPT (OpenAI)
- Responds well to markdown; JSON mode available
- Linear decay — steady decline as instruction count increases
- Failure mode: Can be confidently wrong

### Gemini (Google)
- Supports both XML and markdown; largest context windows (2M tokens)
- Failure mode: Can be overly literal; Flash variants sacrifice depth

### Local Models (Qwen, DeepSeek, Llama)
- Weaker instruction following; benefit most from explicit CoT and few-shot examples
- Exponential decay pattern on instruction density
- Recommendation: More explicit, more structured, more examples

## 7. Context Engineering (Anthropic Framework, 2025)

### Six Context Layers
1. **System rules**: Identity, constraints, behavioral specification
2. **Memory**: Persistent knowledge from prior interactions
3. **Retrieved docs**: RAG results, file contents, search results
4. **Tool schemas**: Available capabilities and their parameters
5. **Recent conversation**: Recent turns for continuity
6. **Current task**: The immediate user request

### Key Practices
- **Just-in-time retrieval**: Don't preload; retrieve when needed
- **Progressive disclosure**: Start high-level, add detail as needed
- **Compaction**: Compress when approaching limits; preserve recent turns + critical instructions
- **Sub-agent isolation**: Offload context-heavy work; parent gets summary only
- **Canonical examples over edge-case lists**: Curated examples portray expected behavior

## 8. Agentic Persistence

### The Degradation Problem
- All LLMs: **average 39% drop** in multi-turn vs single-turn (ICLR 2026)
- "When LLMs take a wrong turn in a conversation, they get lost and do not recover."

### Mitigation Strategies
1. **Instruction reiteration**: Repeating task description restores up to 85% of lost accuracy
2. **Fresh start**: New conversation with same info often outperforms persisting
3. **Structural memory separation**: Instructional memory (persistent) + episodic memory (dynamic)
4. **Utility-based memory deletion**: Prevents bloat; yields up to 10% performance gains
5. **Periodic checkpoints**: Summarize progress, restate goals, clear completed context

## 9. Identity and Persona

- Use **functional role identity** ("You are a code review agent") not personality traits
- Anchor identity in system prompt opening (primacy) and closing (recency)
- Tie identity to capabilities: "As a code reviewer, you have access to [tools]"
- Avoid personality theater: Heavy persona instructions deprioritized under task pressure

## Anti-Patterns

1. **Monolithic Prompt Stuffing** — Layer context instead
2. **Vague Behavioral Specs** — "Be helpful" tells nothing; specify concrete behaviors
3. **Instruction Overload** — Prioritize 10-15 critical rules; move rest to retrievable docs
4. **The "Don't" Wall** — Lead with what to do; use "don't" for safety only
5. **Tool Description Bloat** — Audit tool set; remove unused tools
6. **Hardcoded Brittle Logic** — Move complex conditionals to code
7. **Missing Output Spec** — Include explicit format with canonical example
8. **Context Mixing** — Separate instructions from data with clear delimiters
9. **Ignoring Degradation** — Reiterate key instructions periodically in long sessions
10. **Over-Constraining Autonomy** — Identify 3-5 rules that matter; make rest guidance

## Sources
- Liu et al., "Lost in the Middle" (TACL 2024)
- Leviathan, "Prompt Repetition Improves Non-Reasoning LLMs" (Google Research, 2025)
- "How Many Instructions Can LLMs Follow at Once?" (2025): arxiv:2507.11538
- Anthropic, "Effective Context Engineering for AI Agents" (2025)
- Anthropic, "Building Effective Agents" (2024)
- Multi-turn degradation (ICLR 2026): openreview.net/pdf?id=VKGTGGcwl6
