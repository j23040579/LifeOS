# Validation record

Cloud checks on 26 October 2026 (Asia/Kuala_Lumpur), Linux x86_64, Flutter 3.47.8 /
Dart 3.13.7. These results apply to this development build, not every master-spec
capability or a production release.

| Executed check | Result |
|---|---|
| Dart formatting, lib/test/integration_test/tool | 51 files checked; no formatting changes required |
| `flutter analyze` | No issues |
| `flutter test --concurrency=2` | **73 passed**, no skipped/disabled tests |
| `node --test server/gemini-worker.test.mjs` | **6 passed** using synthetic provider responses |
| `dart run tool/bootstrap.dart`, repeated | Passed; existing runners preserved, SQLite web assets verified; documented Android INTERNET/automatic-backup settings applied |
| `flutter build web --no-web-resources-cdn` | Passed; browser engine/fonts/PDF/SQLite assets served locally |
| `flutter build apk --debug --target-platform android-arm64` | Passed, then passed incremental rebuild after final planning fixes |
| APK inspection | ARM64 PDFium and SQLite bundled; minSdk 26, targetSdk 36, INTERNET permission, allowBackup false |
| Loopback mock gateway | Authenticated health/chat 200 with demo/live:false labels; unauthenticated health rejected 401 |
| Actual private fixture parser probe | Hevy: 437 set rows / 27 sessions / 0 rejected; nutrition: 6 food items / 2 partial dates / 0 rejected; private files excluded from Git |
| Internal Chromium interaction | Task creation/reload, selected-file Hevy import, repeat-import prevention, training summary and offline chat passed, no JS page errors |
| Internal Chromium planning/backup | Cancel kept records unchanged; approval saved blocks; JSON export/clear/restore recovered identical record IDs; no JS page errors |
| Internal Chromium document flow | Selected PDF/EPUB files imported, page/section notes present, JSON downloaded with no credential fields, separate fictional demo opened at desktop/mobile widths; no JS page errors |
| Reusable cloud installation | Executed twice successfully against retained toolchains; activation and setup instructions saved to draft; fresh-machine publication/restoration unverified |

Unit tests cover hard overlaps, deadlines/dependencies, parent task effort and
inherited deadlines, paused/completed states, overload rollback, fixed/pinned
preservation, cross-midnight events, free-time reserve and future DST transitions.
They also cover timezone ambiguity, source parser semantics, money precision,
imports, transaction revisions, stepwise undo, migration, erasure, restore rejection,
source staleness, actual PDF/EPUB extraction, context privacy and malformed AI actions.
Widget tests exercise task persistence, all tabs at 360px and 200% text in both
themes, credential restore/failure/forget, and AI review before one-time approval.

The first Android build exposed a missing JDK compiler in the cloud host; a full
JDK was installed under the writable toolchain directory. Native PDF hooks required
Clang; the installed NDK's host compiler satisfies that requirement. Android SDK
35/36, CMake 3.22.1 and NDK 28.2.13676358 are retained. The first dependency-heavy
APK build took about nine minutes; the incremental build took about 20 seconds.
No verification checks, assertions or TLS validation were disabled to get a pass.

Nonfatal build output includes a Cupertino icon-font warning from the PDF package's
widget dependency (this app uses PDF text extraction, not its viewer widgets), and
an Android SDK XML parser version warning on initial setup. Analysis and builds
complete successfully. Linux tool setup cannot find Visual Studio; that capability
must be checked on Windows.

## Unexecuted or limited checks

- Windows desktop compilation, actual native secure-token storage, Windows file
  chooser and screen-reader/manual keyboard acceptance: require your Windows laptop.
- Android device/emulator interaction and native integration tests: no attached
  device/emulator. Platform-tools 37 device enumeration also attempts to create
  `/home/agent/.android` on this cloud host's read-only home. That is a cloud
  restriction, not an application compile failure; HOME was not redirected.
- Native integration journeys (`integration_test/workspace_test.dart` and the
  earlier sample test) are supplied and analyzed, but not claimed as executed.
- Only the ARM64 debug APK was built here; emulator x86_64 and release signing,
  production identity, store deployment and release-size optimization remain.
- Actual Gemini generation, current free-project/model eligibility, remote HTTPS
  gateway deployment, and all third-party account sync: not configured or verified.
  Protocol mocks cannot establish provider intelligence, availability or pricing.
- Browser interaction used a current Chromium on an internal local origin. It does
  not establish native Android/Windows behaviour, all browser versions, incognito
  durability, or a future production web deployment.
- Formal screen-reader audit, malicious-document fuzzing and large-data endurance
  testing remain. PDF/EPUB parsers enforce local file/decompression/text limits;
  this does not make every possible document safe or supported.

## Laptop commands

From the checkout root, with current Flutter/Visual Studio tooling installed:

```powershell
git pull --ff-only
flutter pub get
dart run tool/bootstrap.dart
flutter analyze
flutter test
flutter run -d windows
flutter run -d chrome --web-port=7357
flutter devices
flutter run -d <device_id>
flutter test integration_test/workspace_test.dart -d windows
flutter test integration_test/workspace_test.dart -d <device_id>
```

Create/reload a task; keep a fixed block while approving a plan; import each
synthetic fixture twice; try the source recall and offline chat; add measurements
and expenses; export/restore a backup; change appearance and restart; test enlarged
text and narrow windows. Use a separate demo database for destructive data tests.
