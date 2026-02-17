# Rebound

Rebound is the canonical **transport broker** for **Packet Constitution v1** directory-bundle packets.

## What Rebound does
- Verifies packets **without mutation** (PacketId rule + sha256sums + signatures via trust bundle).
- Receives packets into deterministic runtime dirs (inbox/quarantine).
- Provides thin wrappers for **send** and **handoff-to-privacy** workflows (transport + integration are explicit hooks).
- Emits append-only deterministic receipts.

## What Rebound does NOT do
- Does not decrypt or reinterpret vault objects.
- Does not re-encrypt or mutate authoritative payloads.
- Does not "self-heal" packets during verify.

## Canonical laws
- Packet Constitution v1 (Option A) — manifest.json has **no packet_id**
- NeverLost v1 — trust bundle → allowed_signers; deterministic receipts
- NFL/WatchTower compatibility — evidence is hash/sig/receipt based

## Docs
- docs/PACKET_CONSTITUTION_V1.md
- docs/PRIVACY_SECTOR_BRIDGE_V1.md

## Runtime dirs
- packets/outbox
- packets/inbox
- packets/quarantine
- packets/receipts
