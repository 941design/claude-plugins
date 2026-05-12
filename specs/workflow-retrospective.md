# /base:feature workflow — retrospective and improvement proposals

Addressed to: maintainers of the `base:feature` skill and its supporting
agent infrastructure (codex-companion, integration-architect, verifier).

Source: the `nostr-events` library epic (2026-05-03) — 15 stories,
63 ACs, greenfield TypeScript library, 4-agent team (planner + 2
architects + verifier). A complete, non-escalated run.

---

## 1. Codex adversarial-review gate is non-functional on greenfield branches

**What happened.** The last-mile Codex adversarial-review gate was
waived for every story in the epic (9 stories before token exhaustion,
remainder skipped by policy). Root cause: the codex-companion script
bundles the entire working tree — tracked and *untracked* files — when
preparing the review payload. On a fresh branch where the spec
directory (`specs/`, 1.5 MB of negotiation rounds, refactoring plans,
acknowledgments) is untracked, the payload consistently exceeded the
1 MB input limit.

**Impact.** The "last-mile external check" quality gate was never
applied. Given that primary verification (VQ examination + independent
test re-run) caught all real issues anyway, this was not a correctness
problem in this epic — but the gate existed for a reason and should
actually run.

**Proposed fixes (in priority order):**

1. *Exclude non-source paths from the bundle.* Add a
   `.codexignore`-style exclusion list to the companion script. Default
   exclusions: `specs/`, `negotiation/`, `refactoring-plans/`,
   `node_modules/`, `dist/`, `coverage/`. Anything matching these
   prefixes should be omitted from the untracked-file payload regardless
   of `.gitignore` status. This fix resolves the issue for any project
   that tracks a heavy spec directory.

2. *Scope the review to story-changed files, not the whole tree.*
   The integration-architect already knows which files it created or
   modified (they appear in `result.json#files_created` and
   `files_modified`). Pass that list to the codex-companion as the
   review scope instead of the working tree root. This makes the payload
   proportional to the story size rather than the repo size.

3. *Tiered review by story category.* Scaffold stories (empty stubs,
   re-exports, type-only files) have no production logic to attack.
   Adversarial review on them is wasteful and the return S0 episode
   demonstrated it can loop on test-mechanism bypass vectors rather than
   actual AC violations. Add a `story_category` field to stories.json
   (`scaffold | types | feature | ci-gates`) and skip the adversarial
   review for `scaffold` and `types` categories. Reserve the token
   budget for `feature` stories (signers, gift-wrap, transport
   adapters).

---

## 2. Task system and result.json are conflated — one authoritative source needed

**What happened.** The task system tracks implementation completion
("architect marked the story done"). `result.json#final_outcome:
accepted` tracks verifier acceptance. These are different events that
often happen turns apart. The lead (team-lead agent) updated
`epic-state.json#completed_stories` based on the task system and had
to roll back twice when the verifier flagged the mismatch.

**Proposed fix.** Document explicitly in the base:feature skill
instructions:

> **Completion authority:** A story is complete when and only when
> `{story_dir}/result.json#final_outcome === "accepted"`. The task
> system reflects architect intent; it is not authoritative. The lead
> MUST NOT update `epic-state.json#completed_stories` until the
> verifier has written acceptance to `result.json`.

Optionally, the verifier could be the sole writer of
`completed_stories` in `epic-state.json`, removing the lead's need to
track this at all.

---

## 3. Verifier missed handoffs from two concurrent architects

**What happened.** When both architects were active and submitting
stories in the same turn window, the verifier missed S9 (transport-
types) and S13 (nip19-and-branded). Both were eventually caught only
when the lead explicitly asked the verifier about their queue.

**Root cause.** The verifier processed one architect's message per
turn and did not maintain an explicit queue. The second architect's
submission arrived during a turn and was silently lost.

**Proposed fixes:**

1. *Require explicit "story queued" acknowledgment.* When the verifier
   receives a "story ready" message, they should immediately reply
   with a confirmation ("S13 received, queued after S9") so the
   architect knows the handoff succeeded. Silent receipt is not
   sufficient.

2. *Verifier queue in a file.* The verifier should maintain a
   `specs/epic-{name}/verifier-queue.json` listing stories received,
   under-review, and accepted. The lead can inspect this file to detect
   dropped handoffs without asking. Schema:
   ```json
   { "queue": [{"story_id": "S9", "received_at": "...", "status": "pending|reviewing|accepted"}] }
   ```

3. *Architect dual-message protocol.* The base:feature skill should
   require that architects send two messages on story completion:
   (a) to the **verifier**: "Story {id} ready for review — {artifact
   path}"
   (b) to the **lead**: "Story {id} implementation done; deps now
   unblocked: {list of downstream story IDs}"
   
   Currently only the verifier message is specified. The lead message
   is what enables timely parallel scheduling.

---

## 4. Verifier state writeback drift (acceptance reported but not written)

**What happened.** The verifier correctly accepted S9 in a message but
did not write `final_outcome: accepted` to `result.json`, update
`stories.json`, or update `epic-state.json`. This happened twice (S9
and S13). The verifier self-diagnosed it as "I wrote the acceptance
message but forgot the state files."

**Proposed fix.** Reorder the verifier's acceptance sequence in the
skill instructions from:

> "Update result.json… message lead"

to a stricter atomic pattern:

