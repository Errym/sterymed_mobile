# Release

**Status: skeleton — blocked on credentials/accounts only the product
owner can provide.** This is Phase 10 (Days 51-52) territory; see
`docs/CICD.md` for the current state of the build pipeline this would
extend.

## Android

- [ ] Real signing keystore — doesn't exist yet.
  `android/app/build.gradle.kts`'s release build currently falls back to
  the **debug** signing config.
- [ ] Keystore stored as CI secrets, `mobile-release-android.yml`
  implemented to build a signed APK + AAB (currently an empty stub).
- [ ] Google Play internal testing track access.
- [ ] Install-on-real-device smoke test — needs a physical device.

## iOS

- [ ] `ios/Podfile` is missing — `mobile-build-ios.yml` fails on this
  today, blocking even the *debug* build, let alone release. Needs
  Xcode access to generate/fix.
- [ ] Apple Developer account + provisioning for TestFlight.
- [ ] macOS CI runner for the release build
  (`mobile-release-ios.yml` is currently an empty stub).
- [ ] TestFlight install + smoke test — needs a physical device.

## Rollback plan

- [ ] Not defined. If a release ships a critical bug, what's the
  process — revert to the previous build in Play/TestFlight, a forced
  update prompt, something else? Needs a decision before the first real
  release, not after.

## Versioning

Current: `pubspec.yaml` → `version: 0.1.0+1`. No versioning policy
(semver rules, when to bump build number vs version) is documented yet.

## Staging verification before release

Per the plan's Day 53, a release should be verified against a real
staging deployment with pilot-scale seeded data first. No real staging
host exists yet (`steriqore`'s `docker-compose.staging.yml` is a local-
only skeleton) — this step is blocked on that, tracked as an open
question in the backend repo (OQ-10).
