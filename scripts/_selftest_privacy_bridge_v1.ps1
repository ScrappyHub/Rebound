param(
  [Parameter(Mandatory=$true)][string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Must-Exist([string]$p) { if (-not (Test-Path -LiteralPath $p)) { throw ("MISSING_REQUIRED_PATH: " + $p) } }

Must-Exist (Join-Path $Root "docs\PRIVACY_SECTOR_BRIDGE_V1.md")
Must-Exist (Join-Path $Root "docs\PACKET_CONSTITUTION_V1.md")

Must-Exist (Join-Path $Root "schemas\rebound.transmit.intent.v1.json")
Must-Exist (Join-Path $Root "schemas\vault.ref.v1.json")
Must-Exist (Join-Path $Root "schemas\rebound.send.receipt.v1.json")
Must-Exist (Join-Path $Root "schemas\rebound.receive.receipt.v1.json")
Must-Exist (Join-Path $Root "schemas\rebound.privacy.ingest.receipt.v1.json")

Must-Exist (Join-Path $Root "scripts\rebound_send_packet_v1.ps1")
Must-Exist (Join-Path $Root "scripts\rebound_receive_packet_v1.ps1")
Must-Exist (Join-Path $Root "scripts\rebound_handoff_to_privacy_v1.ps1")
Must-Exist (Join-Path $Root "scripts\_lib_rebound_packet_constitution_v1.ps1")

Write-Host "OK: SELFTEST_PRIVACY_BRIDGE_V1_SMOKE_PASS" -ForegroundColor Green
