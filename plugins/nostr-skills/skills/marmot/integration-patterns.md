# Marmot Integration Patterns

Real-world patterns and gotchas from production marmot-ts and MDK integrations.
Sources: notestr (marmot-ts browser + MDK Rust CLI, cross-implementation), quizzl (marmot-ts),
CalPal (MDK FFI). Each pattern is grounded in observed, working code.

---

## marmot-ts Patterns

### 1. NDK as NostrNetworkInterface

NDK can be used as the relay backend for marmot-ts **if you use it correctly**. The
critical constraint: marmot-ts produces pre-signed events (kinds 443, 444, 445, 1059)
with a foreign pubkey and signature. NDK's `publishReplaceable()` and some publish
paths silently drop pre-signed events by re-signing them. Use `NDKEvent.publish(relaySet,
timeoutMs)` instead, which forwards the raw event without re-signing.

A complete, battle-tested NDK adapter (from notestr-web `src/marmot/network.ts`):

```typescript
import NDK, { NDKEvent, NDKRelaySet, NDKSubscription } from "@nostr-dev-kit/ndk";
import type {
  NostrNetworkInterface, PublishResponse, Subscribable,
  Observer, Unsubscribable,
} from "@internet-privacy/marmot-ts";
import type { NostrEvent } from "applesauce-core/helpers/event";
import type { Filter } from "applesauce-core/helpers/filter";

export class NdkNetworkAdapter implements NostrNetworkInterface {
  constructor(
    private readonly ndk: NDK,
    private readonly defaultRelays: string[] = [],
  ) {}

  async publish(relays: string[], event: NostrEvent): Promise<Record<string, PublishResponse>> {
    const ndkEvent = new NDKEvent(this.ndk, event);
    const relaySet = NDKRelaySet.fromRelayUrls(relays, this.ndk);
    const results: Record<string, PublishResponse> = {};
    try {
      // Timeout required — NDK waits indefinitely for relay OK without one.
      // This stalls the commit/invite flow if a relay is unresponsive.
      const publishedRelays = await ndkEvent.publish(relaySet, 10_000);
      for (const relay of publishedRelays) {
        results[relay.url] = { from: relay.url, ok: true };
      }
      for (const url of relays) {
        if (!(url in results)) {
          results[url] = { from: url, ok: false, message: "No confirmation" };
        }
      }
    } catch (err) {
      for (const url of relays) {
        if (!(url in results)) {
          results[url] = { from: url, ok: false,
            message: err instanceof Error ? err.message : String(err) };
        }
      }
    }
    return results;
  }

  async request(relays: string[], filters: Filter | Filter[]): Promise<NostrEvent[]> {
    const ndkFilters = Array.isArray(filters) ? filters : [filters];
    const relaySet = NDKRelaySet.fromRelayUrls(relays, this.ndk);
    return new Promise<NostrEvent[]>((resolve) => {
      const events: NostrEvent[] = [];
      const sub: NDKSubscription = this.ndk.subscribe(
        ndkFilters as any,
        { closeOnEose: true },
        relaySet,
      );
      sub.on("event", (e: NDKEvent) => events.push(e.rawEvent() as NostrEvent));
      sub.on("eose", () => resolve(events));
      // Safety: resolve after timeout if EOSE never fires.
      const timeout = setTimeout(() => { sub.stop(); resolve(events); }, 15_000);
      sub.on("close", () => clearTimeout(timeout));
    });
  }

  subscription(relays: string[], filters: Filter | Filter[]): Subscribable<NostrEvent> {
    const ndkFilters = Array.isArray(filters) ? filters : [filters];
    const relaySet = NDKRelaySet.fromRelayUrls(relays, this.ndk);
    return {
      subscribe: (observer: Partial<Observer<NostrEvent>>): Unsubscribable => {
        const sub: NDKSubscription = this.ndk.subscribe(
          ndkFilters as any,
          { closeOnEose: false },
          relaySet,
        );
        sub.on("event", (e: NDKEvent) => {
          try { observer.next?.(e.rawEvent() as NostrEvent); }
          catch (err) { observer.error?.(err); }
        });
        sub.on("close", () => observer.complete?.());
        return { unsubscribe(): void { sub.stop(); } };
      },
    };
  }

  async getUserInboxRelays(pubkey: string): Promise<string[]> {
    // Always query default relays — not an empty set.
    const events = await this.request(this.defaultRelays, [
      { kinds: [10051 as any], authors: [pubkey], limit: 1 } as any,
    ]);
    if (events.length === 0) return this.defaultRelays; // fallback required
    const latest = events.sort((a, b) => (b.created_at ?? 0) - (a.created_at ?? 0))[0];
    return latest.tags
      .filter((tag) => tag[0] === "relay" && typeof tag[1] === "string")
      .map((tag) => tag[1]);
  }
}
```

