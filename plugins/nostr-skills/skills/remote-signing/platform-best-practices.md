# Platform Best Practices

## PWA (Progressive Web Apps)

### The Platform Challenge

PWAs face the hardest key management landscape:
- No native extension support (NIP-07 unavailable when installed standalone)
- No OS keychain or intent system (NIP-55) access
- Service workers terminated by OS at any time, especially on mobile
- IndexedDB/localStorage are the only persistent storage, both accessible to
  same-origin JavaScript

### Recommended Approaches

**Primary: NIP-46 Remote Signing**

NIP-46 is the strongest option for PWAs:
- Private key never enters the PWA's execution context
- Works across all platforms (iOS, Android, desktop)
- PWA only holds a disposable client keypair
- Signing requests encrypted with NIP-44 over Nostr relays

**Secondary: Web Signer Integration (nsec.app pattern)**

- Keys stored non-custodially, encrypted with user-defined password
- NIP-46 signer runs inside a **service worker** for background signing
- Companion server sends **push notifications** (VAPID) to wake the worker
- **iframe + postMessage** pattern provides origin isolation
- E2E encrypted server sync for cross-device access

**Fallback: Encrypted Local Storage**

If keys must be stored locally:
- Use **Web Crypto API** for non-extractable CryptoKey objects in IndexedDB
- Caveat: non-extractable keys are obfuscation, not true security (Spectre,
  compromised render process can extract)
- If storing raw key material, encrypt with NIP-49 (ncryptsec)
- Use scrypt LOG_N >= 16 (64 MiB memory)

### Service Worker Considerations

- Can run NIP-46 signer logic in background
- Push notifications wake sleeping workers for signing requests
- **Unreliable on mobile** when phone is locked
- Share same-origin security boundary — XSS in main page can access worker state
- Mitigation: import keys on every device rather than relying on cross-device
  service worker wakeups

### Cross-Origin Security

- iframe + postMessage pattern (nsec.app) provides origin isolation
- Signer in different origin than client app
- XSS in client cannot directly access keys in signer's origin
- But attacker could still request signatures through postMessage channel
- Signer should implement per-request user approval for sensitive operations

---

## Web Applications

### NIP-07 Integration

Always check for `window.nostr` before use:
```typescript
if (window.nostr) {
    const pubkey = await window.nostr.getPublicKey();
    const signed = await window.nostr.signEvent(unsignedEvent);
}
```

Best practices:
- Implement fallback for users without extensions (NIP-46 or read-only mode)
- Never request the private key — extension handles all signing
- All methods return Promises — handle async correctly

### NIP-46 Integration

**Connection from bunker:// URI:**
```typescript
// Parse bunker URI → extract signer pubkey, relays, secret
// Generate ephemeral client keypair
// Connect to relays, subscribe to kind 24133 for client pubkey
// Send connect request with secret
// Handle auth_url responses (display URL, don't auto-open)
// Store client keypair for session resumption
```

**Critical implementation details:**
- First param of `connect` MUST be remote-signer pubkey (not client pubkey)
- Always pass secret as second parameter
- Handle relay disconnects: reconnect + re-subscribe
- Ignore duplicate `auth_url` and duplicate replies
- Use NIP-46-dedicated relays to avoid rate limiting

### Handling Signing Requests

- **Queue** requests when signer temporarily unavailable
- **Timeout** at 30–60 seconds for interactive requests
- **Retry** with exponential backoff
- **User feedback** — show clear status while waiting for approval
- **Auth challenges** — handle `auth_url` responses gracefully

### Security Guidelines

- **Never accept nsec input for login** — provide NIP-07 and NIP-46
- **Detect accidental nsec paste** in text fields — warn before submission
- **Never store raw keys** in localStorage or cookies
- If keys must be stored locally, use ncryptsec (NIP-49)

---

## Desktop Applications

### OS Keychain Integration

| Platform | Facility | Integration |
|----------|----------|-------------|
| macOS | Keychain | keyring crate (Rust), Tauri keyring plugin |
| Windows | Credential Manager | DPAPI, Tauri keyring plugin |
| Linux | Secret Service (GNOME Keyring, KWallet) | libsecret, keyring crate |

### Tauri Patterns

**Keyring Plugin (recommended):**
- Wraps OS credential managers transparently
- Store encryption key in OS keychain
- Use that key to encrypt/decrypt Nostr private key on disk
- Provides both at-rest encryption and OS-level access control

**Stronghold Plugin (deprecated in v3):**
- IOTA Stronghold engine for write-only vault
- Data can be written and deleted but not directly read back

### Desktop Client Key Management

**Gossip model (gold standard):**
- Keys encrypted under passphrase on disk
- Passphrase required on startup
- Memory zeroed before freeing
- Can serve as NIP-46 bunker for other applications

