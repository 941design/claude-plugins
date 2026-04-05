# Cross-Project Analysis

How to identify and document patterns that span multiple reference repos.

## When to Perform Cross-Project Analysis

Run after individual repo updates, not during. Cross-project analysis
requires up-to-date knowledge of each repo first.

**Do analyze when:**
- Two or more repos solve a similar problem differently
- The user asks a comparative question ("how do X and Y handle Z?")
- A pattern appears in 2+ repos — it's likely a domain convention
- Repos depend on each other or compete for the same use case

**Skip when:**
- Only one reference repo exists
- Repos are in unrelated domains
- Knowledge for one or more repos is too shallow (Tier 1 only)

## What Constitutes a Shared Pattern

A shared pattern is a design choice or implementation approach that appears
in multiple reference repos. It may be identical or take different forms:

### Identical patterns
Same approach, same structure. Document once, note which repos use it.
Example: both repos use event-driven architecture with a central event bus.

### Convergent patterns
Different implementations of the same concept. Document the concept and
compare implementations.
Example: both repos handle authentication, but one uses JWT and the other
uses sessions.

### Divergent approaches
Same problem, deliberately different solutions. Document the trade-offs.
Example: one repo uses a relational DB, the other uses event sourcing.

## Comparison Dimensions

When comparing how repos handle a concern, consider:

| Dimension | What to capture |
|-----------|----------------|
| **API design** | Naming conventions, parameter styles, return types |
| **Error handling** | Error types, propagation strategy, user-facing messages |
| **State management** | Where state lives, how it flows, persistence |
| **Extensibility** | Plugin systems, hooks, middleware, event listeners |
| **Testing** | Test frameworks, coverage approach, test data strategy |
| **Configuration** | Config format, defaults, validation, environment handling |
| **Performance** | Caching strategy, lazy loading, batching, concurrency model |

## Writing Good Comparisons

Structure comparisons as decision-support tools, not inventories:

**Good:** "For event filtering, applesauce uses reactive observables that
re-evaluate on subscription change, while nostr-tools uses static filter
objects passed to subscription calls. The reactive approach is better when
filters change frequently; the static approach is simpler for one-shot
queries."

**Bad:** "applesauce uses observables. nostr-tools uses filter objects."
(No decision-support value.)

## Maintaining `_cross-project/`

### `shared-patterns.md`
- Group by domain concept (auth, data flow, error handling), not by repo
- Each pattern entry: description, which repos, variations, relevance
- Remove patterns when they become too stale or repos are removed from config

### `comparison.md`
- Start with a summary table (repos as columns, aspects as rows)
- Follow with detailed per-topic comparisons
- Include code examples from each repo when they illustrate the difference
- Always state which version/commit the comparison is based on

## Connecting to the Consumer Project

Cross-project analysis is only valuable when it helps the consumer project.
Always ask: "how does this comparison help the developer working in THIS
project?" If the answer isn't clear, the comparison isn't worth maintaining.

Ways cross-project insights apply:
- Choosing between approaches: "repo A does X, repo B does Y — here's which
  fits your project better and why"
- Adopting patterns: "all reference repos handle this with Z — consider
  adopting this convention"
- Avoiding pitfalls: "repo A tried approach X and moved away from it in
  v2.0 — here's why"
