# Common Tasks Across SDKs

Side-by-side snippets for the most common Nostr operations across the major
language SDKs. These are starting points — fetch live docs to confirm
current API surfaces before shipping.

## 1. Generate a keypair / encode npub

### nostr-tools (TS)
```ts
import { generateSecretKey, getPublicKey } from 'nostr-tools'
import { nip19 } from 'nostr-tools'

const sk = generateSecretKey()             // Uint8Array
const pk = getPublicKey(sk)                 // hex string
const npub = nip19.npubEncode(pk)
const nsec = nip19.nsecEncode(sk)
```

### NDK (TS)
```ts
import { NDKPrivateKeySigner } from '@nostr-dev-kit/ndk'

const signer = NDKPrivateKeySigner.generate()
const user = await signer.user()
console.log(user.npub)
```

### rust-nostr (Rust)
```rust
use nostr_sdk::prelude::*;

let keys = Keys::generate();
println!("npub: {}", keys.public_key().to_bech32()?);
println!("nsec: {}", keys.secret_key().to_bech32()?);
```

### fiatjaf.com/nostr (Go)
```go
import "fiatjaf.com/nostr"
import "fiatjaf.com/nostr/nip19"

sk := nostr.GeneratePrivateKey()
pk, _ := nostr.GetPublicKey(sk)
npub, _ := nip19.EncodePublicKey(pk)
```

### pynostr (Python)
```python
from pynostr.key import PrivateKey

pk = PrivateKey()
print(pk.public_key.bech32())   # npub...
print(pk.bech32())              # nsec...
```

### nostr-sdk-ios (Swift)
```swift
import NostrSDK

let keypair = Keypair()!
print(keypair.publicKey.npub)
print(keypair.privateKey.nsec)
```

### nostr-sdk-jvm (Kotlin)
```kotlin
import rust.nostr.sdk.Keys

val keys = Keys.generate()
println("npub: ${keys.publicKey().toBech32()}")
```

## 2. Publish a kind-1 text note

### nostr-tools (TS)
```ts
import { finalizeEvent, Relay } from 'nostr-tools'

const event = finalizeEvent({
  kind: 1,
  created_at: Math.floor(Date.now() / 1000),
  tags: [],
  content: 'hello nostr',
}, sk)

const relay = await Relay.connect('wss://relay.damus.io')
await relay.publish(event)
```

### NDK (TS)
```ts
import NDK, { NDKEvent } from '@nostr-dev-kit/ndk'

const ndk = new NDK({ explicitRelayUrls: ['wss://relay.damus.io'], signer })
await ndk.connect()

const event = new NDKEvent(ndk)
event.kind = 1
event.content = 'hello nostr'
await event.publish()
```

### rust-nostr (Rust)
```rust
let client = Client::new(&keys);
client.add_relay("wss://relay.damus.io").await?;
client.connect().await;
client.publish_text_note("hello nostr", []).await?;
```

### fiatjaf.com/nostr (Go)
```go
ev := nostr.Event{
    Kind:      1,
    CreatedAt: nostr.Now(),
    Content:   "hello nostr",
}
ev.Sign(sk)

relay, _ := nostr.RelayConnect(ctx, "wss://relay.damus.io")
relay.Publish(ctx, ev)
```

### pynostr (Python)
```python
from pynostr.event import Event
from pynostr.relay_manager import RelayManager

ev = Event(content="hello nostr", kind=1)
ev.sign(pk.hex())

rm = RelayManager(timeout=2)
rm.add_relay("wss://relay.damus.io")
rm.publish_event(ev)
rm.run_sync()
```

## 3. Subscribe to a filter

### nostr-tools (TS)
```ts
const sub = relay.subscribe([{ kinds: [1], limit: 20 }], {
  onevent(ev) { console.log(ev) },
  oneose() { sub.close() },
})
```

### NDK (TS)
```ts
const sub = ndk.subscribe({ kinds: [1], limit: 20 }, { closeOnEose: true })
sub.on('event', (ev) => console.log(ev.rawEvent()))
```

### rust-nostr (Rust)
```rust
let filter = Filter::new().kinds([Kind::TextNote]).limit(20);
let events = client.get_events_of(vec![filter], None).await?;
```

### fiatjaf.com/nostr (Go)
```go
sub, _ := relay.Subscribe(ctx, nostr.Filters{
    {Kinds: []int{1}, Limit: 20},
})
for ev := range sub.Events {
    fmt.Println(ev)
}
```

## 4. Connect to a NIP-46 bunker

### nostr-tools (TS)
```ts
import { BunkerSigner, parseBunkerInput } from 'nostr-tools/nip46'

const ptr = await parseBunkerInput('bunker://...')
const signer = new BunkerSigner(localSecretKey, ptr)
await signer.connect()
const event = await signer.signEvent({ kind: 1, content: 'hi', tags: [] })
```

### NDK (TS)
```ts
import { NDKNip46Signer } from '@nostr-dev-kit/ndk'

const remote = new NDKNip46Signer(ndk, bunkerPubkey, { relayUrls, secret })
await remote.blockUntilReady()
ndk.signer = remote
```

### rust-nostr (Rust)
```rust
let app_keys = Keys::generate();
let signer = Nip46Signer::new(uri, app_keys, Duration::from_secs(60), None).await?;
let client = Client::with_signer(signer);
```

### nostr-sdk-jvm (Kotlin)
```kotlin
val appKeys = Keys.generate()
val signer = NostrConnect(uri, appKeys, 60u, null)
val client = ClientBuilder().signer(signer).build()
```

## Notes

- All examples are illustrative; consult each library's README/changelog
  for the exact current API.
- For NIP-46 / NIP-07 / NIP-55 specifics see the **remote-signing** skill.
- For Marmot/MLS group messaging see the **marmot** skill.