**Recommended combined pattern:**
1. Store primary encryption key in OS keychain via keyring
2. Use that key to encrypt/decrypt the Nostr private key on disk
3. Zero key material from memory after use
4. Optionally serve as NIP-46 bunker for browser/mobile apps

### NIP-46 Desktop Roles

**As client:** Desktop app connects to remote signer (nsec.app, Amber, bunker)
**As bunker:** Desktop app (Gossip, Keystr) holds key and responds to signing
requests from web/mobile apps

---

## Universal Security Rules

### Never Expose nsec in Plaintext

- Never log private keys to console or crash reports
- Never transmit over the network
- Never store in plain text (localStorage, config files, databases)
- Detect `nsec1` prefix in text inputs and warn
- Use copy-to-clipboard without visual display

### Memory Safety

**Rust/native (Gossip pattern):**
- `explicit_bzero` or equivalent to zero memory
- Prevent key material from being swapped to disk
- Exclude from core dumps

**JavaScript/TypeScript:**
- Strings are immutable — cannot securely clear from memory
- Use `Uint8Array` for key material, zero-fill when done: `keyBytes.fill(0)`
- Avoid converting key bytes to strings until necessary
- Web Crypto non-extractable CryptoKey = obfuscation, not security
- Garbage collection is non-deterministic — copies may persist

### Backup and Recovery

- Copy private key to password manager immediately on creation
- Write nsec on paper → physically secure location
- Use ncryptsec format for digital backups
- Create multiple backups in different locations
- **Test recovery** on a fresh device before relying on backups
- Never store backups in unencrypted cloud storage, email, or screenshots

### Multi-Device Strategies

1. **Remote signer (recommended):** NIP-46 to single trusted device; all
   others connect as clients; revoke per-device
2. **Encrypted key sync (nsec.app):** E2E encrypted server storage; each
   device decrypts locally
3. **Purpose-scoped keys:** Separate keys for different security levels
4. **Threshold signing (FROSTR):** M-of-N shares across devices

---

## UX Patterns

### Onboarding

**Progressive disclosure is essential:**
- Don't explain keys during initial signup
- Minimum viable onboarding: name entry + auto key generation
- Delay key backup to after user has experienced value
- Target: under 2 minutes to first content

**Recommended flow:**
1. Name entry (low friction)
2. Optional interests/topics (low friction)
3. Auto-follow curated accounts for immediate content
4. **After engagement:** prompt for key backup
5. **Later:** introduce extensions, bunkers, advanced key management

### Login/Connect Flows

**Multi-method flow:**
1. Check `window.nostr` (NIP-07 extension present?)
2. If yes → "Login with Extension" as primary option
3. Always offer "Login with Nostr Connect" (NIP-46) as alternative
4. Optionally offer "Read-only" mode (npub only)
5. Discourage or block raw nsec input with warning

**nostr-login library** provides this out of the box:
```html
<script src="https://www.unpkg.com/nostr-login@latest/dist/unpkg.js"
  data-dark-mode="true"
  data-bunkers="nsec.app,highlighter.com"
  data-perms="sign_event:1,nip44_encrypt">
</script>
```

### Permission Approval

- Clear descriptions of what each permission grants
- Logical grouping (signing, encryption, key access)
- Granular per-kind signing permissions
- "Always allow" and "ask every time" options
- Clear audit trail of app access
- One-click revocation

### Offline Bunker Handling

- Display clear connection status (connected/connecting/disconnected)
- Queue actions when bunker unreachable
- Offer retry with clear feedback
- Fallback: "Signer offline. Switch to read-only mode?"
- Warn mobile users that locking phone may interrupt service worker

### Abstracting NIP-46 Complexity

From user perspective, NIP-46 should feel like:
1. Scan QR code or paste connection string
2. Approve connection on signer device
3. Use app normally — signing is transparent

Technical details (relays, keypairs, encryption) should be hidden from
non-technical users.

---

## Platform Recommendation Summary

| Concern | PWA | Web App | Desktop App |
|---------|-----|---------|-------------|
| **Signer** | NIP-46 bunker | NIP-07 + NIP-46 fallback | OS keychain + local encrypted |
| **Key storage** | Never local | Extension handles | Encrypted on disk + keychain |
| **iOS** | NIP-46 via nsec.app | NIP-07 via Safari ext | N/A |
| **Android** | NIP-46 or NIP-55 | NIP-46 | N/A |
| **Backup** | ncryptsec (NIP-49) | ncryptsec (NIP-49) | ncryptsec (NIP-49) |
| **Memory** | Uint8Array, zero-fill | Uint8Array, zero-fill | Zero before free |
| **Multi-device** | NIP-46 to bunker | NIP-46 to bunker | Act as bunker |
| **Login UX** | nostr-login + NIP-46 | nostr-login + ext detect | Passphrase on startup |
