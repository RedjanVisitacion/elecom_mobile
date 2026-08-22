param(
  [string]$VersionName = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$bumpScript = Join-Path $PSScriptRoot "bump_build.ps1"
$apkDir = Join-Path $repoRoot "build\app\outputs\flutter-apk"
$sourceApk = Join-Path $apkDir "app-release.apk"
$targetApk = Join-Path $apkDir "elecom.apk"

Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($VersionName)) {
    & $bumpScript
  } else {
    & $bumpScript -VersionName $VersionName
  }

  flutter build apk --release

  if (-not (Test-Path -LiteralPath $sourceApk)) {
    throw "Build completed, but app-release.apk was not found at $sourceApk"
  }

  Copy-Item -LiteralPath $sourceApk -Destination $targetApk -Force
  Write-Host "Release APK ready: $targetApk"
} finally {
  Pop-Location
}
