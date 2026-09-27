# CI/CD

Seven GitHub Actions workflows under `.github/workflows/`. All of them —
except the two release stubs — trigger on every `push` (any branch) and
on pull requests touching relevant paths, matching this repo's actual
setup rather than a typical main-branch-only pipeline.

| Workflow | Trigger | What it does |
|---|---|---|
| `mobile-analyze.yml` | push, PR (`lib/**`, `test/**`, `pubspec.*`, `analysis_options.yaml`) | `flutter analyze --fatal-infos` |
| `mobile-test.yml` | push, PR | `flutter test --coverage` — the full suite; see `docs/TESTING.md` |
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
(`flutter analyze --fatal-infos` then `flutter test`) before every local
commit — so a CI failure on `analyze`/`test` should be rare; if it happens
despite a clean local commit, suspect an environment difference
(Flutter/Dart version drift between local and the pinned CI version)
before assuming flakiness. Not tracked by git (`.git/hooks/` is local-only
per clone) — there is no committed setup script that installs it for a
fresh clone; a new contributor's machine won't have it until someone
copies it in or a tracked install step is added.

## Dependency updates

`.github/dependabot.yml` — weekly PRs for `pub` (Dart/Flutter, root
`pubspec.yaml`), `github-actions` (workflow action versions), and
`gradle` (`android/`). No `npm`/`bundler`/etc. ecosystems — this is a
Flutter-only mobile repo.

## Local CI

`scripts/ci-local.sh` runs the same steps as the workflows above
(analyze, test, Android debug build, iOS simulator build if on macOS,
gitleaks if Docker is available) so a failure surfaces before pushing,
not after. It's a convenience mirror, not authoritative — if a
workflow's command changes, this script needs updating too, and CI's
result is always the one that counts, not this script's.

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