> 1. Write all state files (`result.json`, `stories.json`,
>    `epic-state.json`) — **do this first, before sending any message**.
> 2. Only after all writes succeed, send the acceptance message to the
>    lead.
>
> *Rationale:* A message without a state write is a ghost — it reports
> completion that can't be recovered from on crash or compaction. A
> state write without a message is merely delayed — the lead can query
> for it. Writes first, messages second.

The verifier adopted this pattern voluntarily mid-epic and had no
further writeback issues.

---

## 5. Empty story directory confusion

**What happened.** Architect-1 created `S11-transport-simple-pool/`
(mkdir) while planning to start the story, then shifted to other work.
The empty directory was then indistinguishable from a crashed
implementation mid-flight, and the lead had to inspect it to determine
no work had been done.

**Proposed fix.** Add to the architect role description:

> Do NOT create the `{story_id}-{name}/` directory until you are about
> to write `baseline.json`. An empty story directory is ambiguous — it
> cannot be distinguished from a partially-completed story on crash
> recovery. Create the directory and write `baseline.json` as a single
> atomic step.

---

## 6. Odd/even architect split creates false parallelism on sequential dependency chains

**What happened.** The odd/even story split (architect-1 takes odd IDs,
architect-2 takes even IDs) was specified as the load-balancing
heuristic for 4+ story epics. In practice, the dependency graph
(S0→S1→S2→S5→S6→S4→...) was mostly sequential. Architect-2 had
several multi-turn idle gaps waiting for architect-1's odd stories to
complete, and the odd/even boundary had to be broken when architect-2
ran out of unblocked even stories (S13 was assigned across the
boundary).

**Proposed fix.** Replace the static odd/even split with a dynamic
assignment rule:

> The lead assigns stories at the moment they become unblocked (all
> deps satisfied), prioritising story_order, assigning to whichever
> architect is idle. If both are idle, prefer the architect whose
> recently completed story shares the most imports/interfaces with the
> next story. The odd/even heuristic is only a tiebreaker when both
> architects become free simultaneously.

This makes the assignment responsive to the actual dependency graph
rather than the ID parity.

---

## 7. S0 adversarial review loop — category-aware gate threshold

**What happened.** The adversarial review on S0 (scaffold — all empty
stubs) ran 4 remediation rounds, each finding a new bypass vector for
the AC-INV-6 getter trap test. The test itself is a regression guard
for when real implementations land; the stubs it was testing are
trivially compliant. The lead intervened at round 4 to reframe the
findings as LOW severity.

**Proposed fix** (related to proposal 1 above, item 3):

For `scaffold` and `types` category stories, the adversarial review
should be either skipped entirely or capped at severity `medium`
findings being blocking (not `high`). The HIGH threshold should be
reserved for `feature` category stories where the implementation
complexity justifies the scrutiny.

Additionally, the lead's intervention protocol could be proactive:

> If an adversarial review HIGH finding targets the **test harness
> mechanism** (trap design, mock fidelity, fixture construction) rather
> than the **production code surface** (actual exports, runtime
> behavior), the lead should reframe the finding as LOW and proceed. A
> HIGH finding against a trap that detects whether `export {};` accesses
> browser globals is not a compliance failure.

---

## 8. Token budget awareness

**What happened.** Codex token credit was exhausted with 6 stories
remaining (S12, S8, S14, plus S9/S13 retro and S7 which finished just
before exhaustion). The first story (S0) consumed the most tokens — 4
adversarial review rounds against trivial stubs — which is the inverse
of where adversarial review value concentrates.

**Proposed guidance for future epics:**

> - Reserve adversarial review for `feature` category stories. Do not
>   run it on `scaffold`, `types`, or `re-export` category stories.
> - If total story count exceeds 10, consider setting `adversarial_review_budget`
>   (max stories to review) in `epic-state.json` and declining the gate
>   for stories beyond the budget, starting from the lowest-risk ones.
> - When the lead declares token exhaustion mid-epic, the verifier
>   should record `codex_adversarial_review.status = 'skipped-lead-policy'`
>   (not 'waived') in verification.json so the audit trail clearly
>   distinguishes a deliberate policy skip from an infrastructure failure.
>   This was adopted correctly in this epic.

---

## Summary of proposed changes

| # | Change | Location | Effort |
|---|--------|----------|--------|
| 1a | Exclude `specs/`, `negotiation/`, `dist/` from Codex bundle | codex-companion script | Low |
| 1b | Story-scoped file list for Codex review | codex-companion + integration-architect | Medium |
| 1c | Story-category field + adversarial skip for scaffold/types | stories.json schema + verifier instructions | Low |
| 2 | Document result.json as sole completion authority | base:feature skill instructions | Low |
| 3a | Verifier queue acknowledgment reply | verifier role description | Low |
| 3b | `verifier-queue.json` sidecar file | verifier role description + crash-recovery section | Medium |
| 3c | Architect dual-message protocol | architect role description | Low |
| 4 | Write-first, message-second acceptance protocol | verifier role description | Low |
| 5 | Prohibit empty story directories | architect role description | Low |
| 6 | Dynamic story assignment replacing odd/even split | base:feature coordination section | Medium |
| 7 | Category-aware adversarial review threshold | verifier role description | Low |
| 8 | Token budget guidance | base:feature skill instructions (new section) | Low |
