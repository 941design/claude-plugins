# Signer Implementations

## Comparison Matrix

| Implementation | Platform | NIPs | Key Location | Server Required | Best For |
|---------------|----------|------|-------------|----------------|----------|
| **nsecbunkerd** | Server (Node.js/Docker) | 46 | Encrypted on server | Yes | Teams, organizations |
| **nsec.app** | Web PWA | 46 | E2E encrypted server | No (hosted) | Non-technical, multi-device |
| **Amber** | Android | 46, 55 | Android device | No | Android, phone-as-bunker |
| **Aegis** | Android + Desktop (Flutter) | 46, 55 | Local device | No | Cross-platform, local relay |
| **nos2x** | Chromium | 07 | Extension storage | No | Simple browser signing |
| **Alby** | Chrome, Firefox | 07 | Extension storage | No | Lightning + Nostr |
| **nostr-keyx** | Chromium | 07 | OS keychain / YubiKey | No | Security-conscious browser |
| **Gossip** | Desktop (Rust) | 46 | Encrypted on disk | No | Power users, desktop bunker |
| **Igloo (FROSTR)** | Desktop | Custom FROST | Distributed shares | No | Maximum security |

---

## nsecbunkerd (kind-0)

- **Repo:** https://github.com/kind-0/nsecbunkerd
- **Language:** TypeScript (95.9%)
- **License:** MIT
- **Platform:** Server (Node.js v18+, Docker)

### Architecture

Headless daemon holding encrypted private keys, responding to NIP-46 requests.

**Two-key system:**
- **Bunker Key:** Admin communication. Low-risk if exposed alone.
- **User Keys:** Encrypted at rest with LND-style passphrases. Must be
  unlocked at every daemon restart. Loss of passphrase = permanent key loss.

**Stack:** Node.js + Prisma ORM + Docker

### Policy System (v2)

- **Access Tokens:** Per-method, per-kind restrictions, expiration dates,
  usage count limits
- **Per-session auth:** First login generates 30-second admin approval request
- **"Always allow":** After initial approval per event kind, auto-approve
- **Admin:** Only designated `ADMIN_NPUBS` can manage the instance

### Deployment

**Docker (recommended):**
```bash
mkdir $HOME/.nsecbunker-config
cp .env.example .env
# Set ADMIN_NPUBS and DATABASE_URL in .env
docker compose build nsecbunkerd
docker compose up -d
docker compose exec nsecbunkerd cat /app/config/connection.txt
```

**Manual:**
```bash
git clone https://github.com/kind-0/nsecbunkerd
npm i && npm run build
npx prisma migrate deploy
npm run nsecbunkerd -- add --name <key-name>
```

**StartOS:** Community package at https://github.com/hzrd149/nsecbunker-startos

**Hosted:** `app.nsecbunker.com` — paid subscription with Lightning payments

---

## nsec.app (Noauth)

- **Repo:** https://github.com/nostrband/noauth
- **Website:** https://nsec.app/
- **Platform:** Web (PWA), any browser

### Architecture

NIP-46 signer running inside a **browser service worker**.

- Keys encrypted locally with user-defined password (brute-force resistant KDF)
- Encrypted keys synced to nsec.app server for cross-device access (E2E encrypted)
- **Push notifications** (VAPID) wake dormant service workers for signing
- **iframe + postMessage** pattern enables embedding in other web apps

### Permission Levels

- **Basic:** Auto-approve all interactions
- **On demand:** Each new interaction type requires manual approval
- Per-app revocation available

### Limitations

Service workers unreliable when phone is locked. Mitigation: import keys on
every device rather than relying on cross-device wakeups.

---

## Amber (Android)

- **Repo:** https://github.com/greenart7c3/Amber
- **Language:** Kotlin (98.7%)
- **License:** MIT

### Dual Role

1. **NIP-55 local signer:** Android apps invoke via Intents/Content Resolvers.
   nsec never leaves Amber's process.
2. **NIP-46 remote bunker:** Acts as a bunker over Nostr relays, turning the
   phone into a portable signing device.

### Features

