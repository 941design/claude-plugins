# Project Backlog

Project-level coordination state. Read by `/base:orient`; written by humans and
by `base:project-curator` (advisory — proposes, lead writes).

The four artifacts of project meta-state:

| Artifact | Captures | Lifecycle |
|---|---|---|
| `specs/epic-*/` | What we built (behavior) | Living; amended on resolved findings |
| `docs/adr/` | Why we chose this shape | Immutable once Accepted; superseded |
| `BACKLOG.md ## Findings` | What's open and undecided | Working set, soft cap ~15 |
| `BACKLOG.md ## Archive` | What we considered and rejected | Append-only, never expires |

Git history is the long-term audit trail underneath all four.

---

## Epics

One bullet per `specs/epic-*/` directory. Status is one of `PLANNED`,
`IN_PROGRESS`, `DONE`, `ESCALATED`. The next-action hint tells a returning
human or agent how to act on this epic.

<!-- format:
- specs/epic-<slug>/ — <STATUS> — <next action>
-->

- _no epics yet_

---

## Findings

The working set of open items that don't (yet) justify their own epic. Soft
cap **~15 entries** — when the list grows past that, `/base:orient` will nag
you to resolve, promote, or delete.

Each finding MUST be file-anchored when applicable. A finding without a
`path` or `path:line` reference is half a thought; resolve it or delete it.

<!-- format:
- [<type>] <anchor> — <text> (YYYY-MM-DD)
where <type> ∈ { bug | chore | question | observation }
and <anchor> is `path[:line]` or `-` when no specific anchor exists
-->

- _no findings yet_

### Resolution paths

When a finding leaves this section, it goes to **exactly one** of:

- **`[done→spec:<spec-path>]`** — behavior change. The named spec was
  amended (see its `## Amendments` section) or a new spec was created. The
  spec is the durable record; **no archive entry is written**.
- **`[promoted→<spec-path>]`** — finding became a full epic. The new
  `specs/epic-*/` directory appears under `## Epics` above; **no archive
  entry is written**.
- **`[done-mechanical]`** — typo, dependency bump, formatting, or pure
  refactor with no externally-observable behavior change. Just commit; **no
  archive entry, no spec amendment**. Test: could a future reader of any
  spec notice the change is missing? If yes, it's not mechanical.
- **`[rejected]`** — we considered, said no. Goes to `## Archive` below
  with a reason. **Never expires.**

If you cannot honestly tag a removal with one of the above, the finding
stays in `## Findings` and ages visibly.

---

## Archive

**Rejected items only.** Append-only. Never pruned. This is the project's
durable record of paths not taken — the answer to "did we ever consider X?"

The high-value oscillation signal lives here: when a finding reappears that
matches an archived rejection, `/base:orient` flags it loudly so the
re-decision is conscious, not accidental. After ~3 rejections of related
style, the curator may propose promoting the cluster to an ADR (see
`docs/adr/`); the archive entries then carry a `→ ADR-NNN` pointer but are
not deleted.

<!-- format:
- YYYY-MM-DD — <text> — <reason>
- YYYY-MM-DD — <text> — <reason> [→ ADR-NNN]
-->

- _no rejections yet_
