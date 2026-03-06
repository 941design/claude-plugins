# nostr-skills

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin providing
knowledge and implementation advice for the **Marmot Protocol** — end-to-end
encrypted group messaging over MLS and Nostr.

## Installation

### From Marketplace

```bash
# Inside Claude Code
/plugin install nostr-skills
```

### From Source

```bash
claude --plugin-dir /path/to/claude-marmot
```

Or add to your user settings (`~/.claude/settings.json`):

```json
{
  "plugins": ["/path/to/claude-marmot"]
}
```

## Skills

### `/nostr-skills:marmot [question]`

Knowledge and implementation advisor. Answers questions about:

- Marmot Protocol specification (MIP-00 through MIP-05)
- MDK (Rust SDK) — structs, traits, methods, storage backends
- marmot-ts (TypeScript) — classes, interfaces, async patterns
- WhiteNoise architecture — Flutter app, wn-tui, wn/wnd CLI+daemon
- MLS (RFC 9420) integration with Nostr
- Encrypted media via Blossom (MIP-04)
- Group lifecycle, epoch management, commit race resolution

**Auto-invokes** when Claude detects Marmot-related questions. Runs in an
isolated agent context with persistent memory.

**Self-updating:** Checks documentation freshness on each invocation. If
supporting documents are older than 7 days, automatically fetches the latest
from all primary repositories before answering.

### `/nostr-skills:marmot-update [topic]`

Manual maintenance skill. Fetches the latest from all Marmot Protocol
repositories and updates the supporting documents and agent memory.

```bash
# Full update
/nostr-skills:marmot-update

# Targeted update
/nostr-skills:marmot-update mdk-reference
```

## Agent

### marmot-researcher

Custom agent with user-scoped persistent memory (`~/.claude/agent-memory/marmot-researcher/`).
Accumulates knowledge about the Marmot Protocol across sessions — API patterns,
common pitfalls, version tracking, and changelog.

Both skills run in this agent's context, sharing the same memory.

### First Run

Agent memory is user-scoped and lives outside the plugin directory. On first
invocation (or for any new user installing the plugin), the agent detects that
its memory is empty and automatically runs a full initialization cycle:

1. Fetches latest content from all primary repositories
2. Updates the supporting documents shipped with the plugin
3. Populates `~/.claude/agent-memory/marmot-researcher/` with:
   - `MEMORY.md` — index with version numbers, repo map, fetch timestamp
   - `api-patterns.md` — cross-library usage patterns
   - `gotchas.md` — common pitfalls
   - `changelog.md` — version snapshots

This adds latency to the first invocation but requires no manual setup.
Subsequent invocations reuse cached memory and only refresh when stale (>7 days).

To force a rebuild at any time:

```bash
/nostr-skills:marmot-update
```

## Supporting Documents

Six reference files ship with the plugin and are kept current by the update
mechanism:

| File | Content |
|---|---|
| `protocol-overview.md` | Goals, security properties, cryptographic parameters |
| `mip-specifications.md` | MIP-00 through MIP-05 specification summaries |
| `mdk-reference.md` | Rust MDK API — structs, traits, enums, methods |
| `marmot-ts-reference.md` | TypeScript API — classes, interfaces, types |
| `architecture.md` | Layer diagrams, data flows, IPC, epoch rollback |
| `ecosystem.md` | Applications, language bindings, related projects |

## Primary Sources

| Source | Repository |
|---|---|
| Protocol specification | [marmot-protocol/marmot](https://github.com/marmot-protocol/marmot) |
| MDK (Rust SDK) | [parres-hq/mdk](https://github.com/parres-hq/mdk) |
| marmot-ts (TypeScript) | [marmot-protocol/marmot-ts](https://github.com/marmot-protocol/marmot-ts) |
| WhiteNoise (Rust core) | [marmot-protocol/whitenoise-rs](https://github.com/marmot-protocol/whitenoise-rs) |
| WhiteNoise (Flutter) | [marmot-protocol/whitenoise](https://github.com/marmot-protocol/whitenoise) |
| wn-tui (Terminal UI) | [marmot-protocol/wn-tui](https://github.com/marmot-protocol/wn-tui) |
| marmots-web-chat | [marmot-protocol/marmots-web-chat](https://github.com/marmot-protocol/marmots-web-chat) |
| TS documentation | [marmot-protocol.github.io/marmot-ts](https://marmot-protocol.github.io/marmot-ts/) |

## Plugin Structure

```
claude-marmot/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── agents/
│   └── marmot-researcher.md     # Custom agent with user-scoped memory
├── skills/
│   ├── marmot/
│   │   ├── SKILL.md             # Knowledge/advisory skill
│   │   ├── last-updated.txt     # Freshness timestamp
│   │   ├── protocol-overview.md
│   │   ├── mip-specifications.md
│   │   ├── mdk-reference.md
│   │   ├── marmot-ts-reference.md
│   │   ├── architecture.md
│   │   └── ecosystem.md
│   └── marmot-update/
│       └── SKILL.md             # Maintenance skill (manual-only)
└── README.md
```

## License

MIT