Key rules enforced by this implementation:
- `publish()` is always awaited (never fire-and-forget) and always times out.
- `request()` collects until EOSE with a safety timeout — never returns partial results on timeout (resolves empty, then caller can skip the sync cycle).
- `getUserInboxRelays()` always falls back to `defaultRelays` when kind 10051 is absent.
- `subscription()` is persistent (`closeOnEose: false`).

### 2. MarmotClient initialization in a React context

Pattern from notestr-web `src/marmot/client.tsx`. Key aspects not obvious from the API docs:

```typescript
// Per-store IndexedDB isolation using idb-keyval createStore().
// Each store name gets its own IDB database — avoids IDB version conflicts
// when multiple marmot-ts stores coexist.
function createKVStore<T>(name: string): KeyValueStoreBackend<T> {
  const store = createStore(`notestr-${name}`, name); // (dbName, storeName)
  return {
    async getItem(key) { return (await get<T>(key, store)) ?? null; },
    async setItem(key, value) { await set(key, value, store); return value; },
    async removeItem(key) { await del(key, store); },
    async clear() { await idbClear(store); },
    async keys() { return idbKeys<string>(store); },
  };
}

const client = new MarmotClient({
  signer,                          // applesauce-core EventSigner
  groupStateBackend: new KeyValueGroupStateBackend(createKVStore("group-state")),
  keyPackageStore: new KeyPackageStore(createKVStore("key-packages")),
  network: new NdkNetworkAdapter(ndk, relays),
  clientId,   // stable per-device UUID from IndexedDB — required for kind 30443
});
```

The `clientId` field is the addressable key package `d` slot identifier (kind 30443).
Generate it once with `crypto.randomUUID()`, persist in IndexedDB, and reuse on
subsequent sessions. Without `clientId`, `client.keyPackages.create()` may fail or
produce non-addressable (legacy kind 443) key packages.

InviteStore (three separate IDB stores, not one):

```typescript
const inviteStore: InviteStore = {
  received: createKVStore("invite-received"),
  unread: createKVStore("invite-unread"),
  seen: createKVStore("invite-seen"),
};
const inviteReader = new InviteReader({ signer, store: inviteStore });
```

### 3. Concurrent ingest serialization (per-group mutex)

marmot-ts's `group.ingest()` mutates `this.state` internally. Calling `ingest()` on
the same group concurrently from two different code paths (e.g., live subscription
event arriving while historical batch is still processing) produces race conditions:
`"desired gen in the past"` errors, epoch skips, or state corruption.

**Fix**: Chain every ingest call for a given group onto a single promise using a
per-group lock.

```typescript
const ingestLock = new Map<string, Promise<void>>();

async function ingestGroupEvents(group: MarmotGroup, events: NostrEvent[]): Promise<void> {
  const prev = ingestLock.get(group.idStr) ?? Promise.resolve();
  const next = prev
    .catch(() => undefined)               // don't let prior error block the chain
    .then(() => ingestGroupEventsRaw(group, events));
  ingestLock.set(group.idStr, next);
  try {
    await next;
  } finally {
    // Clear if we're still the tail — lets GC collect resolved promises.
    if (ingestLock.get(group.idStr) === next) ingestLock.delete(group.idStr);
  }
}
```

