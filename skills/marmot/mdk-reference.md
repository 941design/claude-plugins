# MDK (Marmot Development Kit) — Rust API Reference

**Repository:** https://github.com/parres-hq/mdk
**Crate:** `mdk-core` v0.7.1
**License:** MIT

## Crate Structure

```
crates/
  mdk-core/            — Main library: MLS + Nostr integration
  mdk-storage-traits/  — Storage abstraction layer
  mdk-memory-storage/  — In-memory backend (testing)
  mdk-sqlite-storage/  — SQLite backend (production)
```

## Key Dependencies

| Crate | Version | Role |
|---|---|---|
| `openmls` | 0.8.1 | MLS protocol (RFC 9420) |
| `openmls_rust_crypto` | 0.8.1 | Cryptographic backend |
| `nostr` | 0.44 | Nostr protocol types |
| `chacha20poly1305` | workspace | Outer encryption |
| `tls_codec` | workspace | TLS serialization |

---

## Primary Struct: `MDK<Storage>`

The entry point for all protocol operations.

```rust
pub struct MDK<Storage: MdkStorageProvider> {
    pub ciphersuite: Ciphersuite,
    pub extensions: Vec<ExtensionType>,
    pub provider: MdkProvider<Storage>,
    pub config: MdkConfig,
    epoch_snapshots: Arc<EpochSnapshotManager>,
    callback: Option<Arc<dyn MdkCallback>>,
}
```

### Configuration: `MdkConfig`

```rust
pub struct MdkConfig {
    pub max_event_age_secs: u64,          // Default: 3888000 (45 days)
    pub max_future_skew_secs: u64,        // Default: 300 (5 minutes)
    pub out_of_order_tolerance: u32,      // Default: 100
    pub maximum_forward_distance: u32,    // Default: 1000
    pub max_past_epochs: usize,           // Default: 5
    pub epoch_snapshot_retention: usize,  // Default: 5
    pub snapshot_ttl_seconds: u64,        // Default: 604800 (1 week)
}
```

---

## API Methods

### Key Package Operations

```rust
// Generate a KeyPackage for kind 443 event publication
create_key_package_for_event() -> Result<(base64_content, tags)>

// Validate and deserialize a KeyPackage from a Nostr event
parse_key_package(event) -> Result<KeyPackage>

// Remove consumed KeyPackages from storage
delete_key_package_from_storage(ref) -> Result<()>
```

### Group Lifecycle

```rust
// Create a new group with initial members
create_group(creator_pk, member_kp_events, config) -> Result<GroupResult>

// Retrieve a specific group
get_group(group_id) -> Result<Option<Group>>

// List all groups
get_groups() -> Result<Vec<Group>>

// Finalize a pending Commit
merge_pending_commit(group_id) -> Result<()>

// Cancel a pending Commit
clear_pending_commit(group_id) -> Result<()>
```

### Member Management

```rust
// List group members
get_members(group_id) -> Result<BTreeSet<PublicKey>>

// Add members via their KeyPackage events
add_members(group_id, kp_events) -> Result<UpdateGroupResult>

// Remove members by public key
remove_members(group_id, pubkeys) -> Result<UpdateGroupResult>

// Check pending additions/removals
pending_member_changes(group_id) -> Result<PendingMemberChanges>
```

### Group Updates

```rust
// Update group metadata (name, description, relays, etc.)
update_group_data(group_id, update) -> Result<UpdateGroupResult>

// Rotate own signing key material
self_update(group_id) -> Result<UpdateGroupResult>

// Leave a group
leave_group(group_id) -> Result<UpdateGroupResult>
```

### Welcome Processing

```rust
// Parse a received Welcome event
process_welcome(wrapper_event_id, rumor_event) -> Result<Welcome>

// Join a group from a Welcome
accept_welcome(welcome) -> Result<()>

// Decline a Welcome invitation
decline_welcome(welcome) -> Result<()>

// List pending Welcomes
get_pending_welcomes(pagination) -> Result<Vec<Welcome>>
```

### Message Operations

```rust
// Encrypt and wrap a message for the group
create_message(group_id, rumor) -> Result<Event>

// Decrypt and classify a received event
process_message(event) -> Result<MessageProcessingResult>

// Retrieve group message history
get_messages(group_id, pagination) -> Result<Vec<Message>>
```

