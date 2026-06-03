Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter is not installed or not on PATH. Install Flutter first."
}

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  throw "ADB is not installed or not on PATH. Install Android SDK Platform Tools first."
}

Push-Location (Join-Path $PSScriptRoot "..")
try {
  adb devices
  flutter pub get
  flutter test
  flutter build apk --release
  $apk = Resolve-Path "build/app/outputs/flutter-apk/app-release.apk"
  adb install -r "$apk"
  Write-Host "Installed: $apk"
}
finally {
  Pop-Location
}
