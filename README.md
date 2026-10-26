# LifeOS

Android-first, local-first planning, learning, and personal progress in one Flutter
codebase. Windows desktop and Chrome support laptop development. No account,
deployed backend, real credentials, or paid service is required for basic use.

## What you can test

The [Home/calendar guide](docs/calendar-home-redesign.md) explains timeline event
creation, linked subtasks, today's to-dos, current-state scoring, Gemini fallback,
and task-linked focus/reflections. The [progress review guide](docs/progress-reviews.md)
covers food-day completeness, personal targets, and exercise-name mappings.

- **Today / Plan:** goals, projects, nested tasks, effort-weighted progress,
  deadlines, prerequisites, fixed/pinned blocks, habits and explicit availability.
  Tap an event to expand its checklist inside the calendar, create nested work,
  or choose from nine saved event colors. Buttons remain fully rounded in all
  states. The scheduler compares deadline-first, importance-first, and spread-work
  alternatives, preserves commitments, reserves free time, reports overload, and
  shows a proposal before saving. Undo and revision checks protect
  local changes. Delaying work never changes a deadline automatically.
- **Learn:** courses, local notes, PDF/EPUB text extraction with page/section
  provenance, prerequisite concept links, self-assessed recall and review dates,
  source-to-task approval, local search, and focus sessions. Optional Gemini tutor
  modes use only the question and context you select. Self-assessment is distinct
  from verified correctness; code is never described as tested by the tutor.
- **Progress:** Hevy CSV, MyFitnessPal TXT, manual food and body/activity/sleep
  records, macro summaries, measurement charts with accessible values, recorded
  exercise progression, integer-sen budgets, transactions, and outing estimates.
  Personal nutrition targets, week/month food summaries, explicit day-completeness
  review, and editable provider-specific exercise mappings are included. Missing
  nutrients/RPE stay missing; food edits invalidate a previous complete-day review.
- **Coach:** offline commands and scheduling, an explicitly labelled offline chat
  demo, and optional online Gemini through a personal gateway. AI can propose a
  task change; only a separate user approval saves it. No external write tools.
- **Settings:** local file import with preview/deduplication, JSON backup/restore,
  audit/undo, explicit data erasure, timezone/budget, appearance, and a separate
  fictional demo database. Calendar ICS imports preserve external ownership.

This is an expanded development build, not a claim that every master-spec gate
is production complete. See [scope and remaining work](docs/status.md) and
[validation](docs/validation.md). External account integrations are unavailable
until separately configured and verified; they are never simulated as connected.

## Windows setup

1. Install **Flutter stable 3.47 or newer with Dart 3.13 or newer**. Cloud checks
   use Flutter **3.47.8 / Dart 3.13.7**. Add Flutter `bin` to PATH; use its bundled
   Dart. PDF support now needs this newer SDK. Check `flutter --version`.
2. Install **Visual Studio** with **Desktop development with C++** and a Windows
   SDK. Visual Studio Code alone is insufficient. Install **C++ ATL for x64/x86**
   matching the installed MSVC toolset as well; the secure-storage plugin needs it. Enable Windows Developer Mode
   if Flutter requests symlink support for plugins.
3. Install Chrome for browser testing. Install Android Studio, an Android SDK
   and emulator (or use USB debugging on your phone) for Android testing.
   Review Android licences using `flutter doctor --android-licenses`.
4. Open PowerShell in the checkout root that contains `pubspec.yaml`:

```powershell
git pull --ff-only
flutter channel stable
flutter upgrade
flutter --version
flutter doctor -v
flutter pub get
dart run tool/bootstrap.dart
flutter devices
```

Bootstrap generates only missing Android, Windows and Web runners in a temporary
project; it preserves app source and existing runner settings. It adds bundled
SQLite browser assets, Android INTERNET permission for optional HTTPS AI, and
`android:allowBackup="false"` to keep app records/tokens out of Android automatic
cloud backups. Use explicit JSON backups for records. Minimum Android API is 26;
existing customized runners should also use API 26 or newer. Review these additive
manifest changes if you manage custom backup policies. Re-running bootstrap is safe.

Generated runners and `pubspec.lock` are local in this development checkout, so
pulling these source changes does not overwrite runners already on your laptop.
Direct dependency versions are pinned. Preserve your resolved lock for your local
build; release work must establish a tracked lock and production identity/signing.
Do not run `flutter create .` over the app. The generated ID is `com.example.lifeos`.
If your Android runner came from an older SDK, run `flutter analyze --suggestions`
and review Flutter's Gradle/Java migration advice. The cloud-generated runner uses
Gradle 9.3.1, Android Gradle Plugin 9.1.0, Kotlin 2.4.0 and JDK 21. Bootstrap preserves
an existing runner's versions; upgrading Flutter does not rewrite custom Gradle files.

