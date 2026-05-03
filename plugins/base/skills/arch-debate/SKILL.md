---
name: arch-debate
description: |-
  Epic-level architecture debate orchestrator. Produces a living architecture.md
  and an ADR by running a structured two-round debate between a Claude Proposer
  subagent and a Codex adversary, then synthesizing both documents.

  TRIGGER when: base:feature invokes this skill (always via the arch_debate: true
  spec flag); user runs /base:arch-debate for standalone architectural analysis of
  a feature spec; team lead needs to re-examine architecture mid-epic after a major
  pivot or escalation that revealed architectural contradictions.
  Agent self-detected uncertainty about the right paradigm or module boundaries
  for a feature is sufficient to trigger.

  SKIP when: architecture.md already exists and no re-analysis is requested;
  the change is purely cosmetic or configuration-only with no structural decisions.
argument-hint: "--epic <name> --spec <path> [--adr-n <N>]"
allowed-tools: Task, Read, Write, Bash, Skill
model: opus
---

# Architecture Debate Orchestrator

You coordinate a structured two-round architecture debate for this epic. Your job
is to produce two durable artifacts:

1. `docs/adr/ADR-{N:03d}-{epic-slug}.md` — the decision record (history + rationale)
2. `specs/epic-{epic}/architecture.md` — the operational document (paradigm, modules, seams, boundary rules)

---

## Inputs

Parse `$ARGUMENTS`:
- `--epic <name>`: epic slug (e.g., `user-auth`)
- `--spec <path>`: path to spec.md
- `--adr-n <N>`: ADR number override (optional; default: auto-detect)

**If invoked standalone** (no `--epic` flag), derive the epic name from the spec
path or ask via AskUserQuestion.

Read:
- The spec at `--spec` path
- `specs/epic-{name}/exploration.json` — codebase findings from code-explorer subagents
- `docs/adr/` — count existing ADRs to assign the next number (`ls docs/adr/*.md 2>/dev/null | wc -l`, then +1)

If `exploration.json` does not exist, spawn two `code-explorer` subagents in parallel:
- Focus `architecture` (paradigm classification + module map)
- Focus `similar-features` (existing patterns for reuse)

Merge findings and write `specs/epic-{name}/exploration.json` before proceeding.

---

## State Tracking

Maintain `specs/epic-{name}/arch-debate.json` throughout. Update after each phase:

```json
{
  "status": "pending|proposed|round1_challenged|round1_responded|round2_challenged|synthesized",
  "adr_number": null,
  "proposal": null,
  "round1_challenge": null,
  "round1_response": null,
  "round2_challenge": null,
  "synthesized_at": null,
  "adr_path": null,
  "architecture_path": null
}
```

If `arch-debate.json` already exists with `status != "synthesized"`, resume from
the last completed phase rather than restarting.

---

## Phase 1: Propose

Spawn a `code-explorer` subagent as the **Proposer**. Give it this task:

> FEATURE: {spec title from spec.md}
> FOCUS: architecture-proposal
>
> You have access to:
> - Spec: {spec path}
> - Codebase exploration: specs/epic-{name}/exploration.json
>
> Produce an architectural proposal for this epic. Your proposal MUST include:
>
> 1. **Paradigm**: Name the architectural pattern you recommend — choose from:
>    layered/n-tier, hexagonal/ports-and-adapters, package-by-feature, modular
>    monolith, event-driven, CQRS, functional core + imperative shell, or mixed.
>    Justify your choice with evidence from exploration.json (cite file:line).
>
> 2. **Module map**: Name each module this epic creates or modifies.
>    For each: module name, purpose, directory location, data it owns exclusively.
>
> 3. **Seam contracts**: For each cross-story dependency you anticipate, define
>    the typed interface: type_name, field list (name + type), invariants.
>
> 4. **Boundary rules**: What may import what? State forbidden dependency edges
>    explicitly (e.g., "module A must not import from module B's internals").
>
> 5. **Assumptions**: What does this proposal depend on that could turn out wrong?
>    Be explicit — these become the adversary's primary targets.
>
> Be specific. Name files, types, modules. Do not be vague about paradigm choice.

Write the Proposer's output verbatim to `arch-debate.json` as `proposal`.
Update status to `proposed`.

---

## Phase 2: Challenge (Round 1)

Invoke the adversary: `Skill("codex:adversarial-review", args: "--wait architecture-challenge-round1")`.

The focus passed to the review must include:

> You are reviewing an architectural PROPOSAL, not code. No implementation exists yet.
>
> Epic: {spec title}
> Spec summary: {first 200 words of spec.md}
>
> Proposal:
> {arch-debate.json proposal field}
>
> YOUR ROLE: Skeptical senior architect. Challenge this proposal.
>
> DO NOT propose your own solution.
> DO NOT comment on code style, naming, or implementation details.
> DO NOT approve or endorse any part of the proposal.
> ONLY challenge.
>
> Challenge these five dimensions:
> 1. Paradigm fit — Is this paradigm right for this project's scale and codebase? What evidence from the exploration contradicts it?
> 2. Module replaceability — Can each proposed module be deleted and rewritten without touching siblings? What coupling makes this untrue?
> 3. Seam durability — Will these contracts hold when independent agents implement different stories? Where will they drift or be violated?
> 4. Parallel safety — What hidden shared state or coupling will emerge when two architects implement different stories simultaneously?
> 5. Evolution triggers — Under what concrete conditions will this architecture need a major revision within the epic's lifetime? Name a specific scenario.
>
> Return a JSON object:
> {
>   "challenged_assumptions": [...],
>   "paradigm_risks": [...],
>   "replaceability_gaps": [...],
>   "seam_risks": [...],
>   "parallel_hazards": [...],
>   "evolution_triggers": [...],
>   "blocking_concerns": ["...must be addressed before implementation begins"]
> }

