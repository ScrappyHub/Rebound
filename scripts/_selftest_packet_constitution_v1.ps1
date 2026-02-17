param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$Principal,
  [Parameter(Mandatory=$true)][string]$Namespace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path (Join-Path $Root "scripts") "_lib_rebound_packet_constitution_v1.ps1")

$trust = Join-Path $Root "proofs\trust\trust_bundle.json"
$allowed = Join-Path $Root "proofs\trust\allowed_signers"

$vecRoot = Join-Path $Root "test_vectors\packet_constitution_v1"
$pktFail = Join-Path $vecRoot "minimal_packet_fail_sig"

if (-not (Test-Path -LiteralPath $pktFail)) { throw ("MISSING_TEST_VECTOR: " + $pktFail) }

Write-Host "SELFTEST: verifying minimal vector that MUST fail signature (deterministic)" -ForegroundColor Cyan

$ok = $false
try {
  Verify-Packet-OptionA -Root $Root -PacketDir $pktFail -TrustBundlePath $trust -AllowedSignersPath $allowed -Namespace $Namespace -Principal $Principal -ReceiptSchema "rebound.packet.verify_receipt.v1" | Out-Null
  $ok = $true
} catch {
  $ok = $false
}

if ($ok) { throw "SELFTEST_EXPECTED_FAILURE_BUT_GOT_SUCCESS" }

Write-Host "OK: SELFTEST_PACKET_CONSTITUTION_V1_PASS (expected failure observed)" -ForegroundColor Green
