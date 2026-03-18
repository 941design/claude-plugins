# nak Command Reference

## Global Flags

| Flag | Description |
|---|---|
| `-q, --quiet` | Suppress log output; `-qq` suppresses stdout too |
| `-v, --verbose` | Verbose relay WebSocket logging |
| `--version` | Print nak version |
| `--config-path` | Config file path (hidden) |

## Command Index

### Event Creation & Publishing

| Command | Purpose |
|---|---|
| `event` | Create, sign, and optionally publish events |
| `publish` | Smart text note publisher with auto-tagging |

### Querying & Filtering

| Command | Purpose |
|---|---|
| `req` | Request events from relays with filters |
| `fetch` | Fetch specific events by NIP-19 code or hex ID |
| `filter` | Build and output filter JSON |
| `count` | Count events matching a filter (NIP-45) |
| `verify` | Validate event signatures |

### Encoding & Decoding

| Command | Purpose |
|---|---|
| `decode` | Decode NIP-19 strings to JSON |
| `encode` | Encode data into NIP-19 format |

### Key Management

| Command | Purpose |
|---|---|
| `key generate` | Create new private key (hex) |
| `key public` | Derive public key from private key |
| `key encrypt` | NIP-49 encrypt a private key |
| `key decrypt` | NIP-49 decrypt an ncryptsec |
| `dekey` | Key derivation |

### Encryption & Wrapping

| Command | Purpose |
|---|---|
| `encrypt` | NIP-44 encrypt a message |
| `decrypt` | NIP-44 decrypt a message |
| `gift` | Gift-wrap events (NIP-59) |

### Relay Operations

| Command | Purpose |
|---|---|
| `relay` | Relay information and operations |
| `serve` | Run a local test relay |
| `admin` | NIP-86 relay management API |
| `sync` | Sync events between relays (NIP-77 negentropy) |
| `curl` | Raw HTTP-like relay requests |

### Signing

| Command | Purpose |
|---|---|
| `bunker` | Run/manage NIP-46 remote signer |

### Files & Media

| Command | Purpose |
|---|---|
| `blossom` | Upload/download files via Blossom servers |
| `fs` | Mount FUSE filesystem for Nostr |

### Social & Collaboration

| Command | Purpose |
|---|---|
| `group` | NIP-29 group chat operations |
| `git` | NIP-34/GRASP git repository management |
| `profile` | View/manage Nostr profiles |

### Other

| Command | Purpose |
|---|---|
| `wallet` | NIP-60 Cashu wallet operations |
| `outbox` | Outbox model relay discovery |
| `nip` | NIP specification lookup |
| `spell` | Spell operations |
| `mcp-server` | MCP server for AI tool integration |

## Environment Variables

| Variable | Purpose |
|---|---|
| `NOSTR_SECRET_KEY` | Default private key (hex, nsec, ncryptsec, or bunker URI) |
| `NOSTR_CLIENT_KEY` | Client identity key for bunker connections |
