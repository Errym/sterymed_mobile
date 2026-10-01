# Phase 0 build baseline

G02/G04 preparation, 1 October 2026. This records configuration and commands; it is not a signed-release certificate. See [the clinic release plan](../CLINIC_READY_MASTER_PLAN.md).

## Supported toolchain

| Item | Repository/installed evidence |
|---|---|
| Repeatable Flutter baseline | CI pins and installed `bin/cache/flutter.version.json`: **3.47.2 stable**, revision `d3b14c876900e553bc736ca19295fc09e3853e8e` |
| Installed Dart | **3.13.2**, from SDK metadata and `bin/cache/dart-sdk/version` |
| Declared lower bounds | Flutter **3.44.0**, Dart **3.12.0**; now match `pubspec.lock`'s SDK requirements |
| Android Gradle plugin / wrapper | 9.1.0 / 9.3.1, already configured |
| Android Kotlin / Java target | 2.4.0 / 17, already configured; CI selects Temurin 17 |
| iOS deployment target | 15.0 in the current Xcode project |
| App version | `0.2.0+1`; owner must assign the actual release number |

The local Flutter directory name contains `3.29.2`, but its installed metadata is 3.47.2. Use metadata, not the folder name. Raising the declared minima changes no dependency versions. The exact pinned SDK is the validation baseline; the lower bounds are dependency requirements and do not claim every intermediate SDK was tested.

The Dart 3.12 language version also enables private initializing formals. Six constructors now use `required this._field` to satisfy the analyzer while retaining the same public named arguments and field values, as documented in [Dart's private named parameters](https://dart.dev/language/constructors#private-named-parameters). No repository/session behavior changed in those edits.

Run from the mobile repository root:

```text
python scripts/verify_release_config.py
python -m unittest discover -s scripts/tests -p test_phase0_tools.py -v
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test --coverage --no-pub --reporter expanded
flutter build apk --debug --no-pub
```

Run Flutter commands sequentially; capture the exact output and source fingerprint with the Phase 0 ledger. A restricted sandbox may require approval for SDK cache writes. Failure to obtain dependencies or SDK access is a blocked check, not a passing result. Do not change dependency versions to bypass a failed locked install without reviewing the cause.

## Windows grouped runner

Use Git Bash with GNU coreutils:

```bash
bash scripts/run_tests_win.sh
```

The existing unit, bloc, widget and golden groups still run in that order, each with a 180-second timeout. Flutter output goes directly to `build/test_output.log`; the summary includes each group's status. All groups run, and the process returns the first failing status. Timeout statuses remain failures. Override the timeout with `TEST_TIMEOUT_SECONDS=300` if justified by measured local performance.

This is the user's grouped convenience runner. It does not include every test directory; the complete release gate remains `flutter test --coverage --no-pub`. Python process regressions use stub commands and never invoke Flutter.

## Android signing preparation

`android/app/build.gradle.kts` now uses an explicit release signing configuration from ignored `android/key.properties`. It no longer falls back to the debug key. A release task fails clearly when fields or the keystore are missing. Debug builds remain available for Phase 0 validation.

1. Have the owner confirm the application ID, distribution account and existing upload-key custody. Current `com.example.sterymed_mobile` remains a placeholder. Change namespace/source package coherently if needed; do not invent a business identifier.
2. Copy `android/key.properties.example` to `android/key.properties` and complete it locally with the owner-controlled key. The keystore path is absolute or relative to `android/`; use forward slashes on Windows. Existing ignore rules exclude the properties and JKS/keystore files.
3. Copy `docs/phase0/release-defines.example.json` to ignored `build/release-defines.json`. Replace its deliberately invalid host with the verified production `/api` base URL. Dart defines are compiled into the app; never put private credentials there.
4. Run the preflight using the same define file that the build will use:

```text
python scripts/verify_release_config.py --mode android-release --defines build/release-defines.json
flutter build appbundle --release --no-pub --dart-define-from-file=build/release-defines.json
```

The preflight checks declared/pinned SDKs, placeholder identifiers, signing field/file presence and explicit HTTPS production defines. It does not open the keystore or print credential values. It does not prove key validity/ownership, DNS/TLS reachability, artifact signing or store acceptance. Verify the resulting bundle's certificate against the owner's recorded fingerprint before distribution. No key was generated, no application ID was invented, and no publishing workflow was added.

**Current expected release blockers:** placeholder application ID, no configured owner key, no verified production define file. A successful debug APK does not close these items.

## Mac / iOS work to run next

No iOS build or archive was run on this Windows host. The current project uses a generated Swift Package Manager integration and has no committed Podfile. Existing simulator CI records an earlier `Pods_Runner` linking failure. That is an unresolved historical result to reproduce on a clean Mac, not proof of today's failure or success.

With the same Flutter 3.47.2 checkout and Xcode selected on a Mac:

```text
xcodebuild -version
xcode-select -p
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
flutter build ios --simulator --no-codesign --no-pub
flutter build ios --release --no-codesign --no-pub --dart-define-from-file=build/release-defines.json
```

Record Xcode, macOS, simulator/device, build log and plugin-resolution results. If CocoaPods fallback is required, resolve the current plugin requirements and Xcode integration on that Mac; do not remove generated package references or regenerate the whole platform project blindly. Commit only the reviewed authored project/dependency changes.

After the owner supplies the real bundle identifier, Apple team, provisioning and distribution method, configure them in `ios/Runner.xcworkspace`. Check duplicate permission keys/display-name cleanup, camera/photo explanations, entitlements, signing and archive validation. Then build an IPA using an owner-approved export-options file:

```text
flutter build ipa --release --no-pub --dart-define-from-file=build/release-defines.json --export-options-plist=build/ExportOptions.plist
```

Export options depend on the agreed distribution method and signing team; no fabricated template/team is supplied. Installing the archive on physical clinic devices, camera/media behavior and upgrade acceptance remain Phase 9 gates. The empty release workflow files remain empty; Phase 0 performs no publishing.

## Evidence and remaining checks

- **Configuration inspected:** all mobile analyze/test/debug-build workflow pins; pubspec and lock SDK constraints; Android Gradle/wrapper/manifest/ignore rules; iOS project/config/plist; installed SDK metadata.
- **Local tool verification (1 October):** nine Python/Git-Bash stub regression tests passed; baseline preflight exited 0 against the installed SDK. Android release preflight against the example defines exited 1 as intended, reporting the placeholder application ID, missing key.properties and placeholder API host. `git diff --check` passed. These checks do not compile the app.
- **Root agent validation:** analyzer, full Flutter suite and Android debug build are run separately to avoid concurrent SDK use. Record their actual outcomes before marking G04 verified.
- **Not run here:** macOS/iOS compilation, owner-key release signing, store upload, physical device installation, live backend acceptance or clinical operations.

