Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter is not installed or not on PATH. Install Flutter, Android SDK, then run this script again."
}

Push-Location (Join-Path $PSScriptRoot "..")
try {
  flutter pub get
  flutter test
  flutter build apk --release
  Write-Host "APK: build/app/outputs/flutter-apk/app-release.apk"
}
finally {
  Pop-Location
}
