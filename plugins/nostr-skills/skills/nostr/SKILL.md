---
name: nostr
description: >-
  Nostr protocol operator. Interacts with the Nostr network directly using nak
  (the nostr army knife CLI). Use for publishing events, querying relays,
  fetching profiles, encoding/decoding NIP-19 identifiers, managing keys,
  syncing relays, gift wrapping, blossom file uploads, group chat, and any
  direct Nostr network operations. Invoke when the user wants to read from or
  write to Nostr.
argument-hint: "[nostr operation or question]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: nostr-operator
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Follow the
refresh procedure described in your agent system prompt (fetch nak README and
releases, write findings to agent memory only — never modify plugin files).

If memory is fresh, proceed directly to executing the request.

## Prerequisite Check

Before executing any nak command, verify nak is installed:
```
which nak || echo "nak not found"
```

If not installed, offer to install via `go install github.com/fiatjaf/nak@latest`
or the one-liner: `curl -sSL https://raw.githubusercontent.com/fiatjaf/nak/master/install.sh | sh`

## User Request

$ARGUMENTS

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [nak-commands.md](nak-commands.md) | Complete nak command reference with all subcommands and flags |
| [event-construction.md](event-construction.md) | Event creation, signing, content handling, tag syntax, publishing |
| [query-and-filter.md](query-and-filter.md) | Querying relays, filtering events, pagination, negentropy sync |
| [encoding-keys-signing.md](encoding-keys-signing.md) | NIP-19 encode/decode, key management, bunkers, musig2 |
| [advanced-operations.md](advanced-operations.md) | Gift wrapping, blossom, git, groups, wallet, publish, FUSE, admin |

Read the relevant documents to handle the user's request. Consult your agent
memory for additional context, relay lists, and prior findings.

## Execution Guidelines

- **Execute, don't just explain.** Construct and run the nak command. Show
  both the command and its output.
- **Confirm before publishing.** Always confirm with the user before writing
  to relays (event, publish commands). Reading is always safe.
- Prefer `nak publish` for text notes — it auto-handles hashtags, mentions,
  NIP-19 references, and relay routing.
- Use `jq` to format and extract from JSON output.
- Use `--sec 01` for demonstrations unless the user provides their key.
- Show the exact command before running it.
- Limit query results with `-l` to avoid flooding output.
- Warn about irreversible actions (publishing is permanent).
