param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$PacketDir,
  [Parameter(Mandatory=$true)][string]$Principal,
  [Parameter(Mandatory=$true)][string]$Namespace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path (Join-Path $Root "scripts") "_lib_rebound_packet_constitution_v1.ps1")

$trust = Join-Path $Root "proofs\trust\trust_bundle.json"
$allowed = Join-Path $Root "proofs\trust\allowed_signers"

Ensure-Dir (Join-Path $Root "packets")
Ensure-Dir (Join-Path $Root "packets\inbox")
Ensure-Dir (Join-Path $Root "packets\quarantine")
Ensure-Dir (Join-Path $Root "packets\receipts")

$packetId = $null
$destPath = $null

try {
  $v = Verify-Packet-OptionA -Root $Root -PacketDir $PacketDir -TrustBundlePath $trust -AllowedSignersPath $allowed -Namespace $Namespace -Principal $Principal -ReceiptSchema "rebound.receive.receipt.v1"
  $packetId = $v.packet_id
  $destPath = Join-Path (Join-Path $Root "packets\inbox") $packetId

  if (Test-Path -LiteralPath $destPath) { throw ("INBOX_ALREADY_HAS_PACKET: " + $destPath) }
  Move-Item -LiteralPath $PacketDir -Destination $destPath -Force

  # append additional receipt detail (non-authoritative metadata)
  $receiptsPath = Join-Path $Root "packets\receipts\rebound.receipts.ndjson"
  Append-Receipt $receiptsPath @{
    schema = "rebound.receive.receipt.v1"
    packet_id = $packetId
    ok = $true
    sig = $v.sig
    manifest_sha256 = (Hex-Sha256File $v.manifest_path)
    sha256sums_sha256 = (Hex-Sha256File $v.sha256sums_path)
    moved_to = $destPath
  }

  Write-Host ("OK: REBOUND_RECEIVE_DONE " + $packetId) -ForegroundColor Green
}
catch {
  $err = $_.Exception.Message
  $q = Join-Path (Join-Path $Root "packets\quarantine") ("_failed_" + ([guid]::NewGuid().ToString("n")))
  try {
    if (Test-Path -LiteralPath $PacketDir) {
      Move-Item -LiteralPath $PacketDir -Destination $q -Force
    }
  } catch { }

  $receiptsPath2 = Join-Path $Root "packets\receipts\rebound.receipts.ndjson"
  Append-Receipt $receiptsPath2 @{
    schema = "rebound.receive.receipt.v1"
    packet_id = ""
    ok = $false
    sig = @{ mode="unknown"; ok=$false }
    manifest_sha256 = ""
    sha256sums_sha256 = ""
    moved_to = $q
  }

  throw ("REBOUND_RECEIVE_FAILED: " + $err)
}
