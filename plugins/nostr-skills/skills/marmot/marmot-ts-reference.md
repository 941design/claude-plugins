# marmot-ts — TypeScript API Reference

**Repository:** https://github.com/marmot-protocol/marmot-ts
**npm:** `@internet-privacy/marmot-ts`
**Version:** 0.1.0 (alpha)
**License:** MIT
**Docs:** https://marmot-protocol.github.io/marmot-ts/

## Source Structure

```
src/
  client/
    marmot-client.ts         — Main entry point
    nostr-interface.ts       — Network abstraction
    key-package-manager.ts   — Key lifecycle
    invite-reader.ts         — Gift-wrap + invite lifecycle
    group/
      marmot-group.ts        — Per-group operations
      group-media-store.ts
      group-rumor-history.ts
      proposals/             — Proposal builders
  core/
    protocol.ts              — Constants, event kinds, tags
    group.ts                 — createGroup(), createSimpleGroup()
    credential.ts            — Credential helpers
    key-package.ts           — KeyPackage generation
    welcome.ts               — Welcome creation/parsing
    group-message.ts         — Encrypt/decrypt group events
    marmot-group-data.ts     — TLS encode/decode MarmotGroupData
    media.ts                 — MIP-04 encrypted media
  store/
    group-state-store.ts     — GroupStateStore + backend interface
    key-package-store.ts     — KeyPackageStore
    invite-store.ts          — InviteStore interface
    adapters/
      key-value-group-state-backend.ts
  utils/
    encoding.ts, nostr.ts, relay-url.ts, timestamp.ts
```

## Key Dependencies

- `ts-mls` — Pure TypeScript MLS (RFC 9420) implementation
- `@noble/curves`, `@noble/hashes` — Cryptographic primitives
- `@hpke/core` — Hybrid Public Key Encryption
- `applesauce-core`, `applesauce-common` — Nostr event/filter helpers

---

## Primary Class: `MarmotClient<THistory, TMedia>`

Extends `EventEmitter`. Main entry point.

### Constructor Options

```typescript
interface MarmotClientOptions {
  signer: EventSigner;
  groupStateBackend: KeyValueGroupStateBackend;
  keyPackageStore: KeyPackageStore;
  network: NostrNetworkInterface;
  // Optional: history and media factory functions
}
```

### Key Methods

```typescript
// Create a new encrypted MLS group
createGroup(name: string, options?): Promise<MarmotGroup>

// Join a group from a decrypted Welcome
joinGroupFromWelcome(welcome, ...): Promise<MarmotGroup>

// Preview group metadata from Welcome without joining
readInviteGroupInfo(welcome, ...): Promise<GroupInfo>

// Retrieve a cached group or load from store
getGroup(groupId: string): Promise<MarmotGroup | null>

// Load all stored groups into memory
loadAllGroups(): Promise<void>

// Purge a group from storage and cache
destroyGroup(groupId: string): Promise<void>

// Async generator yielding group array on store changes
watchGroups(): AsyncGenerator<MarmotGroup[]>

// Map ciphersuite names to numeric IDs
getCiphersuiteImpl(): CiphersuiteMap
```

### Events

`groupsUpdated`, `groupLoaded`, `groupCreated`, `groupImported`,
`groupJoined`, `groupUnloaded`, `groupDestroyed`

---

## `MarmotGroup<THistory, TMedia>`

Extends `EventEmitter`. Per-group encrypted communications.

### Key Methods

```typescript
// Send encrypted Nostr event rumors
sendApplicationRumor(event: UnsignedEvent): Promise<void>

// Convenience: send kind 9 chat message
sendChatMessage(content: string): Promise<void>

// Publish MLS proposals
sendProposal(proposal): Promise<void>

// Create proposals via builders
propose(action): Promise<Proposal>

// Create MLS commit with pending proposals, handle Welcome generation
commit(): Promise<CommitResult>

// Rotate leaf key material (self-update)
selfUpdate(): Promise<void>

// Persist pending state changes
save(): Promise<void>

// Add user by kind-443 event, send gift-wrapped Welcome
inviteByKeyPackageEvent(event): Promise<void>

// Async generator: decrypt events, validate, advance MLS state
ingest(): AsyncGenerator<IngestResult>

// MIP-04 encrypted media
encryptMedia(file: Blob): Promise<EncryptedMedia>
decryptMedia(attachment): Promise<Blob>

// Proposal builders
Proposals.inviteUser(): ProposalBuilder
Proposals.removeMember(): ProposalBuilder
Proposals.updateMetadata(): ProposalBuilder
```

### Events

`stateChanged`, `applicationMessage`, `stateSaved`, `destroyed`,
`historyError`

---

## `KeyPackageManager`

Extends `EventEmitter`. MLS key package lifecycle.