All code paths that call `group.ingest()` must go through this serialized wrapper.
This includes: initial historical fetch, live subscription handler, retry queue drain,
and any join barrier callback.

### 4. Retry queue for unreadable events (epoch-ordered retry)

`group.ingest()` returns `unreadable` for events whose decryption fails. Common benign
causes:
- The event's epoch is ahead of the local state (missing a commit that hasn't arrived yet).
- A live subscription event arrives before the commit that would advance the local epoch.

These events may become decryptable after the next epoch advance. Park them in a retry
queue and re-ingest on `stateChanged` — but only on a genuine epoch increment (not
within-epoch ratchet advances from `sendApplicationRumor`).

```typescript
import type { NostrEvent } from "applesauce-core/helpers/event";

function createPendingRetryQueue({ maxSize, maxAgeSec }: { maxSize: number; maxAgeSec: number }) {
  const entries = new Map<string, { event: NostrEvent; queuedAt: number }>();
  return {
    enqueue(event: NostrEvent) {
      if (!event.id || entries.has(event.id)) return;
      entries.set(event.id, { event, queuedAt: Date.now() });
      // Evict oldest when cap exceeded.
      while (entries.size > maxSize) {
        const first = entries.keys().next();
        if (!first.done) entries.delete(first.value);
      }
    },
    snapshot(): NostrEvent[] {
      return Array.from(entries.values(), e => e.event);
    },
    remove(eventId: string) { entries.delete(eventId); },
    prune(nowSec = Math.floor(Date.now() / 1000)) {
      for (const [id, entry] of entries) {
        const age = nowSec - Math.floor(entry.queuedAt / 1000);
        if (age > maxAgeSec) entries.delete(id);
      }
    },
    get size() { return entries.size; },
  };
}

// Attach retry logic to each group's stateChanged event:
const lastEpoch = new Map<string, bigint>();

group.on("stateChanged", () => {
  const newEpoch = group.state.groupContext.epoch;
  const prev = lastEpoch.get(group.idStr) ?? 0n;
  if (newEpoch <= prev) return; // ratchet advance within epoch — skip retry
  lastEpoch.set(group.idStr, newEpoch);

  const queue = retryQueues.get(group.idStr);
  if (!queue || queue.size === 0) return;
  queue.prune();
  const pending = queue.snapshot();
  if (pending.length > 0) {
    // Goes through the serialization lock, safe to fire-and-forget here.
    void ingestGroupEvents(group, pending).catch(console.debug);
  }
});

// In your ingest handler:
if (result.kind === "unreadable") {
  queue.enqueue(result.event);
} else if (result.kind === "processed" || result.kind === "skipped" || result.kind === "rejected") {
  queue.remove(result.event.id); // Remove from retry if it now succeeds.
}
```

### 5. Corrected post-join pattern: do NOT pre-seed seen IDs

Prior guidance (and an old pattern in notestr itself) recommended pre-seeding the
"already seen" event ID set with all current relay events after `joinGroupFromWelcome()`,
to prevent re-ingesting them. **This is wrong.**

ts-mls `group.ingest()` handles past-epoch commits as `skipped` with reason `"past-epoch"`.
Re-ingesting events from before the join epoch is safe and produces no state mutation.
The pre-seed approach causes a subtle and dangerous failure: if any commits landed on the
relay BETWEEN when the admin built the Welcome and when the joiner actually processes it
(e.g., the admin auto-invited a sibling device in the background), the joiner marks those
commits as "already seen" and never ingests them. All subsequent messages from the admin —
encrypted at the later epoch — become permanently unreadable.

**Correct post-join pattern:**

