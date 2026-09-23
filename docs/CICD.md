# CI/CD

Seven GitHub Actions workflows under `.github/workflows/`. All of them —
except the two release stubs — trigger on every `push` (any branch) and
on pull requests touching relevant paths, matching this repo's actual
setup rather than a typical main-branch-only pipeline.

| Workflow | Trigger | What it does |
|---|---|---|
| `mobile-analyze.yml` | push, PR (`lib/**`, `test/**`, `pubspec.*`, `analysis_options.yaml`) | `flutter analyze` |
| `mobile-test.yml` | push, PR | Runs the scoped test suite (files with an actual `main()` — see `docs/TESTING.md`) |
| `mobile-build-android.yml` | push, PR (`lib/**`, `android/**`, `pubspec.*`) | `flutter build apk --debug` — uses Gradle's debug signing config, no keystore secret needed. Uploads the APK as a build artifact. |
| `mobile-build-ios.yml` | push, PR | iOS build — **currently fails**: missing `ios/Podfile`, needs Xcode access to generate. Known, tracked, not yet fixed. |
| `mobile-release-android.yml` | — | Empty stub. Phase 10: signed release APK/AAB, needs a real keystore in CI secrets. |
| `mobile-release-ios.yml` | — | Empty stub. Phase 10: TestFlight, needs a macOS runner + Apple Developer account. |
| `secrets-scan.yml` | push | Scans the diff for committed secrets. |

All workflows pin `flutter-version: "3.47.2"` on the `stable` channel
(`subosito/flutter-action@v2`) and Java 17 (`temurin`) for the Android
build's Gradle step.

## Pre-commit hook (local, not CI)

`.git/hooks/pre-commit` runs the same two checks CI does
(`flutter analyze` then the scoped test run) before every local commit —
so a CI failure on `analyze`/`test` should be rare; if it happens despite
a clean local commit, suspect an environment difference (Flutter/Dart
version drift between local and the pinned CI version) before assuming
flakiness.

## Secrets

No CI secrets are currently configured for signing (neither Android nor
iOS) — the debug build sidesteps this for now. `secrets-scan.yml`
prevents committing new ones by accident; it doesn't manage what's
already stored as repository/organization secrets on GitHub (not visible
from the codebase, check the repo's own GitHub Settings → Secrets).

## What's missing for a real release pipeline

- Android keystore + `mobile-release-android.yml` implementation.
- iOS: fix the `Podfile` gap, then a macOS runner + Apple Developer
  account + `mobile-release-ios.yml` implementation.
- No deployment step exists for the backend (`steriqore`) from mobile
  CI, nor should it — that's a separate repo/pipeline.