```typescript
// Generate key package, store private material, publish kind-443
create(options): Promise<KeyPackage>

// Delete old, create new, remove old private material
rotate(options): Promise<KeyPackage>

// Remove local storage without relay deletion
remove(ref): Promise<void>

// Publish kind-5 deletion for all relay events, remove all local material
purge(): Promise<void>

// Observe Nostr events, record valid kind-443 events
track(events): void

// All locally stored key packages
list(): StoredKeyPackage[]

// Async generator yielding on changes
watchKeyPackages(): AsyncGenerator<StoredKeyPackage[]>
```

---

## `InviteReader`

Extends `EventEmitter`. Group invitation lifecycle.

**State machine:** RECEIVED → UNREAD → SEEN → DELETED

```typescript
// Validate and store kind-1059 gift wraps
ingestEvent(event): void
ingestEvents(events): void

// Decrypt gift wraps, validate Welcome (kind-444) events
decryptGiftWrap(event): Promise<Invite>
decryptGiftWraps(): Promise<Invite[]>

// Retrieve invites by state
getUnread(): Invite[]
getReceived(): GiftWrapEvent[]

// Transition invite to seen
markAsRead(id: string): void

// Async generators
watchUnread(): AsyncGenerator<Invite[]>
watchReceived(): AsyncGenerator<GiftWrapEvent[]>
```

---

## Core Interfaces

### `NostrNetworkInterface`

Applications must implement this to provide relay connectivity:

```typescript
interface NostrNetworkInterface {
  publish(relays: string[], event: NostrEvent):
    Promise<Record<string, PublishResponse>>;
  request(relays: string[], filters: Filter | Filter[]):
    Promise<NostrEvent[]>;
  subscription(relays: string[], filters: Filter | Filter[]):
    Subscribable<NostrEvent>;
  getUserInboxRelays(pubkey: string): Promise<string[]>;
}
```

### `GroupStateStoreBackend`

Bytes-only storage contract:

```typescript
interface GroupStateStoreBackend {
  get(groupId: Uint8Array): Promise<SerializedClientState | null>;
  set(groupId: Uint8Array, state: SerializedClientState): Promise<void>;
  remove(groupId: Uint8Array): Promise<void>;
  list(): Promise<Uint8Array[]>;
}
```

### `KeyValueGroupStateBackend`

Adapter wrapping any key-value store with hex-encoded keys.

### `InviteStore`

```typescript
interface InviteStore {
  received: KeyValueStoreBackend<KnownEvent<kinds.GiftWrap>>;
  unread: KeyValueStoreBackend<Rumor>;
  seen: KeyValueStoreBackend<boolean>;
}
```

---

## Core Types

### `MarmotGroupData`

```typescript
interface MarmotGroupData {
  version: number;              // 1 or 2
  nostrGroupId: Uint8Array;     // 32-byte group identifier
  name: string;
  description: string;
  adminPubkeys: string[];       // Hex-encoded 32-byte public keys
  relays: string[];             // WebSocket URLs
  imageHash: Uint8Array;
  imageKey: Uint8Array;
  imageNonce: Uint8Array;
  imageUploadKey: Uint8Array;
}
```

### Protocol Constants

```typescript
const KEY_PACKAGE_KIND = 443;
const WELCOME_EVENT_KIND = 444;
const GROUP_EVENT_KIND = 445;
const KEY_PACKAGE_RELAY_LIST_KIND = 10051;
const MARMOT_GROUP_DATA_EXTENSION_TYPE = 0xf2ee;
const MARMOT_GROUP_DATA_VERSION = 2;
```

---

## Initialization Pattern

```typescript
import { MarmotClient, KeyValueGroupStateBackend } from
  '@internet-privacy/marmot-ts';

const client = new MarmotClient({
  signer: yourNostrSigner,
  groupStateBackend: new KeyValueGroupStateBackend(localforageInstance),
  keyPackageStore: new KeyPackageStore(keyPackageBackend),
  network: yourNostrNetworkInterface,
});

// Create a group
const group = await client.createGroup("My Group", {
  relays: ["wss://relay.example.com"],
  adminPubkeys: [myPubkey],
});

// Send a message
await group.sendChatMessage("Hello, encrypted world!");

// Ingest messages (async generator)
for await (const result of group.ingest()) {
  // Handle decrypted messages, commits, proposals
}
```

---

## Key Differences from MDK (Rust)

| Aspect | MDK | marmot-ts |
|---|---|---|
| MLS library | OpenMLS (Rust-native) | ts-mls (pure TypeScript) |
| Storage | Trait-based, SQLite/memory | Interface-based, any KV store |
| Network | Direct Nostr client | Bring-your-own via NostrNetworkInterface |
| Platform | Native, Tauri | Browser, Node.js 20+, Bun 1.1+, Deno 2.0+ |
| Event model | Synchronous state machine | Async generators, EventEmitter |
| Group data encoding | TLS encoding | Same TLS encoding, version-aware |