1. `joinGroupFromWelcome()` — creates initial group state.
2. Do NOT pre-seed seen IDs.
3. `ingestGroupEvents(group, allHistoricalEvents)` — let ts-mls skip past-epoch events.
4. Subscribe for live events and ingest them through the same serialized path.
5. Optionally: after all historical ingestion is complete, schedule `selfUpdate()` as a
   deferred background operation (not immediately — see below).

### 6. stateChanged fires for epoch changes AND ratchet advances

Every `sendApplicationRumor()` call fires `stateChanged` on the sending group (ratchet
advance within the same epoch). If you use `stateChanged` to trigger epoch-sensitive
logic (retry queue draining, UI updates that only matter on epoch advance), you must
track the previous epoch and skip ratchet-only advances:

```typescript
const previousEpoch = new Map<string, bigint>();
group.on("stateChanged", () => {
  const prev = previousEpoch.get(group.idStr) ?? 0n;
  const next = group.state.groupContext.epoch;
  previousEpoch.set(group.idStr, next);
  const isEpochChange = next !== prev; // true for commits, false for ratchet advances
  if (isEpochChange) {
    // drain retry queue, update epoch-sensitive displays, etc.
  }
});
```

### 7. groupsUpdated fires synchronously during joinGroupFromWelcome

`MarmotClient.joinGroupFromWelcome()` emits `groupsUpdated` synchronously before it
returns. Any `groupsUpdated` listener that triggers group syncing (subscribing to kind
445 events, calling `ingestGroupEvents`) will fire while you are still inside the join
call. This races with any post-join setup you intend to run after `joinGroupFromWelcome`.

**Fix**: Create a promise barrier before joining. Resolve it only after post-join setup
completes. Have sync handlers await it.

```typescript
let joinBarrier: Promise<void> | null = null;

// Before join:
let resolveBarrier!: () => void;
joinBarrier = new Promise<void>((r) => { resolveBarrier = r; });

// In sync handler:
if (joinBarrier) await joinBarrier;
// ... safe to access post-join state now

// After join and post-join setup:
const group = await client.joinGroupFromWelcome({ welcomeRumor });
await markGroupJoinedFromWelcome(group.idStr); // IDB write
resolveBarrier();
joinBarrier = null;
```

### 8. Detached group detection

A "detached" group is one that exists in local storage but whose MLS ratchet tree no
longer includes the local pubkey. This happens when the user is removed by an admin.
The group will appear in `client.groups` but all `sendApplicationRumor()` calls will
fail.

Detect and surface detached groups:

```typescript
import { getGroupMembers } from "@internet-privacy/marmot-ts";

function computeDetachedGroupIds(groups: MarmotGroup[], pubkey: string): Set<string> {
  const set = new Set<string>();
  for (const group of groups) {
    if (!group.state) continue;
    const members = getGroupMembers(group.state);
    if (!members.includes(pubkey)) set.add(group.idStr);
  }
  return set;
}
```

Show detached groups with a visual indicator. Don't attempt to send messages to them.
Offer a "Leave / Clean Up" action that calls `client.destroyGroup(groupId)` to remove
local state.

### 9. Per-leaf removal (targeted member eviction)

To remove a specific MLS leaf node (for multi-device identity management — evicting
one device without removing the Nostr pubkey from the group):

```typescript
import { defaultProposalTypes } from "ts-mls";

async function removeLeafByIndex(group: MarmotGroup, leafIndex: number): Promise<void> {
  await group.commit({
    extraProposals: [
      {
        proposalType: defaultProposalTypes.remove,
        remove: { removed: leafIndex }, // zero-indexed leaf position in ratchet tree
      },
    ],
  });
}
```

Use `group.state.ratchetTree` to enumerate leaves and find the target. The
`defaultKeyPackageEqualityConfig.compareKeyPackageToLeafNode(keyPackage, node.leaf)`
function from `ts-mls` compares a KeyPackage event to a leaf node to identify which
leaf belongs to which device.

### 10. Stale key package cleanup after browser data wipe

