param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$PacketDir,
  [Parameter(Mandatory=$true)][string]$Principal,
  [Parameter(Mandatory=$true)][string]$Namespace,
  [Parameter(Mandatory=$true)][string]$PrivacyImportScript,
  [switch]$AllowPrivacyStub
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path (Join-Path $Root "scripts") "_lib_rebound_packet_constitution_v1.ps1")

$trust = Join-Path $Root "proofs\trust\trust_bundle.json"
$allowed = Join-Path $Root "proofs\trust\allowed_signers"

Ensure-Dir (Join-Path $Root "packets")
Ensure-Dir (Join-Path $Root "packets\receipts")

function Invoke-PrivacyImport([string]$Script,[string]$Dir,[string]$Pid){
  if (-not (Test-Path -LiteralPath $Script)) {
    if ($AllowPrivacyStub) { return "privacy.stub.ok" }
    throw ("PRIVACY_IMPORT_NOT_FOUND: " + $Script)
  }
  # Canonical: call external script; no mutation of packet here.
  $p = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",$Script,"-PacketDir",$Dir) -Wait -PassThru -NoNewWindow
  if ($p.ExitCode -ne 0) { throw ("PRIVACY_IMPORT_FAILED: exit=" + $p.ExitCode) }
  return "privacy.import.ok"
}

$v = Verify-Packet-OptionA -Root $Root -PacketDir $PacketDir -TrustBundlePath $trust -AllowedSignersPath $allowed -Namespace $Namespace -Principal $Principal -ReceiptSchema "rebound.privacy.ingest.receipt.v1"
$packetId = $v.packet_id

$vaultRefPath = Join-Path (Join-Path $PacketDir "payload") "vault.ref.json"
$vaultObject = ""
if (Test-Path -LiteralPath $vaultRefPath) {
  $vr = Read-AllTextUtf8 $vaultRefPath | ConvertFrom-Json -Depth 99
  if ($null -ne $vr.object) { $vaultObject = [string]$vr.object }
}

$result = Invoke-PrivacyImport -Script $PrivacyImportScript -Dir $PacketDir -Pid $packetId

$receiptsPath = Join-Path $Root "packets\receipts\rebound.receipts.ndjson"
Append-Receipt $receiptsPath @{
  schema = "rebound.privacy.ingest.receipt.v1"
  packet_id = $packetId
  ok = $true
  sig = $v.sig
  manifest_sha256 = (Hex-Sha256File $v.manifest_path)
  sha256sums_sha256 = (Hex-Sha256File $v.sha256sums_path)
  vault_object = $vaultObject
  privacy_result = $result
}

Write-Host ("OK: REBOUND_PRIVACY_HANDOFF_DONE " + $packetId) -ForegroundColor Green
