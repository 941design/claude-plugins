# NIP-19 Encoding, Key Management & Signing

## Decode (NIP-19 → JSON)

Converts any NIP-19 bech32 string to readable JSON.

```
nak decode <nip19-string>
```

### Supported Formats

| Prefix | Entity | Decode output |
|---|---|---|
| `npub1` | Public key | `{"pubkey":"hex"}` |
| `nsec1` | Private key | `{"seckey":"hex"}` (never share!) |
| `note1` | Event ID | `{"id":"hex"}` |
| `nevent1` | Event + hints | `{"id":"hex","relays":["wss://..."],"author":"hex"}` |
| `nprofile1` | Pubkey + hints | `{"pubkey":"hex","relays":["wss://..."]}` |
| `naddr1` | Replaceable event | `{"identifier":"slug","pubkey":"hex","kind":30023,"relays":[...]}` |

### Examples

```bash
# Decode npub to hex
nak decode npub1abc... | jq -r '.pubkey'

# Decode nevent to get ID and relay hints
nak decode nevent1abc...

# Decode naddr to get replaceable event coordinates
nak decode naddr1abc...

# Chain: decode then re-encode
nak decode nevent1abc... | jq -r '.id' | nak encode note
```

## Encode (Data → NIP-19)

Creates NIP-19 bech32 strings from hex data.

```
nak encode <type> [flags]
```

### Types and Flags

| Type | Input | Extra flags | Example |
|---|---|---|---|
| `npub` | hex pubkey (stdin) | | `echo "hex" \| nak encode npub` |
| `nsec` | hex privkey (stdin) | | `echo "hex" \| nak encode nsec` |
| `note` | hex event ID (stdin) | | `echo "hex" \| nak encode note` |
| `nevent` | hex event ID (stdin) | `-r relay`, `-a author` | `echo "hex" \| nak encode nevent -r wss://relay.com` |
| `nprofile` | hex pubkey (stdin) | `-r relay` | `echo "hex" \| nak encode nprofile -r wss://relay.com` |
| `naddr` | (flags only) | `-d id`, `-k kind`, `-a author`, `-r relay` | `nak encode naddr -d slug -k 30023 -a hex` |

### Examples

```bash
# Hex pubkey → npub
echo "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d" | nak encode npub

# Event ID → nevent with relay hint
echo "abc123..." | nak encode nevent -r wss://relay.damus.io

# Pubkey → nprofile with relays
echo "abc123..." | nak encode nprofile -r wss://relay.damus.io -r wss://nos.lol

# Replaceable event → naddr
nak encode naddr -d my-article -k 30023 -a abc123... -r wss://relay.damus.io
```

## Key Management

### Generate Keys

```bash
# Generate new private key (hex)
nak key generate

# Generate and get public key
nak key generate | nak key public

# Generate and encode as nsec
nak key generate | nak encode nsec

# Full keypair
PRIVKEY=$(nak key generate)
echo "nsec: $(echo $PRIVKEY | nak encode nsec)"
echo "npub: $(echo $PRIVKEY | nak key public | nak encode npub)"
```

### Derive Public Key

```bash
# From hex private key
nak key public abc123...

# From stdin
echo "abc123..." | nak key public

# From nsec (decode first)
nak decode nsec1... | jq -r '.seckey' | nak key public
```

### NIP-49 Key Encryption

```bash
# Encrypt a private key
nak key encrypt <hex-privkey> <password>
# Output: ncryptsec1...

# Decrypt
nak key decrypt ncryptsec1... <password>
# Output: hex privkey

# Interactive password (no password argument)
nak key encrypt <hex-privkey>
nak key decrypt ncryptsec1...
```

## NIP-44 Message Encryption

### Encrypt

```bash
# Encrypt message to recipient
nak encrypt <recipient-pubkey-hex> --sec <sender-privkey> "message text"

# From stdin
echo "secret message" | nak encrypt <recipient-pubkey-hex> --sec <sender-privkey>
```

### Decrypt

```bash
# Decrypt message from sender
nak decrypt <sender-pubkey-hex> --sec <recipient-privkey> <ciphertext>
```

## Remote Signing (NIP-46 Bunker)

### Using a Bunker to Sign

```bash
# Sign an event via bunker
nak event -c 'hello' \
  --sec 'bunker://<signer-pubkey>?relay=wss://relay.com&secret=<auth-code>' \
  wss://relay.damus.io

# Set client identity
export NOSTR_CLIENT_KEY=<hex-privkey>
nak event -c 'hello' --sec 'bunker://...' wss://relay.damus.io
```

### Running Your Own Bunker

```bash
# Start bunker
nak bunker --sec ncryptsec1... wss://relay.damus.io wss://nos.lol

# With persistence
nak bunker --persist --sec ncryptsec1... wss://relay.damus.io

# Restart persisted bunker
nak bunker --persist

# Named profiles
nak bunker --profile alice --sec ncryptsec1... wss://relay.damus.io
nak bunker --profile alice

# Accept client connection
nak bunker connect 'nostrconnect://...'
nak bunker connect --profile default 'nostrconnect://...'
```

Output displays bunker URI, QR code, and restart command.

## MuSig2 Collaborative Signing

Multi-party event signing where N parties must cooperate:

```bash
# Signer 1 initiates (2-of-2)
nak event --sec KEY1 -k 1 -c 'collaborative post' --musig 2
# Outputs: event JSON + nonce-secret for signer 2

# Signer 2 completes
nak event --sec KEY2 --musig 2 \
  --ts <same-timestamp> \
  --musig-pubkey <PUBKEY1> \
  --musig-nonce <NONCE_FROM_SIGNER1>
```

## Common Key Patterns

### Test Keys

nak has built-in test keys numbered 01-99:
```bash
nak event --sec 01 -c 'test message'  # Uses test key #01
nak event --sec 02 -c 'another test'  # Uses test key #02
```

### Key from Environment

```bash
export NOSTR_SECRET_KEY=nsec1...
nak event -c 'signed with env key' wss://relay.damus.io
```

### Piping Keys

```bash
# Generate, encrypt, and store
nak key generate | nak key encrypt - mypassword > key.ncryptsec

# Decrypt and use
nak event -c 'hello' --sec $(nak key decrypt $(cat key.ncryptsec) mypassword)
```