When a user clears browser data (IndexedDB), local key package private material is lost
but the kind 443 events published to relays persist. These orphaned events confuse
inviters (they fetch a KP whose private key no longer exists, generate a Welcome the
local client cannot decrypt).

Cleanup strategy (from notestr-web initialization):
1. Fetch all kind 443 events authored by the local pubkey.
2. Compare event IDs against locally stored KP events (`client.keyPackages.list()`).
3. Delete relay events whose IDs have no local match via kind 5 deletion.

**Critical**: Do NOT delete kind 30443 events this way. Kind 30443 is addressable (NIP-33)
and a relay-side replacement. A sibling device on the same identity may own a kind 30443
slot you no longer hold locally — deleting it would evict that device.

```typescript
const remoteKPs = await network.request(relays, [{ kinds: [443], authors: [pubkey] }]);
const localList = await client.keyPackages.list();
const localPublishedIds = new Set(localList.flatMap(kp => kp.published.map(e => e.id)));
const staleIds = remoteKPs.map(e => e.id).filter(id => !localPublishedIds.has(id));

if (staleIds.length > 0) {
  const deleteEvent = {
    kind: 5,
    created_at: Math.floor(Date.now() / 1000),
    tags: [
      ...staleIds.map(id => ["e", id]),
      ["k", "443"],
    ],
    content: "",
    pubkey,
  };
  const signed = await signer.signEvent(deleteEvent);
  await network.publish(relays, signed);
}
```

### 11. Kind 10051 publish guard

Publish kind 10051 only if none exists on the relay yet (to avoid overwriting a relay
list that another device or session already published):

```typescript
import { createKeyPackageRelayListEvent } from "@internet-privacy/marmot-ts";

const existing10051 = await network.request(relays, [
  { kinds: [10051], authors: [pubkey], limit: 1 }
]);
if (existing10051.length === 0) {
  const unsigned = createKeyPackageRelayListEvent({ pubkey, relays });
  const signed = await signer.signEvent(unsigned);
  await network.publish(relays, signed);
}
```

### 12. Multi-device auto-invite — joiner suppression

In a multi-device scenario, when a device joins a group via Welcome, it must NOT
auto-invite its sibling devices. The original creator's auto-invite already handles
siblings, and a second wave of invites from joiners adds duplicate leaves for the same
identity.

The suppression flag must survive page reloads and key package rotations:

```typescript
// On join:
await markGroupJoinedFromWelcome(group.idStr); // persist to IndexedDB

// Before auto-inviting:
async function isJoinerOfGroup(group: MarmotGroup): Promise<boolean> {
  if (await isGroupJoinedFromWelcome(group.idStr)) return true;
  // Fallback check via ratchet tree (before IDB write settles):
  const localPkgs = await client.keyPackages.list();
  for (const pkg of localPkgs) {
    if (!pkg.publicPackage) continue;
    for (const node of group.state.ratchetTree) {
      if (node?.nodeType !== nodeTypes.leaf) continue;
      if (defaultKeyPackageEqualityConfig.compareKeyPackageToLeafNode(
        pkg.publicPackage, node.leaf
      )) return true;
    }
  }
  return false;
}

// Auto-invite logic:
if (inviteePubkey === myPubkey && await isJoinerOfGroup(group)) {
  continue; // suppress — creator handles this
}
```

---

## MDK (Rust) Patterns

### 13. Two SQLite databases — separate MDK from app data

MDK must use its own SQLite file, separate from any application database. OpenMLS does
not support partitioning storage for multiple identities in a single file.

```rust
// Derive MDK db path from main app db path:
fn mdk_db_path_from(app_db_path: &str) -> String {
    if let Some(parent) = std::path::Path::new(app_db_path).parent() {
        parent.join("mdk.db").to_string_lossy().to_string()
    } else {
        "mdk.db".to_string()
    }
}

// Initialize MDK:
let storage = MdkSqliteStorage::new_unencrypted(&mdk_db_path)
    .map_err(|e| format!("MDK init failed: {}", e))?;
let mdk = MDK::new(storage);
```

