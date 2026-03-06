# nostr-skills

Implementation advisor for the [Marmot Protocol](https://github.com/marmot-protocol/marmot)
— end-to-end encrypted group messaging combining
[MLS (RFC 9420)](https://messaginglayersecurity.rocks/) with
[Nostr](https://github.com/nostr-protocol/nostr). Helps build applications
using the existing libraries, not reimplement the protocol from scratch.

## Installation

```bash
/plugin marketplace add 941design/claude-plugins
/plugin install nostr-skills@941design
```

## Skills

### `/nostr-skills:marmot [question]`

Advisory skill. Answers questions about using:

- [MDK](https://github.com/parres-hq/mdk) (Rust SDK) — structs, traits,
  methods, storage backends
- [marmot-ts](https://github.com/marmot-protocol/marmot-ts) (TypeScript) —
  classes, interfaces, async patterns
- [wn-tui](https://github.com/marmot-protocol/wn-tui) / wn CLI / wnd daemon —
  subprocess integration, IPC protocol
- [WhiteNoise](https://www.whitenoise.chat/) architecture,
  [Blossom](https://github.com/hzrd149/blossom) media, group lifecycle

**Auto-invokes** when Claude detects Marmot-related questions. Runs in an
isolated agent context with persistent memory.

**Self-updating:** Checks documentation freshness on each invocation. If
supporting documents are older than 7 days, automatically fetches the latest
from all primary repositories before answering.

### `/nostr-skills:marmot-update [topic]`

Manual maintenance skill. Fetches the latest from all Marmot Protocol
repositories and updates agent memory with new findings.

```bash
# Full update
/nostr-skills:marmot-update

# Targeted update
/nostr-skills:marmot-update mdk-reference
```

## Agent: marmot-researcher

Custom agent with user-scoped persistent memory
(`~/.claude/agent-memory/marmot-researcher/`). Accumulates knowledge across
sessions — API patterns, common pitfalls, version tracking, and changelog.

Both skills run in this agent's context, sharing the same memory.

### First Run

Agent memory is user-scoped and lives outside the plugin directory at
`~/.claude/agent-memory/marmot-researcher/`. Plugin files are never modified
at runtime — all dynamic state lives in agent memory.

On first invocation, the agent detects that its memory is empty and
automatically runs a full knowledge refresh:

1. Fetches latest content from all primary repositories
2. Populates agent memory with:
   - `MEMORY.md` — index with version numbers, repo map, fetch timestamp
   - `api-patterns.md` — cross-library usage patterns
   - `gotchas.md` — common pitfalls
   - `changelog.md` — version snapshots
   - `corrections.md` — anything that differs from shipped supporting docs

This adds latency to the first invocation but requires no manual setup.
Subsequent invocations reuse cached memory and only refresh when stale
(>7 days). When memory and supporting docs conflict, the agent trusts its
memory (latest fetch) over the shipped docs.

To force a rebuild at any time:

```bash
/nostr-skills:marmot-update
```

## Supporting Documents

Six read-only reference files ship with the plugin and provide baseline
knowledge. These are updated only through new plugin releases — the agent
never modifies them at runtime:

| File | Content |
|---|---|
| `protocol-overview.md` | Goals, security properties, cryptographic parameters |
| `mip-specifications.md` | MIP-00 through MIP-05 specification summaries |
| `mdk-reference.md` | Rust MDK API — structs, traits, enums, methods |
| `marmot-ts-reference.md` | TypeScript API — classes, interfaces, types |
| `architecture.md` | Layer diagrams, data flows, IPC, epoch rollback |
| `ecosystem.md` | Applications, language bindings, related projects |

## Primary Sources

| Source | Link |
|---|---|
| Marmot Protocol specification | [marmot-protocol/marmot](https://github.com/marmot-protocol/marmot) |
| MDK (Rust SDK) | [parres-hq/mdk](https://github.com/parres-hq/mdk) |
| marmot-ts (TypeScript SDK) | [marmot-protocol/marmot-ts](https://github.com/marmot-protocol/marmot-ts) |
| marmot-ts documentation | [marmot-protocol.github.io/marmot-ts](https://marmot-protocol.github.io/marmot-ts/) |
| WhiteNoise (Rust core) | [marmot-protocol/whitenoise-rs](https://github.com/marmot-protocol/whitenoise-rs) |
| WhiteNoise (Flutter app) | [marmot-protocol/whitenoise](https://github.com/marmot-protocol/whitenoise) |
| WhiteNoise website | [whitenoise.chat](https://www.whitenoise.chat/) |
| wn-tui (Terminal UI) | [marmot-protocol/wn-tui](https://github.com/marmot-protocol/wn-tui) |
| marmots-web-chat (TS reference app) | [marmot-protocol/marmots-web-chat](https://github.com/marmot-protocol/marmots-web-chat) |

## Underlying Standards

| Standard | Link |
|---|---|
| MLS (Messaging Layer Security) | [RFC 9420](https://datatracker.ietf.org/doc/rfc9420/) |
| OpenMLS (Rust MLS implementation) | [openmls.tech](https://openmls.tech/) |
| Nostr protocol | [nostr-protocol/nostr](https://github.com/nostr-protocol/nostr) |
| Nostr NIPs | [nostr-protocol/nips](https://github.com/nostr-protocol/nips) |
| NIP-EE (MLS on Nostr) | [nips.nostr.com/EE](https://nips.nostr.com/EE) |
| Blossom (blob storage) | [hzrd149/blossom](https://github.com/hzrd149/blossom) |

## Development

Load the plugin directly:

```bash
claude --plugin-dir ./plugins/nostr-skills
```
