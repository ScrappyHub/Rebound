Rebound ↔ Privacy Sector Bridge v1

Rebound-side canonical integration specification

Status: LOCKED
Applies to: C:\dev\rebound\
Transport law: Packet Constitution v1 — Option A
Identity layer: NeverLost v1
Witness layer: NFL-compatible receipts
Verification plane: WatchTower-compatible

1. Purpose

This document defines the canonical integration between:

Privacy Sector (authoritative vault, encryption, policy gate, receipts)

Rebound (transport broker, packaging layer, routing layer, witness hooks)

This integration allows Privacy Sector vault objects to be transferred deterministically without mutation, reinterpretation, or re-encryption.

Rebound acts only as a transport broker and verifier.

Privacy Sector remains authoritative for vault state.

2. Canonical Authority Boundary
Privacy Sector is authoritative for

encryption and sealing

vault object storage

vault object identifiers

plaintext hash indexing

policy gate enforcement

seal receipts and existence proofs

Rebound is authoritative for

packet transport

packet verification

routing and delivery

transport receipts

witness hooks

Rebound MUST NEVER

decrypt vault objects

re-encrypt vault objects

mutate vault objects

reinterpret payload contents

alter manifest.json

alter sha256sums.txt

alter packet_id.txt

Rebound handles packets as immutable directory bundles.

3. Transport Law Binding

All packets MUST comply with:

Packet Constitution v1 — Option A

Required files:

manifest.json           (WITHOUT packet_id)
packet_id.txt
sha256sums.txt         (generated LAST)
payload/
signatures/


PacketId derivation:

PacketId = SHA-256(canonical_bytes(manifest_without_id))


Verification is non-mutating.

No repair is allowed during verify.

Repair requires explicit repair commands producing separate artifacts.

4. Bridge Packet Payload Contract

Privacy Sector export packets MUST contain:

payload/
  rebound.transmit.intent.json
  vault.ref.json
  receipts.ndjson

rebound.transmit.intent.json

Purpose: transport intent declaration

Example:

{
  "schema": "rebound.transmit.intent.v1",
  "packet_purpose": "privacy.vault.object.transfer",
  "vault_object": "obj_4e9c...",
  "plaintext_sha256": "ab12...",
  "use": "unrecognized"
}

vault.ref.json

Purpose: authoritative vault object reference

Example:

{
  "schema": "vault.ref.v1",
  "object": "obj_4e9c...",
  "plaintext_sha256": "ab12...",
  "vault_version": "v1"
}

receipts.ndjson

Subset of vault receipts proving object existence and seal.

Rebound MUST NOT modify these receipts.

5. Rebound Runtime Directories

Rebound runtime structure:

packets/
  outbox/
  inbox/
  quarantine/
  receipts/


Rules:

inbox contains verified packets

quarantine contains failed packets

receipts contains append-only deterministic logs

6. Rebound Command Contracts

All commands MUST verify before operating.

Verification includes:

PacketId validation

sha256sums validation

signature validation using NeverLost trust bundle

rebound_send_packet_v1.ps1

Purpose: transmit verified packet

Input:

-PacketDir <path>


Process:

Verify packet

Transmit packet via transport layer

Emit receipt:

schema: rebound.send.receipt.v1
packet_id
destination metadata
verification result

rebound_receive_packet_v1.ps1

Purpose: receive packet into inbox

Process:

Verify packet

Move packet into packets/inbox/<PacketId>

On failure move to packets/quarantine/<PacketId>

Emit receipt:

schema: rebound.receive.receipt.v1
packet_id
verification result

rebound_handoff_to_privacy_v1.ps1

Purpose: handoff verified packet to Privacy Sector

Process:

Verify packet

Extract vault.ref.json

Call Privacy Sector import adapter

Emit receipt:

schema: rebound.privacy.ingest.receipt.v1
packet_id
vault_object
result


Rebound does not decrypt vault objects.

7. Receipt Law (Rebound)

Rebound receipts MUST be:

append-only

UTF-8 no BOM

LF newline

deterministic JSON per line

Receipt location:

packets/receipts/rebound.receipts.ndjson


Minimum receipt fields:

schema
packet_id
ok
manifest_sha256
sha256sums_sha256
signature verification state
operation type

8. NeverLost v1 Integration

Rebound MUST use NeverLost v1 trust bundle:

proofs/trust/trust_bundle.json
proofs/trust/allowed_signers


Signature verification MUST use ssh-keygen -Y verify.

Namespace enforcement MUST be active.

9. Test Vector Compliance (Mandatory)

Rebound MUST include:

test_vectors/packet_constitution_v1/


Golden files:

manifest_without_id.canonjson
packet_id.txt
sha256sums.txt


Selftest script:

scripts/_selftest_packet_constitution_v1.ps1


Verification must match golden values exactly.

10. Deterministic Rules

All Rebound scripts MUST:

use UTF-8 no BOM

use LF newlines

use Set-StrictMode Latest

avoid reserved variable names (example: $PID forbidden)

parse-gate scripts before execution

never rely on interactive state

11. Integration Flow Summary

Privacy Sector → Rebound:

vault object sealed
↓
Privacy Sector exports packet
↓
Rebound receives packet
↓
Rebound verifies packet
↓
Rebound routes or hands off packet
↓
Rebound emits receipt


Rebound never mutates packet contents.

12. Definition of Done (Rebound side)

Rebound is integration-ready when:

Packet Constitution v1 selftest passes

NeverLost trust bundle verification works

rebound_send_packet_v1.ps1 verifies and emits receipt

rebound_receive_packet_v1.ps1 verifies and emits receipt

rebound_handoff_to_privacy_v1.ps1 verifies and emits receipt

receipts are deterministic and append-only

13. Authority Statement

Privacy Sector remains authoritative for vault objects.

Rebound remains authoritative for transport receipts.

Neither layer mutates the other's authoritative state.

Verification guarantees convergence.

14. Canonical Law Binding

This document is binding under:

Packet Constitution v1

NeverLost v1 identity law

NFL witness duplication law

Echo Transport transport law