Use `MdkSqliteStorage::new(service_id, db_key_id)` for production (platform keyring
manages the encryption key). `new_unencrypted()` is only appropriate for development or
when the OS provides filesystem-level encryption.

### 14. MDK is !Send — Tokio app threading pattern

MDK is not Send + Sync. In a Tokio application, all MDK operations must run on a
blocking thread. The correct pattern for combining async relay I/O with synchronous MDK
calls:

```rust
// Background relay task (tokio::spawn) — does I/O only:
tokio::spawn(async move {
    let events = client.fetch_events(filter, timeout).await?;
    tx.send(SyncMessage::GroupMessage { event, group_id }).unwrap();
});

// MDK thread (tokio::task::spawn_blocking):
tokio::task::spawn_blocking(move || {
    // Drain channel, call MDK for each event:
    while let Ok(msg) = rx.try_recv() {
        let result = mdk.process_message(&msg.event)?;
        // handle result...
    }
}).await?;

// From within spawn_blocking, call async relay ops:
let handle = tokio::runtime::Handle::current();
let result = handle.block_on(relay_client.send_event(&commit_event));
```

Architecture: separate the relay I/O (async, tokio) from MLS operations (sync, blocking
thread). Use an unbounded mpsc channel to forward relay events from the async task to
the blocking thread. The blocking thread owns MDK and calls `Handle::current().block_on()`
when it needs async operations (relay publish, relay fetch).

### 15. Publish-then-merge with clear_pending_commit rollback

```rust
let update_result = mdk.add_members(&group_id, &[kp_event])?;

// Publish the commit event first, before merging:
let commit_event = update_result.evolution_event.clone();
let result = handle.block_on(relay::send_event(&client, &commit_event));

let publish_ok = match &result {
    Ok(output) => !output.success.is_empty(), // at least one relay confirmed OK
    Err(_) => false,
};

if !publish_ok {
    // Rollback the pending commit so the group state is consistent:
    let _ = mdk.clear_pending_commit(&group_id);
    return Err("Commit not accepted by any relay; rolled back.".into());
}

// Only merge after successful publish:
mdk.merge_pending_commit(&group_id)?;
```

Failing to call `clear_pending_commit()` after a failed publish leaves MDK in a pending
state where the next operation on the same group will fail.

### 16. Kind 30443 (addressable) and kind 443 (legacy) dual-mode

MDK now exports two key package kind constants. Both must be handled in any relay filter
that fetches key packages:

```rust
use mdk_core::key_packages::{
    MLS_KEY_PACKAGE_KIND as KEY_PACKAGE_KIND,         // 30443 (addressable, current)
    MLS_KEY_PACKAGE_KIND_LEGACY as KEY_PACKAGE_KIND_LEGACY, // 443 (legacy, read-only)
};

// Fetch candidates covering both kinds:
let filter = Filter::new()
    .kinds([KEY_PACKAGE_KIND, KEY_PACKAGE_KIND_LEGACY])
    .author(invitee_pk)
    .limit(16);
```

When building new key package events, use `create_key_package_for_event_with_options()`
which returns a 4-tuple including the `d` tag value for the addressable slot:

```rust
let (encoded, tags, hash_ref, d_tag) = mdk
    .create_key_package_for_event_with_options(
        &public_key,
        relays,
        false,           // is_last_resort
        Some(d_tag_str), // stable per-device slot identifier
    )?;
```

The `d` tag enables NIP-33 addressable replacement: re-publishing with the same slot
replaces the prior event on relays, eliminating accumulation of stale KP events.

### 17. Key package selection ranking (multi-device invite)

When multiple key package events exist for the same pubkey, the correct selection order
for invite targets is (from MDK and notestr CLI `select_invitable_kp`):

