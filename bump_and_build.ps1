# bump_and_build.ps1
# Usage:
#   .\bump_and_build.ps1           -> bumps build number only (1.0.0+3 -> 1.0.0+4)
#   .\bump_and_build.ps1 -patch    -> bumps patch version  (1.0.0+3 -> 1.0.1+4)
#   .\bump_and_build.ps1 -minor    -> bumps minor version  (1.0.0+3 -> 1.1.0+4)
#   .\bump_and_build.ps1 -major    -> bumps major version  (1.0.0+3 -> 2.0.0+4)
#   .\bump_and_build.ps1 -nobuild  -> bumps version only, skips flutter build

param(
    [switch]$major,
    [switch]$minor,
    [switch]$patch,
    [switch]$nobuild
)

$pubspec = "pubspec.yaml"
$content = Get-Content $pubspec -Raw

# Extract current version string e.g. "1.0.0+3"
if ($content -match 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    $maj  = [int]$Matches[1]
    $min  = [int]$Matches[2]
    $pat  = [int]$Matches[3]
    $build = [int]$Matches[4]
} else {
    Write-Error "Could not parse version from pubspec.yaml"
    exit 1
}

$oldVersion = "$maj.$min.$pat+$build"

# Bump the appropriate part
if ($major) {
    $maj++; $min = 0; $pat = 0
} elseif ($minor) {
    $min++; $pat = 0
} elseif ($patch) {
    $pat++
}
# Always bump build number
$build++

$newVersion = "$maj.$min.$pat+$build"

# Write back to pubspec.yaml
$content = $content -replace "version:\s*$([regex]::Escape($oldVersion))", "version: $newVersion"
[System.IO.File]::WriteAllText((Resolve-Path $pubspec).Path, $content)

Write-Host "Version bumped: $oldVersion -> $newVersion" -ForegroundColor Green

if (-not $nobuild) {
    Write-Host "Building release APK..." -ForegroundColor Cyan
    flutter build apk --release
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Build successful: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
        Write-Host "Version: $newVersion" -ForegroundColor Green
    } else {
        Write-Host "Build failed." -ForegroundColor Red
    }
}
