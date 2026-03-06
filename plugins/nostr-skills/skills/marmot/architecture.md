# Marmot Protocol Architecture

## Layer Diagram

```
+------------------------------------------------------+
|  Applications                                         |
|  (WhiteNoise, wn-tui, marmots-web-chat, custom)      |
+------------------------------------------------------+
|  Language Bindings                                    |
|  (mdk-kotlin, mdk-swift, mdk-python, mdk-ruby)       |
+------------------------------------------------------+
|  MDK (Rust)           |  marmot-ts (TypeScript)       |
|  MLS + Nostr core     |  MLS + Nostr core             |
|  OpenMLS              |  ts-mls                       |
+------------------------------------------------------+
|  Nostr Relays (transport)  |  Blossom Servers (media) |
+------------------------------------------------------+
```

## Protocol Composition

Three independent protocols composed together:

1. **MLS (RFC 9420)** — encryption, key agreement, group state
2. **Nostr** — identity (keypairs), transport (relays), event format
3. **Blossom** — blob storage addressed by SHA-256, Nostr-authenticated

## Data Flow: Group Creation and Invitation

```
Alice (Admin)                   Relay                    Bob (Invitee)
     |                            |                           |
     |  1. Fetch Bob's KeyPackage |                           |
     |       (kind 443 query)     |                           |
     |<---------------------------|                           |
     |                            |                           |
     |  2. create_group()         |                           |
     |  (local MLS state init)    |                           |
     |                            |                           |
     |  3. merge_pending_commit() |                           |
     |                            |                           |
     |  4. Publish Commit ------->|                           |
     |     (kind 445 event)       |                           |
     |                            |                           |
     |  5. Wait for ACK <---------|                           |
     |                            |                           |
     |  6. Gift-wrap Welcome ---->|--- (kind 444) ----------->|
     |     (via NIP-59)           |                           |
     |                            |  7. process_welcome()     |
     |                            |  8. accept_welcome()      |
     |                            |  9. Delete init_key       |
     |                            | 10. self_update() (<24h)  |
     |                            |                           |
     | 11. Exchange Messages      |                           |
     | <=====kind 445============>|<=======kind 445==========>|
```

## Data Flow: Messaging

```
Sender                          Relay                    Receiver
  |                               |                          |
  | 1. Create unsigned rumor      |                          |
  |    (kind 9 chat / kind 7      |                          |
  |     reaction / etc.)          |                          |
  |                               |                          |
  | 2. MLS encrypt (inner layer)  |                          |
  |                               |                          |
  | 3. ChaCha20 encrypt           |                          |
  |    (outer layer, exporter key)|                          |
  |                               |                          |
  | 4. Wrap as kind 445           |                          |
  |    (ephemeral keypair,        |                          |
  |     h=nostr_group_id)         |                          |
  |                               |                          |
  | 5. Publish ------------------>|                          |
  |                               |--- subscription -------->|
  |                               |                          |
  |                               |  6. ChaCha20 decrypt     |
  |                               |  7. MLS decrypt          |
  |                               |  8. Extract rumor        |
  |                               |  9. Deliver to app       |
```

## Double Encryption Architecture

Group messages have two encryption layers:

### Inner Layer (MLS)
- Standard MLS group encryption
- Provides forward secrecy and post-compromise security
- Sender authentication via MLS tree

### Outer Layer (ChaCha20-Poly1305)
- Key derived from MLS exporter secret:
  `MLS-Exporter("marmot", "group-event", 32)`
- Random 12-byte nonce per event
- Content: `base64(nonce || ciphertext)`
- Purpose: hides MLS ciphertext structure from relays, enables
  relay-side routing via `h` tag

## Epoch Management and Rollback

The MLS epoch represents the group's cryptographic state version. Each Commit
advances the epoch.

### Race Condition Resolution

In a decentralized system, multiple Commits can target the same epoch:

1. **Ordering rule:** Earliest `created_at` timestamp wins
2. **Tiebreaker:** Lexicographically smallest event `id`
3. **Snapshot mechanism:** Before applying any Commit, save an epoch snapshot
4. **Rollback:** If a "better" Commit arrives after one is applied:
   - Roll back to pre-commit snapshot
   - Invalidate messages decrypted under old epoch
   - Fire `MdkCallback::on_rollback()` with `RollbackInfo`
   - Re-apply the better Commit
   - Failed messages become retryable

### Epoch Snapshot Lifecycle

```
[Epoch N] --snapshot--> [Apply Commit A] --> [Epoch N+1]
                              |
              [Better Commit B arrives]
                              |
              [Rollback to snapshot] --> [Apply Commit B] --> [Epoch N+1']
```

## Storage Architecture

### MDK (Rust) — Trait-Based

