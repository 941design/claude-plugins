# nostr-skills

Implementation advisors for [Nostr](https://github.com/nostr-protocol/nostr)
protocol topics. Currently covers two domains:

- **Marmot Protocol** — end-to-end encrypted group messaging combining
  [MLS (RFC 9420)](https://messaginglayersecurity.rocks/) with Nostr
- **Remote Signing** — NIP-46 bunkers, NIP-07 browser extensions, NIP-55
  Android signers, key management libraries, and platform-specific best
  practices

Helps build applications using existing libraries, not reimplement protocols
from scratch.

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

### `/nostr-skills:remote-signing [question]`

Advisory skill. Answers questions about:

- [NIP-46](https://github.com/nostr-protocol/nips/blob/master/46.md) remote
  signing protocol — connection flows, methods, auth challenges
- [NIP-07](https://github.com/nostr-protocol/nips/blob/master/07.md) browser
  extension integration — `window.nostr` API
- [NIP-55](https://github.com/nostr-protocol/nips/blob/master/55.md) Android
  signer — Intents, Content Resolvers
- Signer implementations — nsecBunker, nsec.app, Amber, Aegis, FROSTR, Gossip
- Libraries — nostr-tools, NDK, nostr-login, nostr-signer-connector
- Platform patterns — PWA, web, desktop key management and security

**Auto-invokes** when Claude detects remote signing or key management questions.
Runs in an isolated agent context with persistent memory.

**Self-updating:** Checks documentation freshness on each invocation. If
supporting documents are older than 7 days, automatically fetches the latest
NIP specs and library sources before answering.

### `/nostr-skills:remote-signing-update [topic]`

Manual maintenance skill. Fetches the latest NIP specifications, library
releases, and signer implementations, then updates agent memory.

```bash
# Full update
/nostr-skills:remote-signing-update

# Targeted update
/nostr-skills:remote-signing-update NIP-46
```

## Agents

### marmot-researcher

Custom agent with user-scoped persistent memory
(`~/.claude/agent-memory/marmot-researcher/`). Accumulates knowledge across
sessions — API patterns, common pitfalls, version tracking, and changelog.

Both marmot skills run in this agent's context, sharing the same memory.

### remote-signing-researcher

Custom agent with user-scoped persistent memory
(`~/.claude/agent-memory/remote-signing-researcher/`). Accumulates knowledge
across sessions — integration patterns, NIP spec changes, library versions,
signer implementation updates, and security gotchas.

Both remote-signing skills run in this agent's context, sharing the same memory.

### First Run (both agents)

Agent memory is user-scoped and lives outside the plugin directory. Plugin
files are never modified at runtime — all dynamic state lives in agent memory.

On first invocation, each agent detects that its memory is empty and
automatically runs a full knowledge refresh, fetching from all primary sources
and populating memory files. This adds latency to the first invocation but
requires no manual setup. Subsequent invocations reuse cached memory and only
refresh when stale (>7 days). When memory and supporting docs conflict, agents
trust their memory (latest fetch) over the shipped docs.

To force a rebuild at any time:

```bash
/nostr-skills:marmot-update
/nostr-skills:remote-signing-update
```

## Supporting Documents

### Marmot Protocol

Six read-only reference files:

| File | Content |
|---|---|
| `protocol-overview.md` | Goals, security properties, cryptographic parameters |
| `mip-specifications.md` | MIP-00 through MIP-05 specification summaries |
| `mdk-reference.md` | Rust MDK API — structs, traits, enums, methods |
| `marmot-ts-reference.md` | TypeScript API — classes, interfaces, types |
| `architecture.md` | Layer diagrams, data flows, IPC, epoch rollback |
| `ecosystem.md` | Applications, language bindings, related projects |

### Remote Signing

Five read-only reference files:

| File | Content |
|---|---|
| `nip-46-protocol.md` | NIP-46 message format, connection flows, methods, auth challenges |
| `signing-nips-reference.md` | NIP-07, NIP-55, NIP-44, NIP-49, NIP-19 and related NIPs |
| `signer-implementations.md` | nsecBunker, nsec.app, Amber, Aegis, nos2x, FROSTR, Gossip |
| `platform-best-practices.md` | PWA, web, desktop patterns, security, UX recommendations |
| `libraries-and-sdks.md` | nostr-tools, NDK, nostr-login, nostr-signer-connector, Nostrify |

## Primary Sources

### Marmot Protocol

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

### Remote Signing

| Source | Link |
|---|---|
| NIP-46 (Remote Signing) | [nostr-protocol/nips/46.md](https://github.com/nostr-protocol/nips/blob/master/46.md) |
| NIP-07 (window.nostr) | [nostr-protocol/nips/07.md](https://github.com/nostr-protocol/nips/blob/master/07.md) |
| NIP-55 (Android Signer) | [nostr-protocol/nips/55.md](https://github.com/nostr-protocol/nips/blob/master/55.md) |
| nostr-tools | [nbd-wtf/nostr-tools](https://github.com/nbd-wtf/nostr-tools) |
| NDK | [nostr-dev-kit/ndk](https://github.com/nostr-dev-kit/ndk) |
| nostr-login | [nostrband/nostr-login](https://github.com/nostrband/nostr-login) |
| nsecbunkerd | [kind-0/nsecbunkerd](https://github.com/kind-0/nsecbunkerd) |
| nsec.app (noauth) | [nostrband/noauth](https://github.com/nostrband/noauth) |
| Amber | [greenart7c3/Amber](https://github.com/greenart7c3/Amber) |
| Aegis | [ZharlieW/Aegis](https://github.com/ZharlieW/Aegis) |
| FROSTR/Igloo | [FROSTR-ORG/igloo-desktop](https://github.com/FROSTR-ORG/igloo-desktop) |

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
