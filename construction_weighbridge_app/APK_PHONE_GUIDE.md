# APK And Phone Install Guide

This project is a Flutter Android app. The APK cannot be built on a machine until Flutter, Android SDK Platform Tools, and JDK 17 are installed.

## 1. Install The Build Tools

Install these on Windows:

- Flutter SDK: https://docs.flutter.dev/get-started/install/windows/mobile
- Android Studio, including Android SDK and Platform Tools.
- JDK 17. Android Studio normally includes a compatible JDK.

After installing, open a new terminal and run:

```bat
flutter doctor -v
```

Fix anything Flutter marks as missing for Android.

## 2. Build The APK

From this folder:

```bat
cd C:\Users\ADMIN\Documents\image\construction_weighbridge_app
scripts\doctor.bat
scripts\build_release_apk.bat
```

The APK will be created here:

```text
C:\Users\ADMIN\Documents\image\construction_weighbridge_app\build\app\outputs\flutter-apk\app-release.apk
```

## Build With GitHub Actions

If you do not want to install Flutter locally, push this repo to GitHub and open the Actions tab.

1. Select `Build Flutter APK`.
2. Click `Run workflow`, or push changes under `construction_weighbridge_app`.
3. Open the completed workflow run.
4. Download the `quarry-gate-release-apk` artifact.
5. Extract the zip and install `app-release.apk` on your phone.

## 3. Install On Your Phone With USB

On the phone:

1. Enable Developer options.
2. Enable USB debugging.
3. Connect the phone with USB.
4. Allow the debugging prompt on the phone.

Then run:

```bat
cd C:\Users\ADMIN\Documents\image\construction_weighbridge_app
scripts\install_to_phone.bat
```

This builds the APK and runs `adb install -r` automatically.

## 4. Install By Copying The APK

After building, copy this file to the phone:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Open it from the phone file manager. Android may ask you to allow installing unknown apps for that file manager. Allow it, then install.

## 5. Google Sheets Sync Package Name

For Google OAuth Android credentials, use this package name:

```text
com.mbm.quarrygate
```

You also need the SHA-1 fingerprint from the same machine/key used to build the APK.