```
MdkStorageProvider (trait)
├── GroupStorage      — groups, members, relays, exporter secrets
├── MessageStorage    — messages, processed events, retries
├── WelcomeStorage    — welcome persistence
└── StorageProvider   — OpenMLS key material
    │
    ├── MdkMemoryStorage  (testing)
    └── MdkSqliteStorage  (production, encrypted)
```

### marmot-ts (TypeScript) — Interface-Based

```
KeyValueGroupStateBackend (interface)
├── get(groupId) / set(groupId, state)  — serialized MLS state
├── remove(groupId) / list()
│
KeyPackageStore (class)
├── Local key packages (with private material)
├── Tracked key packages (foreign, no private material)
│
InviteStore (interface)
├── received — gift-wrapped events
├── unread   — decrypted rumors
└── seen     — read status
```

## Admin vs Member Permissions

| Action | Admin | Non-Admin |
|---|---|---|
| Create group | Yes | No |
| Add members (Commit) | Yes | No |
| Remove members (Commit) | Yes | No |
| Update group metadata | Yes | No |
| Propose changes | Yes | Yes |
| Self-update (key rotation) | Yes | Yes |
| Send messages | Yes | Yes |
| Leave group | Yes | Yes |

## WhiteNoise Application Stack (wn-tui / wn / wnd)

Three-tier architecture separating presentation, CLI, and daemon:

```
 wn-tui  (presentation — ratatui, zero crypto deps)
    |
    |  spawns subprocess, parses JSON stdout
    v
   wn   (stateless CLI client — clap, --json mode)
    |
    |  Unix domain socket, newline-delimited JSON
    v
  wnd   (long-running daemon — owns Whitenoise singleton)
    |
    |  calls Whitenoise methods (MDK, Nostr, MLS, SQLite)
    v
  MDK / whitenoise-rs core library
```

### wn CLI Command Structure

```
wn [--json] [--socket PATH] [--account NPUB]
  create-identity | login | logout | whoami | export-nsec | accounts
  chats [subscribe]
  groups [list|create|show|add-members|remove-members|members|admins|
          leave|rename|invites|accept|decline]
  messages [list|send|delete|retry|subscribe|react|unreact]
  follows [list|add|remove|check]
  profile [show|update]
  relays [list]
  settings [show|theme|language]
  users [show|search]
  notifications [subscribe]
  daemon [start|stop|status]
  media [upload|download]
```

### IPC Protocol (wn ↔ wnd)

**Wire format:** Newline-delimited JSON over Unix domain sockets.

```json
// Request
{"method": "SendMessage", "params": {"account": "abc...", "group_id": "def...", "message": "hello"}}

// Response (one-shot)
{"result": {...}}

// Response (streaming, multiple lines)
{"result": {...}}
{"result": {...}}
{"result": {...}, "stream_end": true}

// Error
{"error": {"message": "..."}}
```

Four streaming endpoints: `MessagesSubscribe`, `ChatsSubscribe`,
`NotificationsSubscribe`, `UsersSearch`.

### wn-tui: Elm Architecture (TEA)

```
Terminal Event → Event → Action → App::update() → Vec<Effect>
                                       |                |
                                  mutates App      executed by
                                    state          main loop
                                       |
                                  App::draw() (pure render)
```

- `update()` is pure — only mutates state and returns effects
- Effects are data, never executed inside `update()`
- Screens: Login, MainScreen (3-panel), GroupDetail, Profile, Settings, UserSearch
- Vim-style navigation (j/k), Tab for focus cycling, Esc for back

### Account Resolution (CLI)

Priority order:
1. `--account <npub>` flag
2. `WN_ACCOUNT` environment variable
3. Auto-select if exactly one account exists
4. Error with guidance if ambiguous

### Storage Paths

- **macOS:** `~/Library/Application Support/whitenoise-cli/{dev|release}/`
- **Linux:** XDG data directory
- Build-mode suffix allows parallel debug/release execution
- Socket: `{data_dir}/whitenoise.sock`
- PID file: `{data_dir}/whitenoise.pid`

## Key Architectural Patterns

1. **Separation of crypto from UI** — MDK/marmot-ts handle all
   security-critical operations; UI layers are thin wrappers.
2. **Pluggable storage** — trait/interface based; swap backends without
   changing protocol logic.
3. **Network agnosticism** (marmot-ts) — bring-your-own Nostr client via
   `NostrNetworkInterface`.
4. **Ephemeral keypairs** — group events signed with disposable keys, never
   reused, preventing correlation.
5. **Identity separation** — MLS signing keys ≠ Nostr identity keys;
   compromise of one doesn't compromise the other.
6. **Subprocess isolation** (wn-tui) — presentation layer communicates via
   JSON subprocess I/O, eliminating all crypto/protocol dependencies.
7. **Client-daemon split** (wn/wnd) — stateless CLI over Unix socket IPC,
   daemon owns singleton state and all relay connections.
