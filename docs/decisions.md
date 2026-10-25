# Approved decisions

## Design foundation

- The user approved the design-system proposal: neutral light/dark surfaces,
  restrained crimson brand accent, amber warning/error family, Inter typography,
  spacing, responsive layout, and component contracts.
- Android is the primary production platform. Windows desktop and Chrome must
  support local development; Web production release is later scope.
- Local-first basic functionality must not require login, a backend, or real keys.
- Minimum Android API 26 is provisional until device and plugin compatibility
  are checked. Pin a stable Flutter SDK during separately approved scaffolding.
- This gate adds only tokens, theme foundations, focused tests, and this record.
  No app entry point, screens, features, packages, or platform scaffolding.

## Free API and server constraint

- The user requires generative AI APIs and server APIs to be free.
- Do not introduce paid API/server dependencies, mandatory billing accounts,
  automatic paid fallbacks, or paid deployment requirements.
- Core workflows must work offline. Development AI uses explicitly labelled
  mock responses, never presented as real model output.
- Any future hosted provider must have its current official free-use terms,
  quotas, billing requirements, data handling, and platform support reviewed
  before selection. Free-tier availability and unlimited use are not guaranteed.
- If free access is unavailable or exhausted, preserve local workflows and show
  an explicit unavailable state. Do not silently switch to a paid service.
- A local model may be evaluated later if the user's hardware supports it;
  availability and performance are not assumed. No provider is selected now.

## Validation and next gate

- A minimal Flutter package manifest was added to resolve SDK imports and enable
  the design tests after the user reported the missing-pubspec error. It declares
  only Flutter and its bundled flutter_test SDK dependency, without app or
  platform scaffolding. Minimum tooling is Flutter 3.24.0 / Dart 3.5.0, which
  supports the WidgetState APIs used by the approved theme. A specific stable
  toolchain release remains to be pinned during platform setup.
- At the design-only gate, Flutter/Dart were unavailable and the source was not
  compiled. Later cloud validation is recorded below.
- Inter assets, license, and font registration were subsequently added in the
  approved Home / Today phase.
- Full component-state contrast, focus-ring placement, reduced motion, platform
  configuration, and manual accessibility checks remain future approved work.
- With Flutter installed, run from the repository root:

  ```powershell
  flutter pub get
  dart format lib/core/design test/core/design
  flutter analyze
  flutter test test/core/design
  ```

- Runnable laptop commands after a separately approved app phase:

  ```powershell
  flutter run -d windows
  flutter run -d chrome
  flutter run -d <device_id>
  ```

- The design-only gate concluded before the user authorized continuation and
  selected Home / Today. Do not treat that approval as approval for further phases.

## Home / Today phase

- The user reported all design tests passing and authorized continuation, then
  explicitly selected Home / Today. Scope: one screen with synthetic fixtures,
  responsive layout, local reversible completion, theme selection, alternate
  states, and focused widget/integration tests. No other screens or domain phases.
- Sample completion and appearance are session-only. This phase does not claim
  persistence, scheduling optimization, import functionality, or live AI.
- Only the bundled integration_test SDK dependency was added, to exercise the
  offline completion/reset journey. No third-party Dart package was added.
- Inter is now bundled with its OFL license and pinned source/hash information.
- Platform setup is provided through tool/bootstrap.dart, which generates only
  missing Android, Windows, and Web runners in a temporary Flutter project,
  preserving source and existing runners. The provisional Android minimum is 26.
- Initial cloud validation was blocked by the SDK download-host policy. After
  storage.googleapis.com became allowed, Flutter 3.47.8 / Dart 3.13.7 was installed
  from the official Flutter repository/artifacts with TLS verification retained.
- Fixed the missing closing list bracket in the sample-state menu that caused
  the user's analyzer, test compilation, and Windows build failures. Dart
  formatting now succeeds across the source and tests.
- `flutter analyze`: no issues. `flutter test --concurrency=2`: all 19 tests passed.
  Appearance tests now tap the menu item and verify actual theme brightness.
- Bootstrap generated all three platform runners successfully; rerunning it
  preserved hashes of every existing runner file. Generated runners and package
  cache/lock outputs stay local in this cloud instance, avoiding collisions with
  the user's existing generated laptop files when they pull the source fix.
- `flutter build web --no-web-resources-cdn`: passed. Chromium smoke checks
  verified initial content, completion, reset, dark-theme canvas pixels, and
  narrow viewport rendering with no JavaScript page errors. Screenshots were
  captured for visual inspection. These are not full screen-reader checks.
- Windows native execution remains unrun on this Linux host. Android build/device
  checks and device integration tests remain unrun without their tooling. The
  browser smoke check does not replace these platform checks.
- Reusable cloud installation/startup instructions were tested and saved in an
  environment configuration draft. Saving is distinct from user publication.
- Stop at this phase pending the user's laptop validation and feedback; do not
  start another feature phase automatically.

## Broader continuation and visual revision

- The user requested more visual character and explicitly authorized continuing
  through all remaining feature phases. Earlier per-phase stop instructions are
  superseded by that authorization; implementation must still be validated and
  remaining limitations reported accurately.
- The visual revision uses warmer neutral text, a larger editorial headline,
  accessible rose foregrounds derived from the crimson brand, category badges,
  and a warm featured card. Crimson remains restrained; error feedback stays amber.
- The user approved Drift/SQLite, file_selector, and csv for local persistence and
  imports, then timezone and crypto for IANA zones and SHA-256 import checksums.
  These libraries require no paid service or billing account.
- Work proceeds through local data and deterministic scheduling, imports/progress,
  learning/coaching, and optional integration boundaries. Live external API access
  must never be claimed without credentials and actual verification.
