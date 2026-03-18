# Advanced nak Operations

## Gift Wrapping (NIP-59)

Encrypt events for private delivery.

### Wrap

```bash
# Wrap an event for a recipient
nak event -c 'secret message' | nak gift wrap --sec <sender-key> -p <recipient-pubkey>

# Wrap a DM (kind 14)
nak event -k 14 -c 'hello privately' | nak gift wrap --sec <sender-key> -p <recipient-pubkey>
```

### Unwrap

```bash
# Fetch and unwrap gift-wrapped events (kind 1059)
nak req -p <my-pubkey> -k 1059 wss://relay.damus.io | \
  nak gift unwrap --sec <my-key> --from <sender-pubkey>
```

## Relay Sync (NIP-77 Negentropy)

Efficiently sync events between relays:

```bash
# Bidirectional sync
nak sync wss://source-relay.com wss://dest-relay.com

# Sync specific kinds
nak sync --filter '{"kinds":[1]}' wss://relay1.com wss://relay2.com

# Download missing events to local file
nak req --only-missing ./events.jsonl -k 1 wss://relay.damus.io >> events.jsonl
```

## Blossom File Operations

Upload and download files from Blossom servers.

### Upload

```bash
# Upload a file
nak blossom --server https://blossom.example.com --sec <key> upload photo.jpg

# Upload from stdin (e.g., audio recording)
ffmpeg -f avfoundation -i ":1" -t 30 -f mp3 - | \
  nak blossom --server https://blossom.example.com --sec <key> upload
```

### Download

```bash
nak blossom --server https://blossom.example.com download <sha256-hash> -o output.jpg
```

### Publish Media Event

```bash
# Record audio → upload → publish as audio note
ffmpeg ... | nak blossom --server <url> upload | \
  jq -rc '{content:.url}' | nak event -k 1222 --sec <key> wss://relay.damus.io
```

## FUSE Filesystem

Mount Nostr as a filesystem:

```bash
# Mount
nak fs --sec 01 ~/nostr

# Browse
ls ~/nostr/npub1.../notes/

# Create a note by writing a file
echo "Hello from filesystem" > ~/nostr/npub1.../notes/new
touch ~/nostr/npub1.../notes/publish  # Triggers publish

# Unmount
fusermount -u ~/nostr
```

## Group Chat (NIP-29)

Interact with relay-based groups:

```bash
# Group info
nak group info "relay.com'groupid"

# Group admin operations
nak group admin "relay.com'groupid"

# Enter chat mode
nak group chat "relay.com'groupid"

# Send a message
nak group chat send "relay.com'groupid" "Hello group!"
```

**Note:** Group identifier format uses single quote `'` separator: `relay'groupid`

## Git Operations (NIP-34/GRASP)

Nostr-native git repository management:

```bash
nak git clone <naddr1...>
nak git init
nak git status
nak git sync
nak git fetch
nak git pull
nak git push
```

## Wallet Operations (NIP-60)

Cashu ecash wallet:

```bash
# List tokens
nak wallet tokens

# Send ecash
nak wallet send <amount>

# Pay lightning invoice
nak wallet pay <bolt11-invoice>
```

## Relay Administration (NIP-86)

```bash
# Allow a pubkey on a relay
nak admin allowpubkey --sec <admin-key> --pubkey <target> wss://relay.com

# Other admin operations follow the same pattern
nak admin <subcommand> --sec <admin-key> [flags] wss://relay.com
```

## Local Test Relay

```bash
# Basic local relay
nak serve

# With NIP-77 negentropy support
nak serve --negentropy

# With NIP-34 GRASP support
nak serve --grasp

# With Blossom file hosting
nak serve --blossom
```

## The `publish` Command (Smart Publisher)

Enhanced text note publishing with auto-processing:

```bash
# Simple publish
echo "Hello world" | nak publish

# With hashtags (auto-tagged)
echo "Loving #nostr and #bitcoin" | nak publish

# With mentions (auto-resolved)
echo "Check out @npub1abc..." | nak publish

# Reply to an event
echo "Great post!" | nak publish --reply nevent1...

# With confirmation
echo "Important post" | nak publish --confirm

# With specific key
echo "Hello" | nak publish --sec nsec1...
```

**Auto-processing details:**
- `#word` → `t` tag added, hashtag preserved in content
- `@npub1...` → converted to `nostr:npub1...`, `p` tag added
- `nevent1...`/`naddr1...` in text → `nostr:` prefix, `q`/`a` tag added
- Bare URLs → `https://` prefix added if needed
- Routes to user's write relays + mentioned users' inbox relays

## Outbox Model

Discover relays for a user via the outbox model:

```bash
nak outbox <npub1...|hex-pubkey>
```

## NIP Lookup

Quick reference for NIP specifications:

```bash
nak nip 1    # Show NIP-01 summary
nak nip 46   # Show NIP-46 summary
```

## MCP Server

Run nak as an MCP (Model Context Protocol) server for AI tool integration:

```bash
nak mcp-server
```

## Verbose/Debug Mode

### Runtime verbose flag
```bash
nak -v req -k 1 -l 1 wss://relay.damus.io
```

### Debug build (full WebSocket logging)
```bash
go install -tags=debug github.com/fiatjaf/nak@latest
```

## Common Advanced Patterns

### Backup all events from a relay
```bash
nak req -k 1 --limit 50000 --paginate --paginate-interval 2s wss://relay.com > backup.jsonl
```

### Mirror events between relays
```bash
nak req -a <pubkey> wss://source-relay.com | \
  while read event; do echo "$event" | nak event wss://dest-relay.com; done
```

### Download torrent from Nostr event
```bash
aria2c $(nak fetch nevent1... | jq -r 'magnet construction...')
```

### Watch livestream
```bash
mpv $(nak fetch naddr1... | jq -r '.tags | map(select(.[0]=="streaming"))[0][1]')
```
