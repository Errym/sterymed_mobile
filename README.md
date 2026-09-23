# SteryMed Mobile

A Flutter app for sterilization traceability in dental clinics: scanning
device labels, recording sterilization cycles and their control tests,
tracking stock and purchase orders, and working offline with a sync queue
for when the clinic's connection drops.

> The prosthetic module described in some early planning docs is **not
> in this app** — deferred per [`docs/adr/0010-prosthetic-deferred.md`](docs/adr/0010-prosthetic-deferred.md)
> after confirming the backend has no prosthetic domain. Don't be misled
> by references to it elsewhere in the repo's history.

## Prerequisites

- Flutter SDK `3.47.2` (stable channel — matches CI; see `.github/workflows/`)
- Dart SDK `>=3.4.0 <4.0.0` (bundled with the Flutter SDK above)
- A running `steriqore` backend (see that repo's own README) — this app
  talks to it over HTTP, it doesn't embed or mock a backend
- Android: Java 17 (`temurin`) for Gradle builds
- iOS: Xcode (builds are currently unsigned/simulator-only — see
  [Known gaps](#known-gaps))

## Setup

```bash
flutter pub get
```

The app reads its backend URL and environment from compile-time
`--dart-define` values (`lib/core/config/env.dart`), not a `.env` file
bundled into the app — `.env.local` in the repo root is a convenience
file of *test credentials* for manual/device testing against the local
`steriqore` dev stack, gitignored, not read by the app itself.

## Running

Against a local `steriqore` instance (`docker compose up -d` in that repo,
serving on `:8000` inside its network):

```bash
# Android emulator — 10.0.2.2 is the emulator's alias for the host machine
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api --dart-define=ENV=dev

# iOS simulator / web — the simulator shares the host's localhost
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api --dart-define=ENV=dev

# Physical device — use the host machine's LAN IP instead of localhost
flutter run --dart-define=API_BASE_URL=http://<your-machine-ip>:8000/api --dart-define=ENV=dev
```

Without any `--dart-define`, `API_BASE_URL` defaults to
`http://10.0.2.2:8000/api` (Android-emulator-friendly) and `ENV` defaults
to `dev`. Test credentials for the demo tenant are in `.env.local`.

## Testing

```bash
flutter analyze

# Scoped to files that actually have a main() — the repo has ~20 empty
# test-file stubs (0 bytes) left over from early scaffolding; they don't
# compile and aren't a real regression signal. This is exactly what the
# pre-commit hook (.git/hooks/pre-commit) and CI run.
test_files=$(find test -name "*_test.dart" -exec grep -l "void main(" {} \;)
flutter test $test_files

# With coverage (writes coverage/lcov.info)
flutter test --coverage $test_files
```

## CI

Seven workflows under `.github/workflows/`, all triggered on every push
and on PRs touching relevant paths:

| Workflow | What it does |
|---|---|
| `mobile-analyze.yml` | `flutter analyze` |
| `mobile-test.yml` | The scoped test run above |
| `mobile-build-android.yml` | Debug APK build (Gradle debug signing — no keystore needed) |
| `mobile-build-ios.yml` | iOS simulator build (currently fails — missing `ios/Podfile`, needs Xcode access to fix; tracked, not yet resolved) |
| `mobile-release-android.yml` | Empty stub — Phase 10 (release signing) |
| `mobile-release-ios.yml` | Empty stub — Phase 10 (TestFlight) |
| `secrets-scan.yml` | Scans for committed secrets |

## Architecture

- **Clean architecture per feature**: `lib/features/<feature>/{data,presentation}` —
  data sources → repositories → blocs/cubits → screens/widgets.
- **Offline outbox**: `lib/core/storage/outbox/` (`OutboxStore`, `SyncEngine`,
  `OutboxOperation`) + `lib/core/sync/` (`ConnectivityService`,
  `SyncStatusCubit`). See [`docs/OFFLINE_MATRIX.md`](docs/OFFLINE_MATRIX.md)
  for exactly which writes queue offline and which don't — it's narrower
  than the original plan; check it before assuming a write is resilient
  to a dropped connection.
- **RBAC**: `lib/core/router/guards/role_guard.dart` gates routes by the
  tenant's real `spatie/permission` grants (surfaced via `/v1/auth/login`
  and `/v1/me`), not a hardcoded role list — see that file's doc comment
  for the full permission map.
- **API contract**: [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md) —
  frozen against a specific `steriqore` commit; any change requires a
  written change request per that doc's header.
- **Architecture decisions**: `docs/adr/`.

## Known gaps

- iOS has no release signing configured yet, and its CI build currently
  fails on a missing `Podfile` (needs Xcode access to generate).
- Android's release build config still uses the Gradle **debug** signing
  config (`android/app/build.gradle.kts`) — no real keystore exists yet.
- No real staging deployment exists (`docker-compose.staging.yml` in
  `steriqore` is a local-only skeleton — see that repo's open questions).
- `docs/USER_GUIDE.md`, `docs/PRIVACY.md`, `docs/RUNBOOK.md`,
  `docs/MIGRATION.md` are placeholders pending input only the product
  owner can give (screenshots, legal specifics, on-call contacts).
