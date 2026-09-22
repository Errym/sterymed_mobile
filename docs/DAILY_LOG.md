# Daily Log — SteryMed Mobile

## Template

### YYYY-MM-DD — Phase X Day Y

**Done today:**
-

**Blocked on:**
-

**Next:**
-

**Answers from stakeholders:**
-

---

## Entries

## Idempotency Test Deferred (original attempt)

Attempted to capture real 409 on `/v1/stock-movements/adjust`. The endpoint rejects our seeded data with 422 VALIDATION_FAILED, so the request never reaches the idempotency layer.

**Root cause:** The batch/location seeded via tinker doesn't satisfy the adjustment's business rules (likely requires a receipt, or a specific stock state).

**Decision (superseded below):** Defer real 409 capture to Phase 3.

The `IdempotencyInterceptor` in code is already correct — it injects a UUID v4 into every queuable POST. Phase 3 will verify the backend honors it.

---

### 2026-09-22 — Idempotency resolved (Phase 0 gate closed)

Resolved without needing seeded stock data: read the backend's own `EnsureIdempotency` middleware source (`steriqore/app/Http/Middleware/Api/EnsureIdempotency.php`, `steriqore` @ `6af6b9c`), then confirmed it live against `POST /v1/auth/login` (which also requires an `Idempotency-Key`):

