# Marmot Protocol Ecosystem

## Organization

**GitHub:** https://github.com/marmot-protocol

## Implementations

### MDK — Marmot Development Kit (Rust)

- **Repo:** https://github.com/parres-hq/mdk
- **Stars:** ~44
- **Status:** Reference implementation, pre-1.0
- **MLS backend:** OpenMLS 0.8.1
- **License:** MIT
- See [mdk-reference.md](mdk-reference.md) for full API.

### marmot-ts (TypeScript)

- **Repo:** https://github.com/marmot-protocol/marmot-ts
- **npm:** `@internet-privacy/marmot-ts`
- **Stars:** ~14
- **Status:** Alpha (v0.1.0), API subject to breaking changes
- **MLS backend:** ts-mls (pure TypeScript)
- **Docs:** https://marmot-protocol.github.io/marmot-ts/
- See [marmot-ts-reference.md](marmot-ts-reference.md) for full API.

### Language Bindings (FFI from MDK)

| Language | Repository | Status |
|---|---|---|
| Swift | https://github.com/marmot-protocol/mdk-swift | Early |
| Kotlin | https://github.com/marmot-protocol/mdk-kotlin | Early |
| Python | https://github.com/marmot-protocol/mdk-python | Early |
| Ruby | https://github.com/marmot-protocol/mdk-ruby | Early |

---

## Applications

### WhiteNoise (Flagship)

- **Website:** https://www.whitenoise.chat/
- **Rust backend:** https://github.com/marmot-protocol/whitenoise-rs (~434 stars)
- **Flutter app:** https://github.com/marmot-protocol/whitenoise
- **License:** AGPL-3.0
- **Features:** Encrypted DMs and group chat, multi-device, encrypted media
  (Blossom), no phone/email required
- **Architecture:** Rust core (whitenoise-rs) with Flutter UI
- **Platforms:** iOS (TestFlight), Android (Zapstore/APK)
- **Backed by:** OpenSats, Human Rights Foundation
- **Notable:** Endorsed by Jack Dorsey

### wn-tui (Terminal UI)

- **Repo:** https://github.com/marmot-protocol/wn-tui
- **License:** MIT
- **Architecture:** Subprocess-based — shells out to `wn --json`, never
  links MDK/MLS/Nostr libraries directly
- **UI framework:** ratatui 0.29 + crossterm 0.28
- **Pattern:** Elm Architecture (TEA) with pure `update()` and returned effects
- **Key feature:** Zero crypto dependencies — communicates entirely via JSON
  over spawned `wn` processes
- See [architecture.md](architecture.md) for the three-tier stack diagram.

### wn / wnd (CLI and Daemon)

- **Location:** Binary targets within whitenoise-rs (feature-gated: `cli`)
- **wn:** Stateless CLI client, 15 top-level commands, `--json` output mode
- **wnd:** Long-running daemon owning the Whitenoise singleton, Unix domain
  socket server
- **IPC:** Newline-delimited JSON over Unix domain sockets, supports both
  request-response and streaming
- **License:** AGPL-3.0
- See [architecture.md](architecture.md) for command structure and IPC details.

### marmots-web-chat (Reference Web App)

- **Repo:** https://github.com/marmot-protocol/marmots-web-chat
- **Status:** Reference implementation of marmot-ts
- Web-based chat demonstrating full NostrNetworkInterface integration

---

## Related Projects

### 0xchat

- **Website:** https://0xchat.com/
- Separate decentralized messenger on Nostr
- Own MLS implementation (Dart-bridged "Nostr MLS package")
- Referenced alongside WhiteNoise in NIP-EE spec

### nostr-openmls (Deprecated)

- **Repo:** https://github.com/marmot-protocol/nostr-openmls (archived)
- Earlier library for OpenMLS in Nostr clients
- Replaced by `nostr-mls` crate in the rust-nostr ecosystem

---

## Underlying Standards

### MLS (RFC 9420)

- **Spec:** https://datatracker.ietf.org/wg/mls/about/
- **Overview:** https://messaginglayersecurity.rocks/
- **Rust impl:** OpenMLS (https://openmls.tech/)
- **TS impl:** ts-mls
- Tree-based key structure: logarithmic (not linear) scaling for groups

### Nostr Protocol

- **Repo:** https://github.com/nostr-protocol/nostr
- **NIPs:** https://github.com/nostr-protocol/nips
- **NIP-EE:** https://nips.nostr.com/EE (Marmot's predecessor)
- Decentralized identity + relay transport

### Blossom Protocol

- **Repo:** https://github.com/hzrd149/blossom
- HTTP blob storage, SHA-256 addressed
- Nostr NIP-98 authentication
- Used for MIP-04 encrypted media

---

## Development Resources

### Testing Infrastructure

WhiteNoise uses Docker-based testing with:
- nostr-rs-relay, strfry (Nostr relays)
- Blossom server
- Automated coverage, security audits, dependency checks
- `just precommit` workflow

### Contributing

- marmot-ts actively seeking contributors
- MDK accepts PRs under MIT license
- WhiteNoise under AGPL-3.0

### Community

- Stacker News: https://stacker.news/items/1256665
- Twitter: https://x.com/whitenoisechat
