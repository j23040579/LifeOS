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

- The repository has no pubspec or Flutter app. Flutter and Dart are not installed
  in the current environment. The theme and test files cannot yet be compiled or
  executed here; the design gate is not a runnable application.
- Inter assets, their license, and font registration remain pending approved setup.
- Full component-state contrast, focus-ring placement, reduced motion, platform
  configuration, and manual accessibility checks remain future approved work.
- After project setup, run from the repository root:

  ```powershell
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
