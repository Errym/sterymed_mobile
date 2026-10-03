# Testing

**Updated 2026-10-01.** 76 `*_test.dart` files exist under `test/`. A fresh
`flutter test` on the working tree gave 488 passed / 13 failed (mid-refactor of
session/storage code); the last measured line coverage was 34.5%. The
per-directory table below is from 2026-09-26 and is approximate. Older text
that follows: 51 files matching `*_test.dart` existed;
**all 51 compile and have a real `main()`** — the CI/pre-commit
compile-crash workaround this doc used to describe (a grep filter for
files with `void main(`) is gone as of Task 2's completion; CI and the
pre-commit hook both now run `flutter test` unfiltered — see
`docs/CICD.md`.

## Coverage, by directory

| Directory | Files | What it covers |
|---|---|---|
| `test/unit/core/` | 10 | `ApiException`/`ErrorMapper`, idempotency key generation, `PiiScrubber` + the `CrashReporter` Sentry scrub integration, `RoleGuard`, validators, `Env`, `Debouncer`, the static `leak_check_test.dart` dispose audit, the `stock_seed_check` bootstrap helper |
| `test/unit/repositories/` | 3 | `CycleRepository`, `LabelUsageRepository`, `PurchaseRepository` — online/offline-fallback paths |
| `test/unit/storage/` | 3 | `OutboxStore`, `SyncEngine` (incl. the 409/422 manual-review paths), `LabelUsageDraftStore` |
| `test/unit/sync/` | 1 | `SyncStatusCubit` (flush-on-start/reconnect) |
| `test/unit/features/prosthetic/` | 4 | Draft store round-trip, status transitions (mirrors the real backend's `allowedNextStatuses()`), remaining-balance/payment-due logic, waiting-placement filter logic |
| `test/unit/contract/` | 2 | `api_endpoints_test.dart` (every `ApiEndpoints` path checked against a live-spec snapshot), `error_codes_test.dart` (`ApiException` getters against the real UPPER_SNAKE_CASE backend codes) |
| `test/bloc/` | 18 | See below — 17 real, 1 documented-empty |
| `test/widget/` | 10 | See below — all real |

Coverage report (`flutter test --coverage`) was last measured Day 48 at
15.5% overall line coverage, before Task 2 added the 9 files below —
stale, not re-measured since; re-run `flutter test --coverage` and check
`coverage/lcov.info` for a current number rather than trusting this line.

### `test/bloc/` (18 files)

Real coverage: `alert_list_bloc_test.dart`, `audit_list_bloc_test.dart`,
`auth_bloc_test.dart`, `cycle_detail_bloc_test.dart`,
`cycle_list_bloc_test.dart`, `cycle_transition_bloc_test.dart`,
`dashboard_cubit_test.dart`, `goods_receipt_flow_test.dart`,
`label_detail_bloc_test.dart`, `label_usage_flow_test.dart`,
`prosthetic_case_detail_flow_test.dart`, `prosthetic_list_bloc_test.dart`,
`prosthetic_payment_section_test.dart`, `prosthetic_status_flow_test.dart`,
`scanner_bloc_test.dart`, `stock_issue_bloc_test.dart`,
`sync_status_bloc_test.dart` (real class is `SyncStatusCubit`, not a
Bloc — noted in the file).

Five of these (`goods_receipt_flow_test.dart`, `label_usage_flow_test.dart`,
`prosthetic_case_detail_flow_test.dart`, `prosthetic_payment_section_test.dart`,
`prosthetic_status_flow_test.dart`) are named after Bloc classes that
**don't exist** — those five screens use direct `setState` +
repository/`getIt` calls, no Bloc. Each file tests that real pattern
instead (see its own header comment) — a deliberate choice, not a
mismatch to fix.

`waiting_placement_bloc_test.dart` is the same "phantom bloc" situation,
but with nothing distinct left to test: `test/widget/waiting_placement_screen_test.dart`
already fully covers the real screen (`ProstheticWaitingPlacementScreen`)
this name points at. Kept as a real, compiling, documented file rather
than either fabricating duplicate coverage or deleting it.

### `test/widget/` (10 files)

All real: `alert_list_screen_test.dart`, `cycle_detail_screen_test.dart`,
`dashboard_screen_test.dart`, `label_blocked_screen_test.dart`,
`label_detail_screen_test.dart`, `login_screen_test.dart`,
`prosthetic_case_detail_test.dart`, `prosthetic_form_test.dart`,
`sync_status_banner_test.dart`, `waiting_placement_screen_test.dart`.

## Golden tests

4 now exist under `test/golden/` (login, dashboard, label detail,
prosthetic case detail) — see `test/COVERAGE.md`'s "Golden tests" section
for what they cover and, importantly, the still-real cross-platform risk
this section used to avoid entirely: developing on Windows while CI runs
`ubuntu-latest` means a Windows-generated golden PNG may not byte-match
Linux font/anti-aliasing rendering. That risk was not resolved here (no
Linux environment was available to regenerate them against), only
documented — read `test/COVERAGE.md` before assuming a red `mobile-test.yml`
run on these 4 files is a real regression rather than a platform mismatch.
Every other screen keeps the structural (finder-based: "does this
text/icon/widget exist") style tests already in `test/widget/` — golden
coverage is intentionally narrow, not a wholesale replacement.

## flutter_test environment gotchas worth knowing before adding a test here

Hit and resolved repeatedly while writing the widget tests above — save
yourself the rediscovery:

- A widget that opens a **real Hive box** directly in `initState` (e.g.
  `CycleNotesCache` inside `CycleDetailScreen`'s notes section) never
  settles inside `testWidgets`' zone, even though the exact same call
  resolves instantly in a plain `test()`. Fix: pre-open that Hive box in
  `setUpAll` (outside the widget-test zone) so the widget's own
  `Hive.openBox()` call returns the already-open, cached instance
  synchronously; use bounded `pump()` loops instead of `pumpAndSettle()`
  on that screen regardless.
- `SectionHeader` and `TypeBadge` both **upper-case** their label text —
  `find.text()` must match the upper-cased string, not the source string
  passed into the widget.
- A plain `ListView(children: [...])` still **lazily mounts only
  in-viewport (+ cache-extent) children** — an off-screen section or
  button genuinely isn't in the element tree yet, not just unpainted.
  Scroll to it first (`tester.drag`, not blind `dragUntilVisible` when
  there are multiple near-identical icons/sections — target the specific
  one via `find.ancestor`/`find.descendant` around its own section
  header text, not `.first`, which can silently pick the wrong one).
- A screen that calls `context.pop()` / `Navigator.pop()` right after a
  success snackbar can't be asserted for that snackbar text in a bare
  `pumpApp` harness with no real back-stack — `go_router`'s `pop()`
  throws with no `GoRouter` ancestor (replacing the snackbar with an
  error one from the same `catch`), and a plain `Navigator.pop()` on the
  sole route tears down the subtree before the snackbar can be observed.
  Verify the real repository call instead of the transient snackbar text
  in that case.

## Integration tests

`integration_test/` has 18 files, 12 of them 0 bytes (checked 2026-10-01). Older
breakdown, 2026-09-26: 16 files, **4 had real content**:
`journeys/auth_journey_test.dart`, `journeys/cycle_lifecycle_journey_test.dart`,
`support/test_user.dart`, and the new `support/live_backend_guard.dart`
(plus the tiny `drivers/integration_test_driver.dart` boilerplate). Both
real journeys now skip by default (`kSkipUnlessLiveBackend`) and only run
with `--dart-define=RUN_LIVE_INTEGRATION_TESTS=true` in addition to their
own `API_BASE_URL`/`ENV` defines — see the guard file's doc comment for
why: newer Flutter/`integration_test` versions can attempt to run these
headlessly via a bare `flutter test integration_test/`, which would
otherwise hang or fail against a backend that isn't there.

The other 11 — `app_test.dart` and 8 more journey files (`alert_resolve`,
`conflict_409`, `goods_receipt`, `offline_sync`, `prosthetic_case`,
`scanner_usage`, `stock_issue`, `waiting_placement`) plus 3 support files
(`backend_reset`, `backend_seed`, `test_data`) — are still 0 bytes,
including 4 of the 6 journeys the original plan named. This is the
largest remaining testing gap in the repo — see `test/COVERAGE.md` for
why they weren't written blind here.

## Backend (`steriqore`) tests and live proofs

- `scripts/backend_tests.sh` runs the backend Pest suite in an **isolated runner
  container against a separate `steriqore_test` database** (`setup`, `sync`,
  `run`, `teardown`). Never run the suite with `docker exec steriqore-app ...`:
  that container exports the dev `DB_DATABASE`, the real environment wins over
  `phpunit.xml`, and `RefreshDatabase` would wipe your dev data.
- Known runner baseline (identical before and after the idempotency change, so
  environmental, not code bugs): the `Web/*` UI tests need a Vite build, and a
  few RLS/OpenAPI tests need grants only present in the full CI database.
- `scripts/verify_idempotency_concurrency.py [N]` fires N identical requests with
  one key and counts real database rows (dev stack only). Expected: 1.
- `test/live/queue_lost_response_live_test.dart` runs the real mobile queue
  against the real backend with a lost-answer fault and counts rows. Skipped
  unless `RUN_LIVE_BACKEND_TESTS=true` plus `TEST_ADMIN_EMAIL`,
  `TEST_ADMIN_PASSWORD`, `TEST_ADMIN_TENANT`.