- Same key + same body sent twice → **both return HTTP 200 with an identical cached response body** (verbatim replay at the original status — not 409).
- Same key + a *different* body (different user's credentials) → **HTTP 409 `IDEMPOTENCY_KEY_REUSED`**, `"This Idempotency-Key was already used with a different request."`

**Conclusion:** the master plan's ground rule ("the 409 is success, not error... replayed idempotency keys mean already recorded") and the old `docs/ERROR_MATRIX.md` entry ("409 = idempotency replay") were both wrong. A benign replay is a 200 (or the original success status), not a 409. 409 only fires on genuine key misuse (same key, different payload) and should be treated as a bug/logged, not swallowed.

**Impact on mobile code (revised 2026-09-22, see below):** at the time, I claimed none was needed because `SyncEngine` treats any non-throwing response as success — true for the benign-replay case, but I never actually re-read the explicit 409-*throwing* branch's code before writing that. It was wrong; see the Phase 5 entry below. `docs/ERROR_MATRIX.md` and `docs/BACKEND_BUGS.md#BUG-006` updated to match. Phase 0 API-contract verification is now complete.

---

### 2026-09-22 — Phase 1: CI, Sentry wiring, network security config

- Wrote real content for the 5 CI workflows required by Gate 1 (`mobile-analyze`, `mobile-test`, `mobile-build-android`, `mobile-build-ios`, `secrets-scan`); the 2 release workflows (`mobile-release-android.yml`, `mobile-release-ios.yml`) are left empty — out of Phase 1 scope, deferred to Phase 10.
- Added `sentry_flutter` and wired `CrashReporter` to actually call `SentryFlutter.init`/`Sentry.captureException`, with `beforeSend` and `beforeBreadcrumb` both routed through `PiiScrubber`.
- **TODO (blocking full Gate 1 close-out): need a real Sentry DSN.** Code is done and is a safe no-op with an empty DSN (`Env.sentryDsn` defaults to `''`). Owner: you — deferred until before Phase 9 per your instruction. Once supplied via `--dart-define=SENTRY_DSN=...`, still need to send a test event and verify it lands in the Sentry dashboard to close Gate 1's "Sentry receives a test event" checkbox.
- Added debug-only `android/app/src/debug/res/xml/network_security_config.xml` (cleartext allowed for `10.0.2.2`/`localhost`/`127.0.0.1` only, debug build variant only) — real Android devices block cleartext HTTP by default since API 28, which would otherwise block every request to a non-HTTPS local dev backend.
- Filled `test/unit/core/env_test.dart` (previously an empty stub, explicitly required by Gate 1's T1.62 checklist).

---

### 2026-09-22 — CI actually runs for the first time; Android fixed, iOS parked

All 5 real CI workflows had `push: branches: [main]`, but every push this session went to `phase-2-offline-outbox` — none of them had ever actually run against real work. Confirmed via `gh run list`: only the 2 still-empty release workflows fired (failing in 0s, as expected), and the 5 real ones had no run history past 2026-09-18, before this branch started. Fixed by dropping the branch restriction on `push`.

Once CI actually ran, it caught two real, previously-undetected native build failures that my own local `flutter build apk --debug` never reached (killed early by low memory):

- **Android — fixed.** `sentry_flutter` 8.14.2's `android/build.gradle` hardcoded Kotlin `languageVersion = "1.6"`, which Kotlin 2.x (this project's KGP is 2.4.0) no longer supports at all — `compileDebugKotlin` failed outright. Upgraded `sentry_flutter` to `^9.30.1`, which dropped that pin. Verified: Android build now passes in CI.
- **iOS — fixed one bug, hit a second, parked.** 8.14.2's Swift plugin code also called a `SentryBinaryImageCache` member that no longer exists in the `sentry-cocoa` version Swift Package Manager resolves — the same 9.30.1 upgrade fixed this (confirmed: that specific compile error is gone). But the build still fails afterward with `Framework 'Pods_Runner' not found` / linker error. Root cause is unrelated to Sentry: this project has no committed `ios/Podfile` (it predates Flutter defaulting new projects to Swift Package Manager), and `flutter_secure_storage`/`mobile_scanner` don't support SPM yet, so Flutter falls back to an auto-generated CocoaPods setup that isn't linking correctly against the Xcode project.
  - Tried `flutter config --no-enable-swift-package-manager` in CI (Flutter's documented remedy for exactly this class of problem) — did not fix it. Read `flutter_tools`' own source (`darwin_dependency_management.dart`) and confirmed the "plugins do not support Swift Package Manager" message is an unconditional warning, unrelated to the actual linker failure — so that fix was targeting the wrong thing.
  - **Parked per your instruction.** Needs interactive Xcode/macOS debugging (Pods target build phases, framework search paths) that isn't possible from CI log inspection alone. `mobile-build-ios.yml` will keep failing until someone with Mac access investigates.

---

### 2026-09-22 — Phase 5 audit: SyncEngine 409 handling was silently unsafe

Auditing Phase 5 ("Usage + patients + offline outbox — the phase that makes or breaks the app") against the actual codebase before building anything, same as every phase this session. Patients, label usage form, and the full outbox/sync infrastructure (`OutboxItem`, `OutboxStore`, `SyncEngine`, `ConnectivityService`, `SyncStatusCubit`) already exist. While re-reading `sync_engine.dart` I found it still carried the exact stale idempotency assumption from earlier today ("409 → already recorded, mark done") — I'd corrected the docs but never actually went back and fixed the code, and my own earlier claim that "no code change was required" turned out to be wrong (see the correction above).

**The real risk:** a genuine 409 (`IDEMPOTENCY_KEY_REUSED`) means the same key was reused with a *different* payload — the backend never recorded *this* item's data under that key. The old code removed the item from the outbox anyway, treating it as done. That's silent data loss on a sterilization-traceability app. A benign replay (the actual common case, same key + same payload) never reaches this branch at all — it returns the original 2xx and is already handled by the success path.

**Fixed:** 409 now routes through the same manual-review path as 422/403 (kept in the outbox, surfaced for review, not silently discarded). Removed the now-dead `SyncResult.conflict` enum value (was only ever produced by the buggy branch). Updated `test/unit/storage/sync_engine_test.dart`'s 409 test, which had explicitly asserted the old (wrong) behavior.

In practice this should be very rare — outbox items each get their own UUID v4 key, so a genuine collision-with-different-payload shouldn't happen under normal operation — but "shouldn't happen" is exactly the case a sync engine needs to fail safe on, not silently swallow.
