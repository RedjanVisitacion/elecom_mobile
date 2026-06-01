param(
  [string]$VersionName = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
$content = Get-Content -LiteralPath $pubspecPath -Raw

$pattern = "(?m)^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)\s*$"
$match = [regex]::Match($content, $pattern)
if (-not $match.Success) {
  throw "Could not find a version line like 'version: 1.0.0+1' in pubspec.yaml."
}

if ([string]::IsNullOrWhiteSpace($VersionName)) {
  $major = $match.Groups[1].Value
  $minor = $match.Groups[2].Value
  $patch = $match.Groups[3].Value
  $VersionName = "$major.$minor.$patch"
} elseif ($VersionName -notmatch "^[0-9]+\.[0-9]+\.[0-9]+$") {
  throw "VersionName must look like 1.0.1"
}

$nextBuild = [int]$match.Groups[4].Value + 1
$newLine = "version: $VersionName+$nextBuild"
$updated = [regex]::Replace($content, $pattern, $newLine, 1)

Set-Content -LiteralPath $pubspecPath -Value $updated -NoNewline
Write-Host $newLine