1. Reject events that fail KP parsing (corrupt, wrong ciphersuite).
2. Drop KPs whose `d` slot matches the caller's own slot (for self-invite, avoids adding
   duplicate leaf for the same device).
3. Prefer kind 30443 (addressable) over kind 443 (legacy).
4. Prefer non-last-resort KPs over last-resort ones. (Heuristic: check for `["k",
   "last_resort"]` tag on the event — avoids re-parsing the binary KP payload.)
5. Prefer highest `created_at`.
6. Tiebreak: lexicographically smallest event `id` (deterministic — two parallel invite
   calls converge on the same KP).

### 18. Per-leaf removal (remove specific device without removing user)

MDK exposes `get_group_leaves()` and `remove_leaves()` for targeted leaf eviction:

```rust
// Inspect all leaves in the group's ratchet tree:
let leaves: Vec<GroupLeafInfo> = mdk.get_group_leaves(&group_id)?;
// GroupLeafInfo includes: leaf_index, nostr_pubkey, key_package_ref, is_last_resort

// Remove specific leaf indices (0-indexed positions in the ratchet tree):
let update = mdk.remove_leaves(&group_id, &[leaf_index])?;
// Returns UpdateGroupResult; publish evolution_event, merge pending commit.
```

Use this to evict a specific device instance while leaving the Nostr identity in the
group. This is distinct from `remove_members()` which removes all leaves for a given
Nostr pubkey.

### 19. NIP-59 gift wrap must use strict three-layer structure for interop

The correct NIP-59 structure for welcome delivery is three layers:

```
kind 1059 gift wrap
  └── content = NIP-44(ephemeral_sk, receiver, JSON(seal))
      └── kind 13 seal
          └── content = NIP-44(sender_sk, receiver, JSON(rumor))
              └── kind 444 welcome rumor (MDK-generated MLS payload)
```

A collapsed structure (NIP-44 directly wrapping the rumor into the gift wrap content)
is NOT compatible with marmot-ts's `InviteReader` or applesauce's `unlockGiftWrap`.
The plaintext parsed out of the gift wrap is treated as a kind 13 seal and rejected on
the `canHaveEncryptedContent` check.

With nostr-sdk 0.44:

```rust
// Build (publish path):
let gift_wrap = EventBuilder::gift_wrap(signer, recipient, rumor, []).await?;

// Unwrap (receive path):
let unwrapped = nip59::extract_rumor(signer, &gift_wrap).await?;
let rumor = unwrapped.rumor; // kind 444 welcome rumor
```

The `build` and `extract_rumor` paths MUST be symmetric. If one uses strict NIP-59,
both must.

### 20. `merge_pending_commit` may return a non-fatal error on first-ever group

When calling `merge_pending_commit()` immediately after `create_group()` for a brand-new
group (with no members added), MDK may return an error like "No pending commit to merge."
This is non-fatal — the group was created successfully; the error means there was nothing
to merge. Log it at trace/debug level and continue:

```rust
if let Err(e) = mdk.merge_pending_commit(&mls_group_id) {
    tracing::debug!("create_group merge_pending_commit note: {}", e);
}
```

---

## Cross-Implementation Interop (marmot-ts + MDK)

### 21. Wire format compatibility: task application messages

When a marmot-ts client and an MDK client share the same group, both must agree on the
inner event format for application messages. The outer kind 445 ChaCha20+MLS envelope is
protocol-compatible by construction. The inner rumor format is application-defined.

notestr uses kind 31337 rumors for task events:

```typescript
// marmot-ts (send):
const rumor: UnsignedEvent = {
  kind: 31337,
  content: JSON.stringify(taskEvent), // application-specific JSON
  tags: [["t", "task"]],
  created_at: Math.floor(Date.now() / 1000),
  pubkey: senderPubkey,
};
await group.sendApplicationRumor(rumor);

// On receive (applicationMessage event):
const rumor = deserializeApplicationData(data);
if (rumor.kind !== 31337) return; // filter non-task messages
const taskEvent = JSON.parse(rumor.content);
```

