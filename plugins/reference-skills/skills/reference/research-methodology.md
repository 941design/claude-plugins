# Research Methodology

How to study a GitHub repository systematically. Follow the tiered approach —
each tier builds on the previous one and adds detail. Stop when you have enough
to answer the current question or fulfill the current refresh scope.

## Tier 1: Overview (always do this)

Fetch the **README** and **repository metadata** (description, topics, language
breakdown). From these, extract:

- **Purpose** — what problem does this project solve?
- **Tech stack** — primary language, frameworks, key dependencies
- **Maturity signals** — stars, latest commit date, release cadence
- **Entry points** — where docs point you for getting started

If the README references dedicated documentation (docs site, wiki, `/docs`
directory), note those URLs for deeper tiers.

## Tier 2: Structure (do for architecture + patterns focus)

Fetch the **repository tree** (via GitHub API) and identify:

- **Top-level layout** — monorepo vs single package, src/ vs lib/, test
  locations
- **Module boundaries** — how is the code organized into logical units?
- **Public surface** — which directories/files constitute the public API?
  Look for `index.ts`, `mod.rs`, `__init__.py`, `exports` in package.json
- **Configuration** — build tools, CI config, linting, formatting
- **Key files** — README per package (monorepos), CHANGELOG, CONTRIBUTING

For monorepos, identify the packages and their dependency relationships. Focus
on packages most relevant to the consumer project.

## Tier 3: API Surface (do for api-surface focus)

Selectively fetch **key source files** identified in Tier 2:

- Public type definitions, interfaces, exported functions
- Configuration schemas and option types
- Event/message types and protocol definitions
- CLI argument parsers and command structures

**Do NOT fetch every file.** Target files that define the public contract:
- TypeScript: look for `index.ts`, `types.ts`, files re-exported from barrel
- Rust: `lib.rs`, `mod.rs`, public modules
- Python: `__init__.py`, type stubs
- Go: exported types in package-level files

Record: function signatures, type definitions, configuration options, and
documented constraints.

## Tier 4: Deep Dive (do selectively, only when needed)

For specific questions or implementation recipes, fetch individual source files:

- Implementation of a specific feature or pattern
- Test files that demonstrate usage patterns
- Example code or sample applications
- Internal architecture documentation

**Stopping criteria for deep dives:**
- You have a concrete code example that answers the question
- You've traced the call chain enough to understand the pattern
- Further reading would only yield implementation details, not insight

## Monorepo Handling

When encountering a monorepo:

1. Identify the package manager (npm workspaces, Cargo workspace, Go modules)
2. List all packages with their descriptions
3. Determine which packages are relevant to the consumer project
4. Treat each relevant package as a mini-repo: apply tiers 1-3 to it
5. Document inter-package dependencies

## Time Budget

During a refresh cycle, spend roughly:
- 30% on Tier 1-2 (overview + structure) — this grounds everything
- 50% on Tier 3 (API surface) — this is the highest-value knowledge
- 20% on Tier 4 (deep dives) — only for specific gaps

If a repo is very large, prefer breadth over depth — a complete Tier 2 map
is more useful than a partial Tier 4 deep dive.

## What Makes Good Knowledge

Good reference knowledge is:
- **Actionable** — a developer can use it to make decisions or write code
- **Comparative** — it highlights how this repo's approach differs from others
- **Concrete** — includes actual type names, function signatures, file paths
- **Current** — timestamped so staleness is visible

Bad reference knowledge is:
- Marketing copy from the README (paraphrased back)
- Exhaustive API listings with no context on usage patterns
- Opinions without evidence from the source code
