param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$PacketDir,
  [Parameter(Mandatory=$true)][string]$Principal,
  [Parameter(Mandatory=$true)][string]$Namespace,
  [Parameter(Mandatory=$true)][string]$Destination,
  [switch]$AllowTransportStub
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path (Join-Path $Root "scripts") "_lib_rebound_packet_constitution_v1.ps1")

$trust = Join-Path $Root "proofs\trust\trust_bundle.json"
$allowed = Join-Path $Root "proofs\trust\allowed_signers"

Ensure-Dir (Join-Path $Root "packets")
Ensure-Dir (Join-Path $Root "packets\outbox")
Ensure-Dir (Join-Path $Root "packets\receipts")

function Invoke-TransportSend([string]$PacketPath,[string]$Dest,[string]$Pid){
  if (-not $AllowTransportStub) {
    throw "TRANSPORT_NOT_CONFIGURED: provide a real transport implementation or use -AllowTransportStub for a no-op send receipt."
  }
  # NO-OP transport stub: do not mutate packet; just return empty message id
  return ""
}

$v = Verify-Packet-OptionA -Root $Root -PacketDir $PacketDir -TrustBundlePath $trust -AllowedSignersPath $allowed -Namespace $Namespace -Principal $Principal -ReceiptSchema "rebound.send.receipt.v1"
$packetId = $v.packet_id

# Stage a copy into outbox/sent/<packetId> for deterministic bookkeeping
$sentRoot = Join-Path (Join-Path $Root "packets\outbox") "sent"
Ensure-Dir $sentRoot
$sentDir = Join-Path $sentRoot $packetId
if (Test-Path -LiteralPath $sentDir) { throw ("OUTBOX_ALREADY_HAS_SENT_PACKET: " + $sentDir) }

Copy-Item -LiteralPath $PacketDir -Destination $sentDir -Recurse -Force

$msgId = Invoke-TransportSend -PacketPath $sentDir -Dest $Destination -Pid $packetId

$receiptsPath = Join-Path $Root "packets\receipts\rebound.receipts.ndjson"
Append-Receipt $receiptsPath @{
  schema = "rebound.send.receipt.v1"
  packet_id = $packetId
  ok = $true
  sig = $v.sig
  manifest_sha256 = (Hex-Sha256File $v.manifest_path)
  sha256sums_sha256 = (Hex-Sha256File $v.sha256sums_path)
  destination = $Destination
  transport_message_id = $msgId
}

Write-Host ("OK: REBOUND_SEND_STAGED " + $packetId) -ForegroundColor Green