### Inspection

```rust
get_ratchet_tree_info(group_id) -> Result<RatchetTreeInfo>
get_relays(group_id) -> Result<BTreeSet<RelayUrl>>
exporter_secret(group_id) -> Result<GroupExporterSecret>
groups_needing_self_update(threshold_secs) -> Result<Vec<GroupId>>
```

---

## Key Enums

### `MessageProcessingResult`

```rust
pub enum MessageProcessingResult {
    ApplicationMessage(Message),     // Decrypted chat/reaction
    Proposal(UpdateGroupResult),     // Membership/settings change
    PendingProposal { mls_group_id },// Cached awaiting Commit
    IgnoredProposal { mls_group_id, reason }, // Rejected
    ExternalJoinProposal { mls_group_id },
    Commit { mls_group_id },         // Epoch advancement
    Unprocessable { mls_group_id },  // Decryption failed
    PreviouslyFailed,                // Already attempted
}
```

### `Backend`

```rust
pub enum Backend { Memory, SQLite }
```

### `MessageSortOrder`

```rust
pub enum MessageSortOrder {
    CreatedAtFirst,    // Sender timestamp
    ProcessedAtFirst,  // Local reception order
}
```

---

## Key Structs

```rust
pub struct GroupResult {
    pub group: Group,
    pub welcome_rumors: Vec<UnsignedEvent>,
}

pub struct UpdateGroupResult {
    pub evolution_event: Event,
    pub welcome_rumors: Option<Vec<UnsignedEvent>>,
    pub mls_group_id: GroupId,
}

pub struct NostrGroupConfigData {
    pub name: String,
    pub description: String,
    pub image_hash: Option<[u8; 32]>,
    pub image_key: Option<[u8; 32]>,
    pub image_nonce: Option<[u8; 12]>,
    pub relays: Vec<RelayUrl>,
    pub admins: Vec<PublicKey>,
}

pub struct PendingMemberChanges {
    pub additions: Vec<PublicKey>,
    pub removals: Vec<PublicKey>,
}

pub struct EpochSnapshot {
    pub group_id: GroupId,
    pub epoch: u64,
    pub applied_commit_id: EventId,
    pub applied_commit_ts: u64,
    pub created_at: Instant,
    pub snapshot_name: String,
}

pub struct RollbackInfo {
    pub group_id: GroupId,
    pub target_epoch: u64,
    pub new_head_event: EventId,
    pub invalidated_messages: Vec<EventId>,
    pub messages_needing_refetch: Vec<EventId>,
}
```

---

## Key Traits

### `MdkStorageProvider`

Central storage abstraction composed of sub-traits:

```rust
pub trait MdkStorageProvider:
    GroupStorage + MessageStorage + WelcomeStorage
    + StorageProvider<CURRENT_VERSION>
{
    fn backend(&self) -> Backend;
    fn create_group_snapshot(&self, group_id, name) -> Result<()>;
    fn rollback_group_to_snapshot(&self, group_id, name) -> Result<()>;
    fn release_group_snapshot(&self, group_id, name) -> Result<()>;
    fn list_group_snapshots(&self, group_id) -> Result<Vec<(String, u64)>>;
    fn prune_expired_snapshots(&self, min_timestamp) -> Result<usize>;
}
```

**Sub-traits:**
- `GroupStorage` — `all_groups()`, `find_group_by_*()`, `save_group()`,
  `messages()`, `admins()`, `group_relays()`, exporter secrets
- `MessageStorage` — `save_message()`, `find_message_by_event_id()`,
  `invalidate_messages_after_epoch()`, retry management
- `WelcomeStorage` — welcome persistence and retrieval

### `MdkCallback`

Event notification interface:

```rust
pub trait MdkCallback: Send + Sync + Debug {
    fn on_rollback(&self, info: &RollbackInfo);
}
```

---

## Storage Backends

### In-Memory (mdk-memory-storage)

For testing and development. All state lost on process exit.

### SQLite (mdk-sqlite-storage)

Production backend with three encryption modes:
1. **Automatic** — platform keyring manages the encryption key
2. **Manual** — application provides the encryption key
3. **Unencrypted** — development only
