---
name: arch-debate
description: |-
  Epic-level and project-wide architecture debate orchestrator. Produces a living
  architecture.md and an ADR by running a structured two-round debate between a
  Claude Proposer subagent and a Codex adversary, then synthesizing both documents.

  TRIGGER when: base:feature invokes this skill (always via the arch_debate: true
  spec flag); user invokes /base:arch-debate with no arguments for a project-wide
  architecture review; user provides a spec file for a feature-scoped debate;
  team lead needs to re-examine architecture mid-epic after a major pivot or
  escalation that revealed architectural contradictions.
  Agent self-detected uncertainty about the right paradigm or module boundaries
  for a feature is sufficient to trigger.

  SKIP when: architecture.md already exists and no re-analysis is requested;
  the change is purely cosmetic or configuration-only with no structural decisions.
argument-hint: "[<spec-file>]"
allowed-tools: Task, Read, Write, Bash, Skill
model: opus
---

# Architecture Debate Orchestrator

You coordinate a structured two-round architecture debate. Your job is to produce
two durable artifacts:

1. An ADR at `docs/adr/` — the decision record (history + rationale)
2. An architecture document — the operational document (paradigm, modules, boundaries)

---

## Mode Detection

Determine mode from `$ARGUMENTS` before doing anything else:

```
IF $ARGUMENTS is empty                     → mode = PROJECT
IF $ARGUMENTS ends in .md                  → mode = EPIC
                                             spec  = $ARGUMENTS
                                             epic  = basename of parent directory
IF $ARGUMENTS is a directory path          → mode = EPIC
                                             spec  = {$ARGUMENTS}/spec.md
                                             epic  = basename of $ARGUMENTS
```

---

## Inputs

Count existing ADRs to assign the next number:
```bash
ls docs/adr/*.md 2>/dev/null | wc -l   # N = result + 1
```
Create `docs/adr/` if it does not exist.

### PROJECT mode

No spec. The codebase itself is the subject.

Spawn 3 `code-explorer` subagents **in parallel**:
- Focus `architecture` — full paradigm classification, all modules, dependency direction
- Focus `testing-and-conventions` — what patterns exist, what's enforced, what has drifted
- Focus `similar-features` — any existing architecture docs, ADRs, READMEs, diagrams

Merge findings and write `docs/arch-debate-exploration.json`.
State file: `docs/arch-debate.json`
ADR path: `docs/adr/ADR-{N:03d}-project-architecture.md`
Architecture doc: `docs/architecture.md`

### EPIC mode

Read:
- The spec at the resolved spec path
- `specs/epic-{name}/exploration.json` — codebase findings from code-explorer subagents

If `exploration.json` does not exist, spawn two `code-explorer` subagents in parallel:
- Focus `architecture` (paradigm classification + module map)
- Focus `similar-features` (existing patterns for reuse)

Merge findings and write `specs/epic-{name}/exploration.json`.
State file: `specs/epic-{name}/arch-debate.json`
ADR path: `docs/adr/ADR-{N:03d}-{epic-slug}.md`
Architecture doc: `specs/epic-{name}/architecture.md`

---

## State Tracking

Maintain the state file throughout. Update after each phase:

```json
{
  "status": "pending|proposed|round1_challenged|round1_responded|round2_challenged|synthesized",
  "mode": "project|epic",
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

If the state file already exists with `status != "synthesized"`, resume from
the last completed phase rather than restarting.

---

## Phase 1: Propose

Spawn a `code-explorer` subagent as the **Proposer**.

### PROJECT mode Proposer prompt

> SUBJECT: {project root directory name}
> FOCUS: architecture-assessment
>
> You have access to:
> - Exploration findings: docs/arch-debate-exploration.json
>
> Produce an honest architectural assessment of this project as it exists today.
> Your assessment MUST include five sections:
>
> 1. **Current paradigm**: Name the architectural pattern actually in use today —
>    choose from: layered/n-tier, hexagonal/ports-and-adapters, package-by-feature,
>    modular monolith, event-driven, CQRS, functional core + imperative shell, or
>    mixed. Support with evidence (cite file:line). If the stated and actual paradigm
>    differ, name both.
>
> 2. **Module map**: What modules/packages exist today? For each: name, purpose,
>    location, what data it owns, where its boundaries are unclear or contested.
>
> 3. **Boundary violations**: Where are module boundaries being crossed today?
>    Name specific files and import paths. Distinguish: intentional shortcuts vs.
>    unintentional drift vs. missing abstraction.
>
> 4. **Fitness concerns**: What in the current architecture is working against the
>    project — coupling that prevents change, replaceability failures, data ownership
>    overlaps, seams that exist only in tests? Be specific, not generic.
>
> 5. **Assumptions**: What does this assessment depend on that might be misread?
>    What would change the picture if it turned out to be wrong?
>
> Be specific. Name files, types, modules. Cite file:line for every claim.

### EPIC mode Proposer prompt

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

Write the Proposer's output verbatim to the state file as `proposal`.
Update status to `proposed`.

---

## Phase 2: Challenge (Round 1)

Invoke: `Skill("codex:adversarial-review", args: "--wait architecture-challenge-round1")`.

### PROJECT mode adversary focus

> You are reviewing an architectural ASSESSMENT of an existing codebase, not a
> proposed design for new code.
>
> Project: {project root directory name}
>
> Assessment:
> {state file proposal field}
>
> YOUR ROLE: Skeptical senior architect. Challenge this assessment.
>
> DO NOT propose your own solution.
> DO NOT comment on code style, naming, or implementation details.
> DO NOT approve or endorse any part of the assessment.
> ONLY challenge.
>
> Challenge these five dimensions:
> 1. Paradigm accuracy — Is the named paradigm what's actually in use, or is it
>    wishful thinking? What evidence contradicts the assessment?
> 2. Module replaceability — Can each described module be deleted and rewritten
>    without touching siblings? Where does the assessment understate the coupling?
> 3. Drift detection — Where is the described architecture already diverging from
>    the actual code in ways the assessment missed? How will that get worse?
> 4. Incremental risk — What is the cost and risk of addressing the fitness concerns
>    named? What breaks if you try to fix the violations identified?
> 5. Evolution triggers — Under what concrete conditions will the assessment become
>    obsolete? What one change to the codebase would require a complete re-evaluation?
>
> Return a JSON object:
> {
>   "challenged_assumptions": [...],
>   "paradigm_risks": [...],
>   "replaceability_gaps": [...],
>   "drift_findings": [...],
>   "incremental_risks": [...],
>   "evolution_triggers": [...],
>   "blocking_concerns": ["...must be addressed or acknowledged before this assessment is actionable"]
> }

### EPIC mode adversary focus

> You are reviewing an architectural PROPOSAL, not code. No implementation exists yet.
>
> Epic: {spec title}
> Spec summary: {first 200 words of spec.md}
>
> Proposal:
> {state file proposal field}
>
> YOUR ROLE: Skeptical senior architect. Challenge this proposal.
>
> DO NOT propose your own solution.
> DO NOT comment on code style, naming, or implementation details.
> DO NOT approve or endorse any part of the proposal.
> ONLY challenge.
>
> Challenge these five dimensions:
> 1. Paradigm fit — Is this paradigm right for this project's scale and codebase?
>    What evidence from the exploration contradicts it?
> 2. Module replaceability — Can each proposed module be deleted and rewritten
>    without touching siblings? What coupling makes this untrue?
> 3. Seam durability — Will these contracts hold when independent agents implement
>    different stories? Where will they drift or be violated?
> 4. Parallel safety — What hidden shared state or coupling will emerge when two
>    architects implement different stories simultaneously?
> 5. Evolution triggers — Under what concrete conditions will this architecture need
>    a major revision within the epic's lifetime? Name a specific scenario.
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

Write the Codex output to the state file as `round1_challenge`.
Update status to `round1_challenged`.

---

## Phase 3: Respond (Round 1)

Spawn a second **Proposer** subagent (fresh context) with the original proposal/assessment
and the Round 1 challenge:

> You produced the following architectural {proposal|assessment}: {state file proposal}
>
> A skeptical reviewer raised these concerns: {state file round1_challenge}
>
> For each item in `blocking_concerns` and `challenged_assumptions`, do one of:
> (a) Acknowledge and revise your {proposal|assessment} to address it — show the revised section.
> (b) Defend with evidence (cite file:line) — explain why the concern does not apply
>     to this specific codebase.
>
> Output a revised {proposal|assessment} in the same five-section format.
> Append a section "Addressed Concerns" listing each blocking concern and your
> resolution (revised / defended + evidence).

Write the response to the state file as `round1_response`.
Update status to `round1_responded`.

---

## Phase 4: Challenge (Round 2)

Invoke the adversary again. Same focus structure as Round 1, extended with:

> Round 2 challenge.
>
> Original {proposal|assessment}: {state file proposal}
> Round 1 concerns: {state file round1_challenge}
> Proposer's response: {state file round1_response}
>
> YOUR ROLE: Focus Round 2 on:
> - What concerns from Round 1 survive despite the response? Why is the response insufficient?
> - What new risks does the revised {proposal|assessment} introduce?
> - Which "defended" positions depend on assumptions that will not hold in practice?
>
> DO NOT repeat concerns that were genuinely resolved by the response.
> Return the same JSON format as Round 1.

Write to the state file as `round2_challenge`.
Update status to `round2_challenged`.

---

## Phase 5: Synthesize

Spawn a **Synthesizer** subagent with the full debate transcript. Instructions:

> Read the complete architecture debate:
> - Original {proposal|assessment}: {state file proposal}
> - Round 1 challenge: {state file round1_challenge}
> - Round 1 response: {state file round1_response}
> - Round 2 challenge: {state file round2_challenge}
>
> Produce TWO documents. Write them both.

### PROJECT mode Synthesizer output

> **Document 1 — ADR** at `docs/adr/ADR-{N:03d}-project-architecture.md`:
>
> # ADR-{N:03d}: Project Architecture Review
>
> **Status**: Accepted
> **Date**: {today}
> **Scope**: Project-wide
>
> ## Context
> {What prompted this review + key findings from exploration}
>
> ## Current State
> {The architecture as it exists today: paradigm, modules, known violations}
>
> ## Assessment
> {The fitness concerns identified: what's working against the project and why}
>
> ## Recommended Changes
> {Prioritised list with rationale from the debate — what to fix and in what order}
>
> ## Alternatives Considered
> | Alternative | Why Deprioritised |
> |---|---|
>
> ## Consequences
> **Positive**: {benefits of acting on the recommendations}
> **Negative / Trade-offs**: {accepted costs}
> **Accepted Risks**: {concerns from Round 2 that are known and accepted}
>
> ## Evolution Triggers
> Conditions that would require reopening this ADR:
> {from round2_challenge evolution_triggers that were not fully resolved}
>
> ## Debate Summary
> - Round 1 blocking concerns: N; resolved: M; accepted: N-M
> - Round 2 residual concerns: K; accepted as known risk: K
>
> ---
>
> **Document 2 — architecture.md** at `docs/architecture.md`:
>
> This document is consumed by developers and agents. Write directives, not narrative.
>
> # Project Architecture
>
> **ADR**: docs/adr/ADR-{N:03d}-project-architecture.md
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
> ## Boundary Rules
> **Allowed dependency edges:**
> - {module A} → {module B}
>
> **Forbidden:**
> - {module X} must not import from {module Y}'s internals
>
> ## Current Violations
> Known boundary crossings and drift — tracked here so they can be resolved incrementally:
> - {violation}: {file:line} — {why it exists, what to do about it}
>
> ## Recommended Changes
> Prioritised list for bringing the codebase into alignment:
> 1. ...
>
> ## Open Questions / Accepted Risks
> {Concerns from Round 2 that are known and accepted}

### EPIC mode Synthesizer output

> **Document 1 — ADR** at `docs/adr/ADR-{N:03d}-{epic-slug}.md`:
>
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
> **Accepted Risks**: {concerns from Round 2 that were not fully resolved}
>
> ## Evolution Triggers
> Conditions that would require reopening this ADR:
> {from round2_challenge evolution_triggers that were not fully resolved}
>
> ## Debate Summary
> - Round 1 blocking concerns: N; resolved: M; accepted: N-M
> - Round 2 residual concerns: K; accepted as known risk: K
>
> ---
>
> **Document 2 — architecture.md** at `specs/epic-{epic-slug}/architecture.md`:
>
> This document is consumed by agents — write directives, not narrative.
> Agents read this file before every story. Make it scannable.
>
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

After the Synthesizer writes both files, update the state file:
- `synthesized_at`: current timestamp
- `adr_path`: the ADR path
- `architecture_path`: the architecture doc path
- `status`: `synthesized`

---

## Return

```
{PROJECT ARCHITECTURE REVIEW | EPIC ARCHITECTURE DEBATE}

ADR: {adr_path} (ADR-{N:03d})
Architecture: {architecture_path}
Paradigm: {named paradigm}
Modules: {count} declared
Accepted risks: {count from round2 residuals}

Open questions requiring attention:
- {list if any, else "none"}
```
