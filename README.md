# LifeOS

Android-first, local-first personal planning. Windows desktop and Chrome are
planned development/testing targets; Web production support is later scope.

## Current scope: design foundations

This repository is a Flutter package containing the approved light/dark theme,
design tokens, and focused tests. It does not yet contain an app entry point or
Android, Windows, or Web runners. `flutter run` is not available at this stage.
Platform scaffolding and screens require a separately approved phase.

Inter is the approved font family, but its assets and license have not yet been
bundled or registered. Theme tests do not validate rendered Inter typography.

## Run the design checks on Windows

Install a stable Flutter SDK (Flutter 3.24.0 / Dart 3.5.0 or newer) and add its
`bin` directory to PATH. These checks require Flutter, not a standalone Dart SDK.
Use the terminal in the cloned LifeOS directory containing `pubspec.yaml`:

```powershell
cd <path-to-your-LifeOS-checkout>
flutter --version
flutter pub get
flutter analyze
flutter test test/core/design
```

Only the Flutter SDK and its bundled `flutter_test` dependency are declared.
Dependency resolution may download their transitive packages. No API keys,
backend, account, or paid service is required.

If Flutter reports `No pubspec.yaml file found`, verify that you have pulled the
latest changes and that your terminal is in the repository root:

```powershell
git pull --ff-only
Get-Location
Test-Path .\pubspec.yaml
```

The final command should return `True`. Then run `flutter pub get` before the
analyzer and tests. Missing `package:flutter/...` or `package:flutter_test/...`
imports can result from missing package configuration; do not fix their cascading
errors by rewriting theme classes.

## Later local application testing

Once platform scaffolding is approved, Windows desktop development will require
Visual Studio with the **Desktop development with C++** workload and a compatible
Windows SDK. Visual Studio Code alone does not supply those build tools.
Chrome testing will require Chrome; Android testing will require the Android SDK
and an emulator or connected Android device. Check tooling with `flutter doctor -v`.

The later runnable app will document these commands:

```powershell
flutter run -d windows
flutter run -d chrome
flutter run -d <device_id>
```

See [approved decisions](docs/decisions.md) for scope and the free API/server
constraint. Hosted AI is optional; no paid fallback is permitted.
