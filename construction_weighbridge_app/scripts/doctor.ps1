Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Test-Command($Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) {
    Write-Host "[ok] $Name -> $($command.Source)"
    return $true
  }
  Write-Host "[missing] $Name"
  return $false
}

Write-Host "Quarry Gate build environment"
Write-Host "-----------------------------"
$hasFlutter = Test-Command "flutter"
$hasDart = Test-Command "dart"
$hasAdb = Test-Command "adb"
$hasJava = Test-Command "java"

if ($hasJava) {
  java -version
}

if ($hasFlutter) {
  flutter doctor -v
}

if (-not $hasFlutter -or -not $hasDart -or -not $hasAdb) {
  Write-Host ""
  Write-Host "Install Flutter SDK, Android SDK platform tools, and JDK 17 before building the APK."
  Write-Host "Then run: .\\scripts\\build_release_apk.bat"
}
