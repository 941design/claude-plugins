# Querying Relays & Filtering Events

## The `req` Command

Requests events from relays matching a filter.

```
nak req [flags] relay-urls...
```

### Filter Flags

| Flag | Description | Example |
|---|---|---|
| `-k, --kind` | Event kind (repeatable) | `-k 1 -k 6` |
| `-a, --author` | Author pubkey hex (repeatable) | `-a abc123` |
| `-i, --id` | Event ID hex (repeatable) | `-i def456` |
| `-t, --tag` | Tag filter `key=value` (repeatable) | `-t p=abc123` |
| `-e` | Shorthand for `-t e=HEX` | `-e abc123` |
| `-p` | Shorthand for `-t p=PUBKEY` | |
| `-l, --limit` | Max events to return | `-l 10` |
| `--since` | Events after timestamp | `--since 1700000000` |
| `--until` | Events before timestamp | `--until 'December 31 2023'` |
| `--search` | NIP-50 full-text search | `--search 'bitcoin'` |
| `--ids-only` | Return only event IDs | |

### Stdin Filters

`req` can also read filter JSON from stdin:

```bash
echo '{"kinds":[1],"limit":5}' | nak req wss://relay.damus.io
```

### Examples

```bash
# Latest 10 text notes from a relay
nak req -k 1 -l 10 wss://relay.damus.io

# Events by a specific author
nak req -a deadbeef1234... -l 5 wss://relay.damus.io

# Profile metadata (kind 0) for a pubkey
nak req -k 0 -a deadbeef1234... wss://relay.damus.io

# Events mentioning a pubkey (p tag)
nak req -t p=deadbeef1234... -k 1 wss://relay.damus.io

# Events in a time range
nak req -k 1 --since 1700000000 --until 1700100000 wss://relay.damus.io

# Multiple kinds
nak req -k 1 -k 6 -k 7 -l 20 wss://relay.damus.io

# NIP-50 search
nak req --search 'nostr army knife' wss://relay.nostr.band

# Multiple relays (results from all)
nak req -k 1 -l 5 wss://relay.damus.io wss://nos.lol

# Only event IDs
nak req -k 1 -l 5 --ids-only wss://relay.damus.io
```

### Pagination

For large result sets:

```bash
nak req -k 1 --limit 50000 --paginate --paginate-interval 2s wss://relay.damus.io > events.jsonl
```

### Negentropy Sync (--only-missing)

Fetch only events not already in a local file:

```bash
nak req --only-missing ./existing.jsonl -k 30617 wss://relay.damus.io
```

## The `fetch` Command

Fetches specific events by NIP-19 code or hex event ID.

```
nak fetch [flags] <nevent1...|note1...|naddr1...|hex-id>
```

### Examples

```bash
# Fetch by nevent1 code
nak fetch nevent1abc123...

# Fetch by note1 code
nak fetch note1abc123...

# Fetch by naddr1 (replaceable event)
nak fetch naddr1abc123...

# Fetch by hex ID with relay hint
nak fetch abc123... --relay wss://relay.damus.io

# Fetch and extract content
nak fetch nevent1... | jq -r '.content'

# Fetch profile and parse metadata
nak fetch nprofile1... | jq -r '.content | fromjson | .name'
```

## The `filter` Command

Builds filter JSON without querying. Useful for scripting.

```bash
# Build a filter
nak filter -k 1 -a abc123 -l 10
# Output: {"kinds":[1],"authors":["abc123"],"limit":10}

# Pipe filter into req
nak filter -k 1 -l 5 | nak req wss://relay.damus.io
```

## The `count` Command

Counts events matching a filter (requires NIP-45 relay support).

```bash
nak count -k 1 -a abc123 wss://relay.damus.io

# Also accepts filters from stdin
echo '{"kinds":[1],"limit":100}' | nak count wss://relay.damus.io
```

## The `verify` Command

Validates event signatures:

```bash
echo '{"id":"...","pubkey":"...","sig":"..."}' | nak verify
# Outputs: valid / invalid

# Verify events from a file
cat events.jsonl | nak verify
```

## The `profile` Command

View Nostr profiles:

```bash
nak profile npub1...
nak profile <hex-pubkey>
```

## Common Query Patterns

### Get someone's profile
```bash
nak req -k 0 -a $(nak decode npub1... | jq -r '.data') wss://relay.damus.io | jq '.content | fromjson'
```

### Get someone's recent notes
```bash
nak req -k 1 -a $(nak decode npub1... | jq -r '.data') -l 20 wss://relay.damus.io | jq -r '.content'
```

### Get replies to an event
```bash
nak req -k 1 -t e=<event-id-hex> wss://relay.damus.io
```

### Get a user's relay list
```bash
nak req -k 10002 -a <pubkey-hex> wss://purplepag.es
```

### Get a user's follows
```bash
nak req -k 3 -a <pubkey-hex> wss://purplepag.es | jq '[.tags[] | select(.[0]=="p") | .[1]]'
```

### Extract quoted events from notes
```bash
nak req -k 1 -l 10 wss://relay.damus.io | \
  jq -r '.content | match("nostr:(nevent1[a-z0-9]+)") | .captures[0].string' | \
  while read code; do nak fetch "$code"; done
```

### Fetch livestream URL
```bash
nak fetch naddr1... | jq -r '.tags | map(select(.[0]=="streaming"))[0][1]'
```
