# LifeOS

Android-first, local-first personal planning. Windows desktop and Chrome support
local testing; Web production release is later scope.

## Current phase: Home / Today sample

One responsive screen uses the approved light/dark themes and bundled Inter font.
It shows three fictional priorities and their daily schedule. Mark a priority
complete, undo it, reset the sample, change appearance, or preview loading, empty,
and error states. Fixed commitments are labelled separately from flexible blocks.

**This is an offline UI prototype.** Completion changes exist only in memory and
reset on restart. The date is a labelled fictional sample day, not today's date.
There is no real calendar, persistence, scheduling engine, AI, backend, or import
implementation yet. No personal exports are bundled. No credentials, paid APIs,
or billing accounts are required.

## Windows laptop setup

1. Install a stable Flutter SDK (minimum Flutter 3.24.0 / Dart 3.5.0) and add its
   `bin` directory to PATH. Use the Flutter-bundled Dart, not a separate Dart SDK.
2. For Windows desktop, install **Visual Studio** with **Desktop development with
   C++** and a compatible Windows SDK. Visual Studio Code alone is insufficient.
3. For browser testing, install Chrome.
4. For Android, install Android Studio, the Android SDK, and an emulator, or enable
   USB debugging on an Android phone. Run `flutter doctor --android-licenses` if
   required and review the licenses. Android minimum API is 26 for this prototype.
5. Open a terminal in the LifeOS repository root containing `pubspec.yaml`:

```powershell
git pull --ff-only
flutter --version
flutter doctor -v
flutter pub get
dart run tool/bootstrap.dart
flutter devices
```

The bootstrap command generates **only missing** `windows`, `web`, and `android`
runner directories using your installed Flutter SDK in a temporary project. It
copies those directories, sets the Android minimum SDK to at least 26, and leaves
source, tests, dependencies, and existing runners untouched. Running it again
preserves existing runners. Development application ID: `com.example.lifeos`;
production identity and signing remain future decisions. Do not run
`flutter create .` over this checkout.

Cloud validation uses Flutter 3.47.8 / Dart 3.13.7. The bootstrap uses your
installed compatible stable SDK. Generated runners remain local setup outputs;
existing laptop runners are preserved, so pulling source fixes will not replace
them. Production platform configuration/signing remains later scope.

## Run locally

After bootstrap:

```powershell
flutter run -d windows
flutter run -d chrome
flutter run -d <device_id>
```

Use an actual ID from `flutter devices` for Android. The Android experience must
be checked on an emulator or physical device; Windows and Chrome are not substitutes
for Android-specific testing.

An optional non-secret example configuration selects the initial sample state:

```powershell
flutter run -d windows --dart-define-from-file=config/example.json
```

`DAY_PREVIEW` accepts `ready`, `loading`, `empty`, or `error`. Unknown values fall
back to `ready`. These are UI state previews, not real network failures. The same
states are available through **Preview states**. No API keys are read.

## Automated checks

```powershell
dart format lib test integration_test tool
flutter analyze
flutter test
flutter test integration_test/today_test.dart -d windows
flutter test integration_test/today_test.dart -d <device_id>
flutter build windows
flutter build web
flutter build apk --debug
```

Unit/theme tests cover design contrast and mappings. Widget tests cover completion,
undo/reset, alternate states, theme switching, and narrow layouts at 200% text.
The integration test covers the offline completion/reset journey on a supported
device. Browser integration tests need a separate WebDriver setup; the Chrome
manual checks below do not imply automated browser integration coverage.

## Manual acceptance checks

- In Windows and Chrome, resize from a narrow window to a wide window. Priority
  and schedule columns should stack when narrow or when text is enlarged.
- Switch between light, dark, and system appearance. Restarting resets the choice.
- Mark the assignment priority complete: the summary and matching schedule block
  should update. Undo and Reset sample should restore the sample state.
- Use Preview states to inspect loading, empty, and error feedback. Retry/load
  should restore the sample; these previews do not call any services.
- Navigate by keyboard, inspect visible focus, and check 200% text/zoom for clipping.
- Verify the same screen on Android when tooling is available.

This phase does not implement file import, forms for real records, AI chat,
notifications, Health Connect, persistence, or scheduling changes. Those require
separately approved phases and platform-specific acceptance checks.

## Validation status

Validated in the Linux cloud environment with Flutter 3.47.8 / Dart 3.13.7:

- `flutter analyze`: no issues.
- `flutter test --concurrency=2`: all 19 tests passed, including narrow layouts
  at 200% text and verified light/dark appearance changes.
- `dart run tool/bootstrap.dart`: generated Android, Windows, and Web runners;
  repeating the command preserved every existing runner file.
- `flutter build web --no-web-resources-cdn`: release Web build passed.
- Chromium smoke check: sample content, completion/reset, dark-theme pixels, and
  narrow viewport rendering passed with no JavaScript page errors.

Windows desktop compilation/execution and the device integration test remain
unrun here because this is a Linux host. Android compilation/device tests also
remain unrun because Android tooling is unavailable. These checks still need to
pass on the relevant platforms before full platform readiness can be claimed.

If `pubspec.yaml` cannot be found, run `Get-Location` and
`Test-Path .\pubspec.yaml`, then change to the actual checkout root. Run
`flutter pub get` before analysis/tests to resolve SDK imports.

See [approved decisions](docs/decisions.md). Only Flutter's SDK dependencies are
used; hosted AI remains optional and paid fallbacks are prohibited.
