# Event Construction, Signing & Publishing

## The `event` Command

Creates a Nostr event, signs it, and optionally publishes to relays.

```
nak event [flags] [relay-urls...]
```

### Content

| Method | Example | Notes |
|---|---|---|
| Inline | `nak event -c 'hello world'` | Most common |
| From file | `nak event -c @message.txt` | Prefix path with `@` |
| Stdin JSON | `echo '{"kind":1,"content":"hi"}' \| nak event` | Modify existing event |
| Default | `nak event` | Defaults to "hello from the nostr army knife" for kind 1 |

**Important:** When piping JSON into `nak event`, the event is parsed from
stdin first, then flags override individual fields. This lets you template
events and modify specific fields.

### Flags

| Flag | Description | Example |
|---|---|---|
| `-k, --kind` | Event kind (default: 1) | `-k 30023` |
| `-c, --content` | Event content | `-c 'hello'` or `-c @file.txt` |
| `-t, --tag` | Add tag (repeatable) | `-t t=nostr` |
| `--e` | Shorthand for `-t e=HEX` | `--e abc123` |
| `--p` | Shorthand for `-t p=PUBKEY` | `--p abc123` |
| `--d` | Shorthand for `-t d=IDENTIFIER` | `--d my-article` |
| `--created-at` | Unix timestamp | `--created-at 1700000000` |
| `--ts` | Alias for --created-at, supports natural language | `--ts 'two weeks ago'` |
| `--sec` | Private key for signing | `--sec nsec1...` |
| `--pow` | NIP-13 proof-of-work difficulty | `--pow 24` |
| `--envelope` | Wrap in `["EVENT", {...}]` format | |
| `--nevent` | Print nevent1 code after publish | |
| `--auth` | Auto-authenticate with relays | |
| `--confirm` | Prompt before publishing | |
| `--force-sign` | Re-sign even if already signed | |
| `--musig` | MuSig2 multi-party signing (N signers) | `--musig 2` |

### Tag Syntax (Critical)

Tags are arrays. The `-t` flag uses `=` for key-value and `;` for additional
array elements:

```bash
# Simple tag: ["t", "nostr"]
nak event -t t=nostr

# Tag with relay hint: ["e", "hex", "wss://relay.com"]
nak event -t 'e=abc123;wss://relay.com'

# Full reply tag: ["e", "hex", "relay", "reply", "pubkey"]
nak event -t 'e=abc123;wss://relay.com;reply;def456'

# Multiple tags
nak event -t t=nostr -t t=bitcoin -t p=abc123

# Protected event tag (NIP-70): ["-"]
nak event -t '-'
```

**Gotcha:** Semicolons separate tag array elements, NOT multiple tags. Each
`-t` flag adds one tag. Use multiple `-t` flags for multiple tags.

### Signing

| Key format | Example |
|---|---|
| Test key | `--sec 01` (hardcoded, for demos) |
| Hex | `--sec deadbeef...` |
| nsec | `--sec nsec1...` |
| ncryptsec (NIP-49) | `--sec ncryptsec1...` (prompts for password) |
| Bunker URI (NIP-46) | `--sec 'bunker://pubkey?relay=wss://r&secret=code'` |
| Env var | `NOSTR_SECRET_KEY=nsec1... nak event -c 'hi'` |
| Default | Without `--sec`, uses test key #01 |

### Publishing to Relays

Relay URLs are positional arguments at the end of the command:

```bash
# Publish to one relay
nak event -c 'hello' wss://relay.damus.io

# Publish to multiple relays
nak event -c 'hello' wss://relay.damus.io wss://nos.lol wss://relay.nostr.band

# Create without publishing (no relay URLs)
nak event -c 'hello' --sec 01
```

Reports success/failure per relay.

## The `publish` Command

Smart publisher for text notes. Preferred over `event` for social posts.

```bash
echo "Hello #nostr! Check out @npub1... and nostr:nevent1..." | nak publish
```

**Auto-processing:**
- `#hashtag` → converted to `t` tag
- `@npub1...` → converted to `nostr:npub1...` URI + `p` tag
- `nevent1...`/`naddr1...` → converted to `nostr:` URI + `q`/`a` tag
- URLs → prefixed with `https://` if needed
- Routes to user's write relays + mentioned users' relays

**Flags:**
- `--reply NEVENT|NADDR|HEX` — reply to an event (preserves kind 1 or 1111)
- `--confirm` — prompt before publishing
- `--sec` — private key (same formats as `event`)

## Common Event Patterns

### Text Note (Kind 1)
```bash
nak event -k 1 -c 'Hello Nostr!' --sec nsec1... wss://relay.damus.io
```

### Reply
```bash
nak event -k 1 -c 'Great post!' \
  --e 'original_event_id;wss://relay;reply' \
  --p original_author_pubkey \
  --sec nsec1... wss://relay.damus.io
```

Or with `publish`:
```bash
echo "Great post!" | nak publish --reply nevent1...
```

### Long-form Article (Kind 30023)
```bash
nak event -k 30023 -c @article.md \
  -t d=my-article-slug \
  -t title='My Article' \
  -t summary='A brief summary' \
  -t published_at=1700000000 \
  --sec nsec1... wss://relay.damus.io
```

### Repost (Kind 6)
```bash
nak fetch nevent1... | nak event -k 6 \
  --e original_id \
  --p original_author \
  --sec nsec1... wss://relay.damus.io
```

### Reaction (Kind 7)
```bash
nak event -k 7 -c '+' \
  --e target_event_id \
  --p target_author \
  --sec nsec1... wss://relay.damus.io
```

### Profile Metadata (Kind 0)
```bash
nak event -k 0 -c '{"name":"alice","about":"Hello","picture":"https://..."}' \
  --sec nsec1... wss://relay.damus.io
```

### Contact List (Kind 3)
```bash
nak event -k 3 -c '' \
  -t 'p=pubkey1;wss://relay1;alias1' \
  -t 'p=pubkey2;wss://relay2;alias2' \
  --sec nsec1... wss://relay.damus.io
```

### Relay List (Kind 10002)
```bash
nak event -k 10002 -c '' \
  -t 'r=wss://relay1.com' \
  -t 'r=wss://relay2.com;read' \
  -t 'r=wss://relay3.com;write' \
  --sec nsec1... wss://relay.damus.io
```