Write the Codex output to `arch-debate.json` as `round1_challenge`.
Update status to `round1_challenged`.

---

## Phase 3: Respond (Round 1)

Spawn a second **Proposer** subagent (fresh context) with the original proposal and
the Round 1 challenge. Instructions:

> You made the following architectural proposal: {proposal}
>
> A skeptical reviewer raised these concerns: {round1_challenge}
>
> For each item in `blocking_concerns` and `challenged_assumptions`, do one of:
> (a) Acknowledge and revise your proposal to address it — show the revised section.
> (b) Defend with evidence from exploration.json (cite file:line) — explain why
>     the concern does not apply to this specific codebase and feature.
>
> Output a revised proposal in the same five-section format as your original.
> Append a section "Addressed Concerns" listing each blocking concern and
> your resolution (revised / defended + evidence).

Write the response to `arch-debate.json` as `round1_response`.
Update status to `round1_responded`.

---

## Phase 4: Challenge (Round 2)

Invoke the adversary again with a new focus:

> Round 2 architecture challenge for: {spec title}
>
> Original proposal: {proposal}
> Round 1 concerns: {round1_challenge}
> Proposer's response: {round1_response}
>
> YOUR ROLE: The proposer has responded. Focus Round 2 on:
> - What concerns from Round 1 survive despite the response? Why is the response insufficient?
> - What new risks does the revised proposal introduce that were not in the original?
> - Which "defended" positions depend on assumptions that will not hold in practice?
>
> DO NOT repeat concerns that were genuinely resolved by the response.
> Return the same JSON format as Round 1.

Write to `arch-debate.json` as `round2_challenge`.
Update status to `round2_challenged`.

---

## Phase 5: Synthesize

Spawn a **Synthesizer** subagent with the full debate transcript. Instructions:

> Read the complete architecture debate:
> - Original proposal: {proposal}
> - Round 1 challenge: {round1_challenge}
> - Round 1 response: {round1_response}
> - Round 2 challenge: {round2_challenge}
>
> Produce TWO documents. Write them both.
>
> ---
>
> **Document 1 — ADR** at `docs/adr/ADR-{N:03d}-{epic-slug}.md`:
>
> ```
> # ADR-{N:03d}: {Epic Title} — Architecture Decision
>
> **Status**: Accepted
> **Date**: {today}
> **Epic**: specs/epic-{epic-slug}/
>
> ## Context
> {Feature summary from spec + key codebase constraints from exploration.json
>  that shaped the decision}
>
> ## Decision
> {The chosen approach: paradigm, module map, seam contracts, boundary rules —
>  specific enough to constrain implementation}
>
> ## Rationale
> {Why this approach over the alternatives, with specific reference to
>  debate rounds — what was challenged and how it was resolved}
>
> ## Alternatives Considered
> | Alternative | Why Rejected |
> |---|---|
>
> ## Consequences
> **Positive**: {benefits}
> **Negative / Trade-offs**: {accepted costs}
> **Accepted Risks**: {concerns from Round 2 that were not fully resolved —
>  these are known and accepted, not ignored}
>
> ## Evolution Triggers
> Conditions that would require reopening this ADR:
> {from round2_challenge evolution_triggers that were not fully resolved}
>
> ## Debate Summary
> - Round 1 blocking concerns: N; resolved: M; accepted: N-M
> - Round 2 residual concerns: K; accepted as known risk: K
> ```
>
> ---
>
> **Document 2 — architecture.md** at `specs/epic-{epic-slug}/architecture.md`:
>
> This document is consumed by agents — write directives, not narrative.
> Agents read this file before every story. Make it scannable.
>
> ```
> # Epic Architecture: {epic-slug}
>
> **ADR**: docs/adr/ADR-{N:03d}-{epic-slug}.md
> **Status**: current
> **Last updated**: {today}
>
> ## Paradigm
> {Named paradigm} — {one-sentence justification}
>
> ## Module Map
> | Module | Purpose | Location | Owned Data |
> |---|---|---|---|
>
> ## Seam Contracts
> For each cross-story seam:
> ### {SeamTypeName}
> | Field | Type | Optional |
> |---|---|---|
> **Invariants**: {bulleted list}
> **Produced by**: story {id} | **Consumed by**: story {id}
>
> ## Boundary Rules
> **Allowed dependency edges:**
> - {module A} → {module B} (through SeamTypeName)
>
> **Forbidden:**
> - {module X} must not import from {module Y}'s internals
>
> ## Implementation Constraints
> Numbered list — integration-architect subagents must comply with all of these:
> 1. ...
>
> ## Open Questions / Accepted Risks
> {Concerns from Round 2 that are known and accepted — so verifiers can watch for them}
> ```

After the Synthesizer writes both files, update `arch-debate.json`:
- `synthesized_at`: current timestamp
- `adr_path`: `docs/adr/ADR-{N:03d}-{epic-slug}.md`
- `architecture_path`: `specs/epic-{epic-slug}/architecture.md`
- `status`: `synthesized`

---

## Return

Report to the caller (the feature workflow lead or the user):

```
ARCH_DEBATE_COMPLETE

ADR: {adr_path} (ADR-{N:03d})
Architecture: {architecture_path}
Paradigm: {named paradigm}
Modules: {count} declared
Seam contracts: {count} typed
Accepted risks: {count from round2 residuals}

Open questions requiring attention:
- {list if any, else "none"}
```
