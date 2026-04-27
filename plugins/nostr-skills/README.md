# nostr-skills

Skills for working with the [Nostr](https://github.com/nostr-protocol/nostr)
protocol. Currently covers four domains:

- **Nostr Operator** — interact with the Nostr network directly using
  [nak](https://github.com/fiatjaf/nak) (the nostr army knife CLI): publish
  events, query relays, manage keys, encode/decode NIP-19, sync, and more
- **Marmot Protocol** — end-to-end encrypted group messaging combining
  [MLS (RFC 9420)](https://messaginglayersecurity.rocks/) with Nostr
- **Remote Signing** — NIP-46 bunkers, NIP-07 browser extensions, NIP-55
  Android signers, key management libraries, and platform-specific best
  practices
- **Nostr SDKs** — cross-language SDK selection and usage advisor across
  TS (nostr-tools, NDK), Rust (rust-nostr), Go (fiatjaf.com/nostr), JVM
  (nostr-sdk-jvm, nostr-java, nostr4j), Apple (nostr-sdk-ios,
  nostr-sdk-swift), Python (pynostr), and more

The Nostr Operator skill executes commands directly. The advisory skills help
build applications using existing libraries.

## Installation

```bash
/plugin marketplace add 941design/claude-plugins
/plugin install nostr-skills@941design
```

## Skills

### `/nostr-skills:nostr [operation or question]`

Operator skill. Interacts with Nostr directly using
[nak](https://github.com/fiatjaf/nak) (the nostr army knife CLI):

- Publish events (text notes, profiles, reactions, reposts, articles)
- Query relays with filters (kind, author, tags, time range)
- Fetch specific events by NIP-19 code or hex ID
- Encode/decode NIP-19 identifiers (npub, nsec, note, nevent, nprofile, naddr)
- Manage keys (generate, derive, NIP-49 encrypt/decrypt)
- Remote signing via NIP-46 bunkers
- Gift wrapping (NIP-59), NIP-44 encryption
- Blossom file uploads, relay sync, group chat, git operations

**Auto-invokes** when Claude detects requests to read from or write to Nostr.
Runs in an isolated agent context with persistent memory.

**Executes commands:** Unlike the advisory skills, this skill runs `nak`
commands directly. It confirms with the user before publishing (writing) but
reads freely.

### `/nostr-skills:nostr-update [topic]`

Manual maintenance skill. Fetches the latest nak README, release notes, and
command documentation, then updates agent memory.

```bash
# Full update
/nostr-skills:nostr-update

# Targeted update
/nostr-skills:nostr-update blossom commands
```

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

### `/nostr-skills:nostr-sdks [question]`

Advisory skill. Helps pick and use the right Nostr SDK across languages and
platforms. Default stance: language-native first.

- **TypeScript/JS** — [nostr-tools](https://github.com/nbd-wtf/nostr-tools),
  [NDK](https://github.com/nostr-dev-kit/ndk)
- **Rust** — [rust-nostr](https://github.com/rust-nostr/nostr) (`nostr-sdk` crate)
- **Go** — [fiatjaf.com/nostr](https://pkg.go.dev/fiatjaf.com/nostr)
  (successor to archived `nbd-wtf/go-nostr`)
- **JVM** — [nostr-sdk-jvm](https://central.sonatype.com/artifact/io.github.rust-nostr/nostr-sdk)
  (UniFFI), [nostr-java](https://github.com/tcheeric/nostr-java),
  [nostr4j](https://github.com/NostrGameEngine/nostr4j)
- **Apple** — [nostr-sdk-ios](https://github.com/nostr-sdk/nostr-sdk-ios)
  (native), [nostr-sdk-swift](https://github.com/rust-nostr/nostr-sdk-swift)
  (UniFFI)
- **Python** — [pynostr](https://github.com/holgern/pynostr) (active fork of
  legacy [python-nostr](https://github.com/jeffthibault/python-nostr))
- Cross-SDK comparison, common-task code snippets, interop and bindings
  guidance, archived/legacy library detection

For deep NIP-46/07/55 signer questions defer to **remote-signing**; for
Marmot/MLS group messaging defer to **marmot**.

**Auto-invokes** when Claude detects SDK-selection or cross-language
questions. Runs in an isolated agent context with persistent memory.

**Self-updating:** Checks documentation freshness on each invocation. If
supporting documents are older than 7 days, automatically fetches the latest
release notes and project status before answering.

### `/nostr-skills:nostr-sdks-update [topic]`

Manual maintenance skill. Fetches latest releases, NIP support, and project
status across all tracked SDKs, then updates agent memory.

```bash
# Full update
/nostr-skills:nostr-sdks-update

# Targeted update
/nostr-skills:nostr-sdks-update rust-nostr
```

## Agents

### nostr-operator

Custom agent with user-scoped persistent memory
(`~/.claude/agent-memory/nostr-operator/`). Accumulates knowledge across
sessions — nak usage patterns, relay lists, version tracking, and changelog.

Both nostr skills run in this agent's context, sharing the same memory.

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

### nostr-sdk-researcher

Custom agent with user-scoped persistent memory
(`~/.claude/agent-memory/nostr-sdk-researcher/`). Accumulates knowledge
across sessions — SDK version numbers, NIP-support tables, archive/legacy
status, and binding/native trade-offs across all tracked Nostr libraries.

Both nostr-sdks skills run in this agent's context, sharing the same memory.

### First Run (all agents)

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
/nostr-skills:nostr-sdks-update
```

## Supporting Documents

### Nostr Operator

Five read-only reference files:

| File | Content |
|---|---|
| `nak-commands.md` | Complete nak command index with all subcommands |
| `event-construction.md` | Event creation, signing, content handling, tag syntax, publishing |
| `query-and-filter.md` | Querying relays, filtering, pagination, negentropy sync |
| `encoding-keys-signing.md` | NIP-19 encode/decode, key management, bunkers, musig2 |
| `advanced-operations.md` | Gift wrapping, blossom, git, groups, wallet, publish, FUSE, admin |

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
| `libraries-and-sdks.md` | TS (nostr-tools, NDK, nostr-login, nostr-signer-connector, Nostrify), Rust (rust-nostr), JVM (nostr-sdk-jvm, nostr-java, nostr4j), Apple (nostr-sdk-ios, nostr-sdk-swift), Go (fiatjaf.com/nostr), Python (pynostr) |

### Nostr SDKs

Four read-only reference files:

| File | Content |
|---|---|
| `library-matrix.md` | All major Nostr SDKs by language/maturity/NIP support/activity, with strengths and trade-offs |
| `selection-guide.md` | Decision tree by language, platform, use case; when to push back on the user's choice |
| `common-tasks.md` | Side-by-side code examples for keypair generation, publish, subscribe, and NIP-46 connect across SDKs |
| `interop-and-bindings.md` | rust-nostr UniFFI family, the two distinct nostr-sdk-ios projects, archived/legacy projects, wire compatibility |

## Primary Sources

### Nostr Operator

| Source | Link |
|---|---|
| nak (nostr army knife) | [fiatjaf/nak](https://github.com/fiatjaf/nak) |
| nak releases | [fiatjaf/nak/releases](https://github.com/fiatjaf/nak/releases) |
| Nostr protocol | [nostr-protocol/nostr](https://github.com/nostr-protocol/nostr) |
| Nostr NIPs | [nostr-protocol/nips](https://github.com/nostr-protocol/nips) |

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

### Nostr SDKs

| Source | Link |
|---|---|
| nostr-tools | [nbd-wtf/nostr-tools](https://github.com/nbd-wtf/nostr-tools) |
| NDK | [nostr-dev-kit/ndk](https://github.com/nostr-dev-kit/ndk) |
| rust-nostr | [rust-nostr/nostr](https://github.com/rust-nostr/nostr) |
| rust-nostr book | [rust-nostr.org](https://rust-nostr.org/) |
| nostr-sdk-jvm | [Maven Central — io.github.rust-nostr:nostr-sdk](https://central.sonatype.com/artifact/io.github.rust-nostr/nostr-sdk) |
| nostr-sdk-swift (UniFFI) | [rust-nostr/nostr-sdk-swift](https://github.com/rust-nostr/nostr-sdk-swift) |
| nostr-sdk-ios (native) | [nostr-sdk/nostr-sdk-ios](https://github.com/nostr-sdk/nostr-sdk-ios) |
| fiatjaf.com/nostr (Go) | [pkg.go.dev/fiatjaf.com/nostr](https://pkg.go.dev/fiatjaf.com/nostr) |
| nostr-java | [tcheeric/nostr-java](https://github.com/tcheeric/nostr-java) |
| nostr4j | [NostrGameEngine/nostr4j](https://github.com/NostrGameEngine/nostr4j) |
| pynostr | [holgern/pynostr](https://github.com/holgern/pynostr) |

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