```rust
// MDK (send):
let rumor = UnsignedEvent::builder()
    .kind(Kind::Custom(31337))
    .content(serde_json::to_string(&task_event)?)
    .tag(Tag::custom(TagKind::Custom("t".into()), ["task"]))
    .build(sender_pubkey);
let message_event = mdk.create_message(&group_id, rumor)?;

// MDK (receive):
match mdk.process_message(&event)? {
    MessageProcessingResult::ApplicationMessage(msg) => {
        let rumor = &msg.event;
        if rumor.kind == Kind::Custom(31337) {
            let task_event: TaskEvent = serde_json::from_str(&rumor.content)?;
        }
    }
    _ => {}
}
```

The inner rumor `kind` is the cross-implementation contract. Both sides must agree on
which kinds they produce and consume.

### 22. Two group IDs — which to use where

Both marmot-ts and MDK expose two distinct group identifiers per group:

| Identifier | MDK | marmot-ts | Used for |
|---|---|---|---|
| MLS group ID | `group.mls_group_id` (GroupId bytes) | `group.idStr` / `group.id` | Internal storage keys, persistence |
| Nostr group ID | `group.nostr_group_id` (32 bytes) | `getNostrGroupIdHex(group.state)` | Kind 445 `#h` tag, relay filters |

**Rule**: Always use the Nostr group ID for relay subscriptions and kind 445 filtering.
Always use the MLS group ID for storage keys and MDK API calls.

In MDK's `sync.rs`, `nostr_group_id_hex(group)` extracts the nostr group ID for
subscription filters. In marmot-ts, `getNostrGroupIdHex(group.state)` does the same.
The value comes from the `marmotGroupData.nostrGroupId` extension field embedded in the
MLS group context.

### 23. NIP-44 task snapshot for state bootstrapping across implementations

Pre-join MLS messages are undecryptable by new members (MLS forward secrecy). This
applies equally to both marmot-ts and MDK implementations. Use kind 30078 NIP-44 events
out-of-band for state snapshots:

**marmot-ts publisher:**
```typescript
const snapshot = { type: "task.snapshot", tasks: currentTasks };
const encrypted = await signer.nip44!.encrypt(inviteePubkey, JSON.stringify(snapshot));
const event = {
  kind: 30078,
  content: encrypted,
  tags: [
    ["d", `notestr-task-snapshot:${groupHTag}:${inviteePubkey}`],
    ["h", groupHTag],  // nostrGroupId hex
    ["p", inviteePubkey],
  ],
  created_at: Math.floor(Date.now() / 1000),
  pubkey: await signer.getPublicKey(),
};
await network.publish(relays, await signer.signEvent(event));
```

**MDK publisher:**
```rust
// When using NIP-46 signer, use an ephemeral key for NIP-44 encryption
// because the bunker may not support nip44_encrypt directly.
// The invitee queries by #p and #h tags, not by the sender's pubkey.
let ephemeral_keys = Keys::generate();
let encrypted = nostr_sdk::nips::nip44::encrypt(
    ephemeral_keys.secret_key(),
    &invitee_pk,
    snapshot_json.as_bytes(),
    nostr_sdk::nips::nip44::Version::V2,
)?;
let event = EventBuilder::new(Kind::Custom(30078), encrypted)
    .tag(Tag::custom(TagKind::Custom("d".into()), [d_tag_value]))
    .tag(Tag::custom(TagKind::Custom("h".into()), [group_h_tag]))
    .tag(Tag::public_key(invitee_pk))
    .sign_with_keys(&ephemeral_keys)?;
```

**Receiver (both implementations):**
Filter: `{ kinds: [30078], "#h": [groupHTag], "#p": [localPubkey] }`.
Decrypt using whichever NIP-44 key the sender used (check `event.pubkey`).
Apply snapshot before ingesting any MLS messages — the snapshot may be stale relative
to the join epoch, but it provides the task state baseline.
