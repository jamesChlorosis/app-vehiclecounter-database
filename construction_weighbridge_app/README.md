# Construction Weighbridge App

Offline-first Flutter APK app for a single weighbridge/gate operator logging quarry material vehicle sales.

## What Is Included

- Camera OCR screen using Google ML Kit text recognition.
- Manual vehicle entry fallback with uppercase plate formatting.
- SQLite storage with `entries`, `vehicles`, `daily_summary`, `accounts`, `settings`, and `item_types`.
- Repeat vehicle autofill for party, item, and last quantity.
- Entry form, today's log, summary/accounts, and settings screens.
- On-demand Google Sheets sync for unsynced entries.
- Daily Excel and PDF exports with share/open actions.
- Dark Material 3 theme, large tap targets, amber industrial palette.

## Build

Flutter is not installed in this Codex environment, so the APK could not be compiled here. On a machine with Flutter and Android SDK:

```bash
cd construction_weighbridge_app
flutter pub get
flutter test
flutter build apk --release
```

The APK will be generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Google Sheets Setup

1. Create a Google Cloud project.
2. Enable Google Sheets API v4.
3. Configure OAuth consent screen.
4. Create Android OAuth credentials and add your SHA-1 fingerprint.
5. Share the target spreadsheet with the Google account used in the app.
6. Paste the spreadsheet ID or full Sheets URL in Settings.

The app stores dates internally as `DD/MM/YYYY`. Google Sheets tab names cannot safely use `/`, so sync creates daily tabs as `DD-MM-YYYY`, appends unsynced rows only, marks rows synced after success, and upserts that date in a `Summary` tab.

OAuth is the recommended Android auth path. A service account can work only if the private key is bundled or retrieved securely, which is not recommended for an operator APK because anyone with the APK could extract it. If you need service-account sync, put that logic behind a small backend and let the APK call your backend.

## Android Notes

Run this after Flutter is available if Android host files need regeneration:

```bash
flutter create --platforms=android .
```

Keep the `lib/` and `pubspec.yaml` files from this scaffold.

## Convenience Build Script

```powershell
.\scripts\build_release_apk.ps1
```

The script runs `flutter pub get`, `flutter test`, and `flutter build apk --release`.
If PowerShell script execution is blocked, run `.\scripts\build_release_apk.bat`.

Before building, you can run:

```powershell
.\scripts\doctor.ps1
```

It checks for Flutter, Dart, ADB, and Java, then runs `flutter doctor -v` when Flutter is available.
If PowerShell script execution is blocked, run `.\scripts\doctor.bat`.