- Offline local signing (NIP-55, no internet needed)
- Multiple account support
- Background signing ("remember my choice" for pre-authorized kinds)
- Web app signing via `nostrsigner://` URI scheme
- GPG-signed releases, reproducible Docker builds
- Available via: Zap Store, Obtainium, GitHub, F-Droid

---

## Aegis (Cross-Platform)

- **Repo:** https://github.com/ZharlieW/Aegis
- **Platform:** Android, macOS, Windows, Linux (Flutter)
- **NIPs:** 46, 55

### Features

- Full bunker protocol (`bunker://` and `nostrconnect://`)
- Android Content Provider / Intent / `nostrsigner://` URI
- **Built-in local relay** (`wss://127.0.0.1:28443`) for on-device communication
- Multi-account management
- OpenSats grant recipient

---

## Browser Extension Signers

### nos2x

- **Repo:** https://github.com/fiatjaf/nos2x
- **Platform:** Chromium
- **NIP:** 07
- Original and most widely-used browser signer
- Firefox fork: nos2x-fox

### Alby

- **Website:** https://getalby.com
- **Platform:** Chrome, Firefox
- **NIP:** 07
- Lightning wallet + NIP-07 Nostr signing
- Alby team also created "Nostr Signer" mobile app for NIP-46

### nostr-keyx

- **Repo:** https://github.com/susumuota/nostr-keyx
- **Platform:** Chromium (macOS, Windows, Linux)
- **NIP:** 07
- Keys stored in **OS keychain** (macOS Keychain, Windows Credential Manager,
  Linux Secret Service) or **YubiKey**
- Crypto operations execute outside browser memory
- Closest to hardware-backed browser signing

### frost2x

- **Repo:** https://github.com/FROSTR-ORG/frost2x
- **NIP:** 07 + FROST threshold signing
- Part of the FROSTR ecosystem

---

## Desktop Signers

### Gossip

- **Repo:** https://github.com/mikedilger/gossip
- **Platform:** Desktop (Rust, native — no web tech)
- Private keys encrypted under passphrase on disk
- Memory zeroed before freeing
- Acts as NIP-46 bunker for other applications (since v0.10.0)

### Igloo (FROSTR)

- **Org:** https://github.com/FROSTR-ORG
- **Key repos:** bifrost (core), igloo-desktop (app), frost2x (ext)

**FROST threshold signatures:**
- M-of-N shares via Shamir Secret Sharing (e.g., 2-of-3, 3-of-5)
- Individual shares cryptographically useless alone
- Signatures indistinguishable from single-key Schnorr sigs
- Shares rotatable without changing pubkey
- Nostr used as transport between signing nodes

**Igloo Desktop features:**
- Generate keysets or import existing nsec
- Configurable M-of-N threshold
- PBKDF2 encrypted share storage
- QR code share transfer
- Full audit trail
- GPG-signed releases (Win/Mac/Linux)

---

## Other Implementations

| Implementation | Platform | Notes |
|---------------|----------|-------|
| **Nostrum** | iOS/Android (React Native) | Reference NIP-46 mobile signer |
| **Nowser** | Multi-platform | NIP-07, NIP-46, NIP-55 combined |
| **Keystr** | Desktop (Rust) | Dedicated keystore, NIP-46 bunker |
| **Nostria Signer** | Chromium, PWA, native | NIP-07 + NIP-46, experimental |
| **Noauth Enclaved** | Server (AWS Nitro) | NIP-46 in hardware enclave |
| **Hardware wallets** | Physical device | Coldcard MK4/Q1, Passport, Satslink |

---

## Security Spectrum (Most → Least Secure)

1. Hardware wallets — air-gapped
2. FROSTR/Igloo — no single point of compromise
3. Desktop bunker (Gossip) — encrypted, memory-zeroed
4. Server bunker (nsecbunkerd) — encrypted, policy-controlled
5. Phone-as-bunker (Amber) — physical possession
6. PWA signer (nsec.app) — E2E encrypted, service worker
7. OS keychain extension (nostr-keyx) — key in keychain/YubiKey
8. Browser extension (nos2x, Alby) — key in browser memory
9. Raw nsec in client — worst practice
