# Security

What's actually implemented, as of 2026-09-23, verified against the code
(not aspirational — see [Known gaps](#known-gaps) for what isn't).

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
- **No certificate pinning.** Standard platform TLS trust store only.
- **No code-level HTTPS enforcement.** `Env.apiBaseUrl`
  (`lib/core/config/env.dart`) defaults to a dev-only `http://` URL with
  no guard preventing a production build from shipping with a non-HTTPS
  base URL — see [Known gaps](#known-gaps).

## Logging and crash reporting

- `PiiScrubber` (`lib/core/utils/pii_scrubber.dart`) redacts `token`,
  `password`, `patient_id`, `practitioner_id`, and `Bearer <token>`
  patterns from any string before it's logged or sent.
- Applied in two places: `LoggingInterceptor` (Dio request/response
  logging) and `CrashReporter`'s Sentry `beforeSend` hook
  (`lib/core/crash/crash_reporter.dart`) — every event is scrubbed before
  leaving the device, not just logged locally.
- Sentry is opt-in via `SENTRY_DSN` (`--dart-define`); with an empty DSN
  (the default), `CrashReporter.init()` is a no-op.

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

- `secrets-scan.yml` runs on every push, scanning for committed secrets.
- `.env.local` (gitignored) holds test credentials for local/device
  testing against the dev backend — never read by the shipped app
  (`Env` reads compile-time `--dart-define` values only).
- No API keys, tokens, or credentials are hardcoded in `lib/`.

## Known gaps

- **No HTTPS enforcement.** A production build could theoretically ship
  pointed at a plaintext `http://` backend with no build-time or
  runtime guard against it. Should be closed before a real deployment —
  e.g. a build-time assertion that `Env.apiBaseUrl` starts with `https://`
  when `Env.isProduction`.
- **No certificate pinning.** Standard TLS trust store trust only;
  acceptable for a pilot, worth revisiting before a wider rollout.
- **No formal, independent security audit.** This document is a
  from-the-code inventory of what exists, not a third-party pentest or
  OWASP Mobile Top 10 sign-off.
- **Biometric/PIN app-lock**: not implemented. Session persists via
  `SecureStorage` with no additional local-unlock gate.
- **RBAC coverage isn't exhaustive.** Extended significantly this
  session (route-level + several in-screen action gates), but wasn't a
  screen-by-screen audit of every mutating button in the app — treat the
  route-level gate (server-enforced regardless) as the real boundary,
  not the presence of a client-side hide/show check on any given button.
