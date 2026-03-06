# Marmot Protocol Overview

## What Is Marmot?

The Marmot Protocol specifies efficient end-to-end encrypted group messaging by
combining two technologies:

- **MLS (Messaging Layer Security, RFC 9420)** — cryptographic group key
  agreement providing forward secrecy and post-compromise security.
- **Nostr** — decentralized identity (secp256k1 keypairs) and relay-based
  message transport.

The protocol evolved from **NIP-EE**, a Nostr Implementation Possibility for
integrating MLS into Nostr messaging. Marmot broadens NIP-EE's scope with its
own specification system (MIPs) covering media, group management, and more.

**Status:** Experimental. Not formally audited. Pre-1.0 across all
implementations.

## Problems Solved

| Existing System | Limitation | Marmot's Answer |
|---|---|---|
| Signal | Centralized, phone-number identity | Decentralized via Nostr, keypair identity |
| NIP-04/NIP-17 | No forward secrecy, no group messaging | MLS provides FS + post-compromise security |
| Matrix/XMPP | Complex server federation, metadata exposure | Untrusted relays, ephemeral keys hide metadata |

## Security Properties

- **Forward Secrecy** — past messages stay secure if current keys are
  compromised.
- **Post-Compromise Security** — key rotation limits impact of future
  compromise.
- **Identity Separation** — MLS signing keys are distinct from Nostr identity
  keys; compromising Nostr keys does not reveal MLS messages.
- **Metadata Protection** — only a Nostr group ID (`h` tag) is visible on
  relays; group events use ephemeral keypairs.

## Cryptographic Parameters

| Parameter | Value |
|---|---|
| Default Ciphersuite | `MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519` (0x0001) |
| Credential Type | BasicCredential (32-byte raw Nostr public key) |
| Custom Extension ID | `0xF2EE` ("Be FREE") |
| Outer Encryption | ChaCha20-Poly1305 |
| Image Encryption | ChaCha20-Poly1305 with HKDF-derived keys |
| Serialization | TLS presentation language, QUIC-style varints (v2) |

## Nostr Event Kinds

| Kind | Name | Purpose |
|---|---|---|
| 443 | KeyPackage Event | Publishes MLS KeyPackages for discovery |
| 444 | Welcome Event | Private group invitation (NIP-59 gift-wrapped) |
| 445 | Group Event | Encrypted group messages, proposals, commits |
| 10051 | KeyPackage Relay List | Advertises relay locations for KeyPackages |

## Referenced Standards

- **RFC 9420** — MLS Protocol
- **NIP-59** — Gift Wrap (Welcome delivery)
- **NIP-44** — Versioned Encryption (gift wrap encryption)
- **NIP-70** — Protected Events (optional KeyPackage protection)
- **RFC 5869** — HKDF (key derivation for media)

## Primary Repositories

| Repository | URL |
|---|---|
| Specification | https://github.com/marmot-protocol/marmot |
| MDK (Rust) | https://github.com/parres-hq/mdk |
| marmot-ts | https://github.com/marmot-protocol/marmot-ts |
| WhiteNoise | https://github.com/marmot-protocol/whitenoise-rs |
| marmots-web-chat | https://github.com/marmot-protocol/marmots-web-chat |
| TS Documentation | https://marmot-protocol.github.io/marmot-ts/ |
