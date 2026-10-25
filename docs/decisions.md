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
- Flutter and Dart are not installed in the current cloud environment. Flutter
  compilation and tests have not been executed here. The design package is not
  a runnable application.
- Inter assets, their license, and font registration remain pending approved setup.
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

- Stop after this gate. Project scaffolding/platform setup and the first screen
  each require an agreed scope; selecting a screen does not authorize building it.

## Home / Today phase (authorized, runtime validation pending)

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
- No Flutter SDK is executable in this cloud instance. The official download
  host storage.googleapis.com returned a policy denial. Its domain addition was
  saved in the environment configuration draft; publication and runtime access
  are not established by that save.
- Manifest/config parsing, font file signature/license checks, and whitespace
  checks passed. These do not establish Dart syntax, compilation, UI behavior,
  platform generation, screenshot fidelity, or test success. Those checks remain
  pending until Flutter access is available. Do not mark this phase complete yet.
- Next action: enable the saved download-host requirement in environment settings
  and validate this phase; do not start another feature phase.