If Flutter reports no pubspec, check:

```powershell
Get-Location
Test-Path .\pubspec.yaml
```

Change to the actual project root before running Flutter commands.

## Run and interact

```powershell
flutter run -d windows
flutter run -d chrome
flutter run -d <device_id>
```

Replace `<device_id>` with an Android ID from `flutter devices`. Android-specific
behaviour still needs an emulator or device; desktop tests cannot replace it.

The default workspace starts empty and saves locally. For fictional sample data:

```powershell
flutter run -d windows --dart-define-from-file=config/example.json
flutter run -d chrome --dart-define-from-file=config/example.json
```

The example contains only `DEMO_WORKSPACE: true`, no credentials. It uses a
separate persistent `lifeos_demo` database. You can also open it from Settings.
`--dart-define=DEMO_ONLY=true` opens the earlier resettable design sample; its
`DAY_PREVIEW` accepts `ready`, `loading`, `empty`, or `error`.

## Local files and data

Use Settings → Import a local file or the import buttons in Learn / Progress.
Preview new rows, duplicates, changed rows and diagnostics before saving. Repeated
checksums do not reimport; changed existing rows are skipped, never overwritten.
Set the source timezone before importing Hevy timestamps. Files stay local.

Supported formats are documented in [imports](docs/imports.md). Synthetic examples
are under `test/fixtures`; private uploaded exports are not committed. PDFs need
extractable text; scanned pages require OCR or a text alternative. EPUB support
is text extraction, not a DRM bypass or a full ebook reader.

SQLite stores records on native platforms and in current Chrome browser storage.
Browser data belongs to the exact origin, so use a fixed local web port if you
want it to persist between development runs:

```powershell
flutter run -d chrome --web-port=7357
```

Private browsing, clearing browser data, or changing origins can remove/hide that
workspace. Reliable browser storage failure is shown explicitly. Export backups.
The workspace database and exported JSON are **not app-encrypted**. The audit
retains at most 50 snapshots; ordinary clear/delete remains undoable while retained.
Settings → Erase records and history removes the current workspace and its audit;
it does not remove exports, the separate demo, or gateway credentials. Use Coach →
Disconnect & forget token to remove saved AI access. Exported backups omit tokens,
API keys, audit history and session-only chat. This is not a forensic erase guarantee.

## Optional Gemini online

See [gateway setup](server/README.md). The app never bundles a Gemini API key.
Windows/Android can optionally remember a gateway access token using OS-backed
secure storage. Chrome uses session-only tokens. Storage failures preserve offline
access; disconnect removes the saved token. No conversation generates on startup.

The free-only rule means: no mandatory billing, paid fallback, automatic model
switch or retries. You must verify that your chosen Gemini model/project is
currently eligible for free use **without billing** and review its data-use terms.
Quotas/model availability change. A configuration flag cannot verify your Google
billing settings; the gateway refuses generation until you explicitly attest to
free/no-billing configuration. No live Gemini request has been verified yet.
Your supplied pricing text identifies `gemini-3.8-flash` as the intended model.
Its availability/free eligibility still needs verification against your project.
Model discovery instructions are in the gateway guide.

For interface testing with zero credentials, use **Coach → Try chat demo (offline)**.
Every result says it is a demo and not live AI. The optional loopback mock server
also supports local Windows/Chrome testing; Android release networking uses HTTPS.

## Checks

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test
node --test server/gemini-worker.test.mjs
flutter test integration_test/workspace_test.dart -d windows
flutter test integration_test/workspace_test.dart -d <device_id>
flutter test integration_test/today_test.dart -d windows
flutter build windows
flutter build web --no-web-resources-cdn
flutter build apk --debug
```

Node tests are optional gateway protocol checks; Node is not required to run the
Flutter app. Native PDF tests use the package's documented PDFium module override
because Flutter's test runner is not an installed desktop app. The real parser and
synthetic PDF are exercised. Native build hooks need the platform C/C++ compiler
(Visual Studio on Windows; Clang for cloud Linux tests) and may download verified
PDFium/SQLite artifacts on the first build. Browser PDF assets ship in the app.

For laptop acceptance: create and reload a task; pin a block; propose and cancel,
then approve a schedule; import a fixture twice; practise recall; add an expense;
export/restore a backup; test the offline chat demo; resize and enable 200% text.
Review [validation evidence and platform limits](docs/validation.md) before treating
any feature as production complete.
