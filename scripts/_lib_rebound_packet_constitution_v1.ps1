Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Utf8NoBom { New-Object System.Text.UTF8Encoding($false) }

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Read-AllTextUtf8([string]$Path) {
  return [System.IO.File]::ReadAllText($Path, (New-Utf8NoBom))
}

function Write-AllTextUtf8Lf([string]$Path, [string]$Text) {
  $dir = Split-Path -Parent $Path
  if ($dir) { Ensure-Dir $dir }
  $lf = ($Text -replace "`r`n", "`n") -replace "`r", "`n"
  if (-not $lf.EndsWith("`n")) { $lf += "`n" }
  [System.IO.File]::WriteAllText($Path, $lf, (New-Utf8NoBom))
  if (-not (Test-Path -LiteralPath $Path)) { throw ("WRITE_FAILED: " + $Path) }
}

function Hex-Sha256Bytes([byte[]]$Bytes) {
  if ($null -eq $Bytes) { throw "SHA256_NULL_BYTES" }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $h = $sha.ComputeHash($Bytes)
  } finally {
    $sha.Dispose()
  }
  ($h | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Hex-Sha256File([string]$Path) {
  $fh = Get-FileHash -Algorithm SHA256 -LiteralPath $Path
  $fh.Hash.ToLowerInvariant()
}

function CanonJson([object]$Obj) {
  # Canonical JSON: stable ordering via ConvertTo-Json is NOT guaranteed for hashtables with random order.
  # We enforce ordering by materializing ordered dictionaries recursively.
  function To-Ordered([object]$x) {
    if ($null -eq $x) { return $null }
    if ($x -is [string] -or $x -is [int] -or $x -is [long] -or $x -is [double] -or $x -is [decimal] -or $x -is [bool]) { return $x }
    if ($x -is [System.Collections.IDictionary]) {
      $keys = @(@($x.Keys) | Sort-Object)
      $o = New-Object System.Collections.Specialized.OrderedDictionary
      foreach ($k in $keys) { [void]$o.Add([string]$k, (To-Ordered $x[$k])) }
      return $o
    }
    if ($x -is [System.Collections.IEnumerable] -and -not ($x -is [string])) {
      $arr = New-Object System.Collections.Generic.List[object]
      foreach ($it in $x) { [void]$arr.Add((To-Ordered $it)) }
      return $arr.ToArray()
    }
    # fallback: treat as PSCustomObject -> dictionary
    $props = $x.PSObject.Properties.Name
    $keys2 = @(@($props) | Sort-Object)
    $o2 = New-Object System.Collections.Specialized.OrderedDictionary
    foreach ($k2 in $keys2) { [void]$o2.Add([string]$k2, (To-Ordered ($x.$k2))) }
    return $o2
  }

  $ordered = To-Ordered $Obj
  # Depth 99 to stay PS5.1-safe; schema objects here are shallow by design.
  $json = $ordered | ConvertTo-Json -Depth 99 -Compress
  # ConvertTo-Json emits CRLF sometimes depending on host; normalize to LF and ensure trailing LF.
  $jsonLf = ($json -replace "`r`n","`n") -replace "`r","`n"
  if (-not $jsonLf.EndsWith("`n")) { $jsonLf += "`n" }
  return $jsonLf
}

function Load-Manifest([string]$ManifestPath) {
  $txt = Read-AllTextUtf8 $ManifestPath
  try { return ($txt | ConvertFrom-Json -Depth 99) } catch { throw ("MANIFEST_JSON_PARSE_FAIL: " + $ManifestPath) }
}

function Manifest-WithoutId-Bytes([object]$ManifestObj) {
  # Option A: manifest MUST NOT contain packet_id. If present, we remove it for hashing input.
  $copy = $ManifestObj | ConvertTo-Json -Depth 99 -Compress | ConvertFrom-Json -Depth 99
  if ($null -ne $copy.packet_id) { $copy.PSObject.Properties.Remove("packet_id") | Out-Null }
  $canon = CanonJson $copy
  return (New-Utf8NoBom).GetBytes($canon)
}

function Compute-PacketId-FromManifest([string]$ManifestPath) {
  $m = Load-Manifest $ManifestPath
  $bytes = Manifest-WithoutId-Bytes $m
  return (Hex-Sha256Bytes $bytes)
}

function Read-PacketIdTxt([string]$PacketIdPath) {
  $t = Read-AllTextUtf8 $PacketIdPath
  $line = ($t -replace "`r`n","`n") -replace "`r","`n"
  $line = $line.Trim()
  if ($line -notmatch '^[a-f0-9]{64}$') { throw ("PACKET_ID_TXT_INVALID: " + $PacketIdPath) }
  return $line
}

function Parse-Sha256Sums([string]$SumsPath) {
  $lines = @(@((Read-AllTextUtf8 $SumsPath) -split "`n") | Where-Object { $_.Trim().Length -gt 0 })
  $map = @{}
  foreach ($ln in $lines) {
    # format: "<hash>  <relative_path>"
    $m = [regex]::Match($ln, '^(?<h>[A-Fa-f0-9]{64})\s\s(?<p>.+)$')
    if (-not $m.Success) { throw ("SHA256SUMS_PARSE_FAIL: " + $SumsPath) }
    $h = $m.Groups["h"].Value.ToLowerInvariant()
    $p = $m.Groups["p"].Value
    if ($map.ContainsKey($p)) { throw ("SHA256SUMS_DUP_PATH: " + $p) }
    $map[$p] = $h
  }
  return $map
}

function Append-Receipt([string]$ReceiptPath, [hashtable]$Obj) {
  $json = CanonJson $Obj
  # NDJSON: one canonical JSON object per line (already ends with LF)
  $dir = Split-Path -Parent $ReceiptPath
  if ($dir) { Ensure-Dir $dir }
  [System.IO.File]::AppendAllText($ReceiptPath, $json, (New-Utf8NoBom))
}

function Verify-Packet-OptionA(
  [string]$Root,
  [string]$PacketDir,
  [string]$TrustBundlePath,
  [string]$AllowedSignersPath,
  [string]$Namespace,
  [string]$Principal,
  [string]$ReceiptSchema
) {
  if (-not (Test-Path -LiteralPath $PacketDir)) { throw ("MISSING_PACKET_DIR: " + $PacketDir) }

  $manifestPath = Join-Path $PacketDir "manifest.json"
  $packetIdPath = Join-Path $PacketDir "packet_id.txt"
  $sumsPath     = Join-Path $PacketDir "sha256sums.txt"
  $sigPath      = Join-Path (Join-Path $PacketDir "signatures") "manifest.json.sig"

  if (-not (Test-Path -LiteralPath $manifestPath)) { throw ("MISSING_MANIFEST: " + $manifestPath) }
  if (-not (Test-Path -LiteralPath $packetIdPath)) { throw ("MISSING_PACKET_ID_TXT: " + $packetIdPath) }
  if (-not (Test-Path -LiteralPath $sumsPath)) { throw ("MISSING_SHA256SUMS: " + $sumsPath) }

  $computedId = Compute-PacketId-FromManifest $manifestPath
  $packetIdTxt = Read-PacketIdTxt $packetIdPath
  if ($computedId -ne $packetIdTxt) { throw ("PACKET_ID_MISMATCH: computed=" + $computedId + " txt=" + $packetIdTxt) }

  # sha256sums verify
  $map = Parse-Sha256Sums $sumsPath
  foreach ($rel in @(@($map.Keys) | Sort-Object)) {
    $abs = Join-Path $PacketDir $rel
    if (-not (Test-Path -LiteralPath $abs)) { throw ("SHA256SUMS_MISSING_FILE: " + $rel) }
    $h = Hex-Sha256File $abs
    if ($h -ne $map[$rel]) { throw ("SHA256SUMS_HASH_MISMATCH: " + $rel) }
  }

  # signature verify (deterministic)
  $sigMode = "missing"
  $sigOk = $false
  if (Test-Path -LiteralPath $sigPath) {
    if (-not (Test-Path -LiteralPath $AllowedSignersPath)) { throw ("MISSING_ALLOWED_SIGNERS: " + $AllowedSignersPath) }
    if (-not (Test-Path -LiteralPath $TrustBundlePath)) { throw ("MISSING_TRUST_BUNDLE: " + $TrustBundlePath) }

    $sigMode = "verified"
    # NOTE: ssh-keygen reads data from stdin. Use cmd redirection deterministically.
    $cmd = "ssh-keygen.exe -Y verify -f `"" + $AllowedSignersPath + "`" -I `"" + $Principal + "`" -n `"" + $Namespace + "`" -s `"" + $sigPath + "`" < `"" + $manifestPath + "`""
    $p = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", $cmd) -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) {
      $sigMode = "failed"
      $sigOk = $false
    } else {
      $sigOk = $true
    }
  }

  $receiptsPath = Join-Path $Root "packets\receipts\rebound.receipts.ndjson"
  $receipt = @{
    schema = $ReceiptSchema
    packet_id = $packetIdTxt
    ok = ($true -and $sigOk)
    sig = @{ mode = $sigMode; ok = $sigOk }
    manifest_sha256 = (Hex-Sha256File $manifestPath)
    sha256sums_sha256 = (Hex-Sha256File $sumsPath)
  }

  Append-Receipt $receiptsPath $receipt

  if (-not $receipt.ok) { throw "VERIFY_FAILED" }

  return @{
    packet_id = $packetIdTxt
    manifest_path = $manifestPath
    sha256sums_path = $sumsPath
    sig = $receipt.sig
  }
}
