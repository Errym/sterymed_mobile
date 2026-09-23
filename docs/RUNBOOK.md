# Runbook

**Status: skeleton — needs on-call/support contacts from the product
owner.** Structure and known-technical-detail sections are filled in;
who-to-call sections are not.

## Support contacts

- [ ] Primary on-call contact / rotation — not yet defined.
- [ ] Escalation path (who's called if the primary is unreachable) —
  not yet defined.
- [ ] SLA for pilot clinics (response time, resolution time) — this was
  also a pre-flight deliverable (P10, `docs/SUPPORT.md`) that's still
  empty; fill both together, they're the same information from two
  angles.

## Known operational facts (what exists today)

- **Backend**: `steriqore` (Laravel). Dev stack: `docker compose up -d`
  in that repo. No real staging/production host exists yet
  (`docker-compose.staging.yml` there is a local-only skeleton).
- **Mobile**: this repo. CI: 7 GitHub Actions workflows (see this repo's
  `README.md`). No release build pipeline yet (Android debug-signs only,
  iOS build currently fails on a missing `Podfile`).
- **Crash reporting**: Sentry, opt-in via `SENTRY_DSN`
  (`lib/core/config/env.dart`) — currently unset by default, so nothing
  reports anywhere unless a DSN is configured for a given build.
- **Offline sync failures**: items that can't sync land in "manual
  review" state in the outbox (`OutboxStatus.manualReview`), visible in
  the app's Sync Queue screen (`Routes.sync`). See
  `docs/OFFLINE_MATRIX.md` for exactly which write operations can even
  reach this state.
- **Backup/restore**: drilled and documented in `steriqore`'s
  `docs/BACKUP_RESTORE.md` — DB dump via `spatie/laravel-backup`, media
  via a custom S3 mirror command, both independently restore-tested.

## Incident triage starting points

- **User reports data didn't sync**: check the Sync Queue screen for
  manual-review items first — this is the expected outcome for a 409
  (idempotency key reused with a different payload) or 422/403
  response, not a bug by itself. A genuine bug is data that should have
  queued but silently didn't — cross-check against
  `docs/OFFLINE_MATRIX.md`'s matrix for whether that write operation is
  even wired to the outbox.
- **App crash reports**: Sentry (once a DSN is configured) —
  `CrashReporter.init()` is a no-op with an empty DSN, so "no crash
  reports" doesn't necessarily mean "no crashes" until this is verified
  configured for the environment in question.
- **Backend down / 5xx**: `steriqore`'s own operational docs (not this
  repo) — this runbook only covers the mobile client's behavior when
  that happens (retries with backoff, then queues writes / shows cached
  reads per `docs/OFFLINE_MATRIX.md`).
