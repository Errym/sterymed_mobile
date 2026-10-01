# Security

What's actually implemented, as of 2026-09-27, verified against the code
(not aspirational — see [Known gaps](#known-gaps) for what isn't).

## Threat model (mobile-specific)

Scoped to what's realistic for a clinic-deployed sterilization-traceability
app, not a generic checklist. Each row is a real, code-verified answer —
not a claim.

| Threat | Mitigated? | How |
|---|---|---|
| Lost/stolen unlocked device — session/token theft | Partial | Bearer token lives in `SecureStorage` (Keychain/`encryptedSharedPreferences`, see [Credential storage](#credential-storage)), not plaintext prefs. **No app-level PIN/biometric re-lock** — anyone with the unlocked OS session can open the app and act as the logged-in user until they explicitly log out. See [Known gaps](#known-gaps). |
| Network eavesdropping / on-path attacker (public wifi, compromised router) | Partial | Standard TLS only when the backend is actually reachable over `https://`; **no certificate pinning** (see [Certificate pinning](#certificate-pinning) below) — a device with a trusted-store-injected MITM proxy (e.g. a compromised/managed device, some corporate MDM setups) could intercept traffic undetected. |
| Compromised or malicious backend tenant escalating a low-privilege account | Mitigated server-side | RBAC is enforced by the real backend `spatie/permission` grants on every request; the app's own gating is a UX convenience only — see [Access control](#access-control-rbac). A compromised backend is out of this app's threat model (that's `steriqore`'s own security posture). |
| Reverse-engineering the shipped APK/IPA (extracting logic, strings, endpoint list) | Partial | Android release builds enable R8 minification and resource shrinking (`isMinifyEnabled`/`isShrinkResources` in `android/app/build.gradle.kts`), but there is no Dart `--obfuscate`/`--split-debug-info` in any build workflow. Low actual exposure today (no secrets are hardcoded — see [Secrets](#secrets) — and the real access boundary is server-side), but the binary is not hardened against inspection. |
| Rooted/jailbroken device running a tampered app | **Not mitigated** | No root/jailbreak detection exists in `lib/`. Accepted risk for a pilot; would need `flutter build`-time integrity checks (Play Integrity API / DeviceCheck) before a wider rollout. |
| Malicious/typo'd deep link or QR-scanned label code | Partial | Label codes are looked up server-side by exact match (`LabelRepository.getByCode`) — an invalid/malicious code returns a real 404, not a client-parsed/executed value. Not a significant attack surface today since there's no client-side deep-link scheme registered beyond `go_router`'s own in-app routes. |

## Credential storage

- Bearer token and session data (`TokenStorage`, `SessionStore`) go
  through `SecureStorage` (`lib/core/storage/secure_storage.dart`), which
  wraps `flutter_secure_storage`:
  - **Android**: `encryptedSharedPreferences: true` explicitly.
  - **iOS**: Keychain by default (no explicit options needed — Keychain
    is the platform default for this package).
- Nothing session-related goes through `shared_preferences` — that
  dependency was removed entirely from `pubspec.yaml` this session after
  confirming zero imports used it anywhere in `lib/`.

## Transport

- `AuthInterceptor` (`lib/core/network/interceptors/auth_interceptor.dart`)
  attaches `Authorization: Bearer <token>` from `TokenStorage` to every
  request.
- `IdempotencyInterceptor` attaches a UUID v4 `Idempotency-Key` to every
  mutating request (`generateIdempotencyKey()`), matching the backend's
  `EnsureIdempotency` middleware — a benign retry (same key, same
  payload) replays the original response rather than double-processing;
  see `docs/OFFLINE_MATRIX.md`'s sync engine section for how the outbox
  handles the genuine-conflict case (409 with a *different* payload).
- **No certificate pinning** — see [Certificate pinning](#certificate-pinning)
  below; deferred to v1.1, not an oversight.
- **HTTPS enforced in production as of this task.**
  `Env.assertSecureTransportInProduction()` (called from `bootstrap()`)
  throws at startup if `Env.isProduction` is true and `Env.apiBaseUrl`
  doesn't start with `https://` — a production build can no longer
  silently ship pointed at a plaintext backend. `Env.apiBaseUrl`'s
  `http://10.0.2.2:8000/api` default remains for local emulator/device
  testing (`Env.isProduction` is false there) — see
  `test/unit/core/env_test.dart`'s `Env.checkSecureTransport` group.

## Certificate pinning

**Deferred to v1.1, not implemented today.** Rationale:

- The current deployment target is a single pilot clinic reaching one
  known `steriqore` backend over a connection the clinic controls (its
  own wifi/router) — the realistic on-path-attacker scenario (a
  compromised/managed device with an injected trusted-store MITM
  certificate) is a real but low-probability risk at this stage, not the
  top priority against a 55-day, 41-screen build.
- Pinning has a real operational cost this app isn't yet set up to
  absorb safely: a pin tied to the current TLS certificate/key breaks
  every installed app on that cert's next rotation unless a pin-rotation
  process ships first (multiple pins, a remote-config fallback, or a
  forced-update path) — none of which exists yet
  (`mobile-release-android.yml`/`mobile-release-ios.yml` are still empty
  stubs, see `docs/CICD.md`).
- Revisit before a wider multi-clinic rollout, and definitely before
  handling a higher-sensitivity data class than this app does today.

## Logging and crash reporting

- `PiiScrubber` (`lib/core/utils/pii_scrubber.dart`) redacts `token`,
  `password`, `patient_id`, `practitioner_id`, and `Bearer <token>`
  patterns from any string before it's logged or sent.
- Applied in two places: `LoggingInterceptor` (Dio request/response
  logging) and `CrashReporter`'s Sentry `beforeSend`/`beforeBreadcrumb`
  hooks (`lib/core/crash/crash_reporter.dart`) — every event is scrubbed
  before leaving the device, not just logged locally.
- **Fixed 2026-09-26 (Task 4.1 audit):** `beforeSend`'s scrub previously
  only touched `event.message`, which Sentry only populates for
  `captureMessage`. `CrashReporter.capture()` actually calls
  `Sentry.captureException`, whose text lands in
  `event.exceptions[].value` — a field that was never scrubbed. Now
  `scrubEvent` also scrubs every exception's `value`. Covered by
  `test/unit/core/crash_reporter_scrub_test.dart`. Note: `capture()` has
  zero call sites in `lib/` today, so this was a latent gap, not an
  observed leak.
- Sentry is opt-in via `SENTRY_DSN` (`--dart-define`); with an empty DSN
  (the default), `CrashReporter.init()` is a no-op.

## PII rules

- **The app's own data model never carries a real patient name.** Every
  patient-facing model field is either an anonymized `patient_reference`
  (e.g. `PAT-000001`, generated by the backend — see
  `docs/PROSTHETIC_MODULE.md`) or an opaque `patient_id` UUID — grep
  confirms no `patient_name`/`patientName` field exists anywhere in
  `lib/`. This is a property of what the backend contract sends, not a
  client-side filter — worth re-confirming if a future endpoint ever adds
  a real name field to a response.
- Given that, [`PiiScrubber`](#logging-and-crash-reporting)'s job is
  narrower than "strip all PII" — it redacts the fields that *are*
  sensitive in this app: `token`, `password`, `patient_id`,
  `practitioner_id`, and any `Bearer <token>` string, from every string
  that reaches a log line or a Sentry event.
- **Known limitation**: `PiiScrubber` matches on exact JSON key patterns
  (`"patient_id":"..."`). A future field with different casing/nesting
  (e.g. a nested object's `id` reused ambiguously) would not be caught
  automatically — it's a fixed pattern list, not a schema-aware scrubber.
  Extend `_patterns` in `lib/core/utils/pii_scrubber.dart` if the backend
  contract adds new sensitive fields.
- Applies equally to local debug logs and anything sent to Sentry — see
  [Logging and crash reporting](#logging-and-crash-reporting) for where
  it's actually wired in (both call sites are required; adding a new Dio
  interceptor or crash-reporting call site must route through
  `PiiScrubber.scrub()` too, not just the two existing ones).

## Access control (RBAC)

- Route- and action-level gating is driven by the tenant's real
  `spatie/permission` grants from `/v1/auth/login` / `/v1/me`
  (`SessionStore.hasPermission`/`hasAnyPermission`), not a client-side
  hardcoded role table — see `lib/core/router/guards/role_guard.dart`'s
  doc comment for the full route → permission map.
- Client-side gating is a UX convenience (hide actions a user can't
  perform), **not** the security boundary — the backend enforces the same
  matrix independently and must reject unauthorized mutations
  server-side regardless of what the client shows.

## Secrets

- `secrets-scan.yml` runs `gitleaks` on every push/PR (`.github/workflows/secrets-scan.yml`).
- **Verified 2026-09-26 (Task 4.1 audit):** ran `gitleaks detect` directly
  against the full local repo (git-history mode, not just the working
  tree — the working-tree/`--no-git` mode falsely flags Chrome's own
  bundled public API key inside gitignored `.dart_tool/` build cache,
  confirmed and discarded as a false positive) — 55 commits scanned,
  **zero leaks found**.
- `.env.local` (gitignored) holds test credentials for local/device
  testing against the dev backend — never read by the shipped app
  (`Env` reads compile-time `--dart-define` values only).
- No API keys, tokens, or credentials are hardcoded in `lib/`.

## Incident response

**Process exists; real contacts don't yet — flagging rather than
inventing them.** Same category as the placeholders `README.md`'s "Known
gaps" already lists for `docs/RUNBOOK.md`/`docs/USER_GUIDE.md`: on-call
contacts are information only the product owner can provide, not
something derivable from the code.

- **If a security incident is suspected** (leaked credential, confirmed
  unauthorized access, a `secrets-scan.yml`/`gitleaks` hit on a real
  secret rather than a false positive): rotate the affected credential
  first (backend API keys/DB creds live in `steriqore`'s own secrets, not
  this repo — see that repo's security docs), then force-logout affected
  sessions via the existing `AuthLogoutEverywhereRequested` flow
  (`lib/features/auth/presentation/bloc/auth_event.dart` — already wired
  in `SettingsScreen`'s "Se déconnecter partout").
- **Contacts: TODO — needs the product owner.** No on-call rotation,
  security email alias, or escalation path is recorded anywhere in this
  repo today. Fill in before this app handles real patient data at scale
  beyond the current pilot; until then, route any suspected incident to
  whoever the product owner designates directly rather than a documented
  address that doesn't exist yet.
- **Regulatory note**: this app handles clinic/patient-adjacent data
  (see [PII rules](#pii-rules)) — an actual incident may carry GDPR/ARS
  notification obligations in addition to the technical response above.
  That determination needs the product owner or legal counsel, not this
  document.

## Known gaps

- **No certificate pinning** — see [Certificate pinning](#certificate-pinning);
  a deliberate, rationale'd deferral to v1.1, not an oversight.
- **No formal, independent security audit.** This document is a
  from-the-code inventory of what exists, not a third-party pentest or
  OWASP Mobile Top 10 sign-off.
- **Biometric/PIN app-lock**: not implemented. Session persists via
  `SecureStorage` with no additional local-unlock gate — see the threat
  model's lost/stolen-device row.
- **Limited binary hardening.** R8 is on for Android release, but no Dart
  `--obfuscate` in any build workflow, and no root/jailbreak detection — see the threat model.
- **RBAC coverage isn't exhaustive.** Extended significantly this
  session (route-level + several in-screen action gates), but wasn't a
  screen-by-screen audit of every mutating button in the app — treat the
  route-level gate (server-enforced regardless) as the real boundary,
  not the presence of a client-side hide/show check on any given button.
- **Incident response contacts are undefined** — see
  [Incident response](#incident-response).
