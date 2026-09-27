# Coverage

**Honest snapshot, 2026-09-27**, from a real `flutter test --coverage` run
(all 401 tests passing) parsed straight out of `coverage/lcov.info` — line
coverage, not a target restated as fact. Regenerate before trusting these
numbers again:

```bash
flutter test --coverage
python scripts/coverage_summary.py   # prints the table below from lcov.info
```

(`scripts/coverage_summary.py` is a small stdlib-only script added with
this doc — no new pub dependency, since Flutter/Dart ship no built-in
per-directory lcov summarizer and `lcov`/`genhtml` aren't installed on
this machine.)

## By module

| Module | Lines hit | Lines found | Coverage | Target | Met? |
|---|---:|---:|---:|---:|:---:|
| `lib/core` | 289 | 533 | **54.2%** | 70% | ❌ |
| `lib/features/prosthetic` | 704 | 1522 | **46.3%** | 70% | ❌ |
| `lib/features` (all other features) | 1957 | 8968 | 21.8% | — | — |
| `lib/shared` | 395 | 473 | 83.5% | — | — |
| `lib/di` | 1 | 241 | 0.4% | — | — |
| **Total** | **3346** | **11737** | **28.5%** | — | — |

**Neither `lib/core` nor `lib/features/prosthetic` meets the 70% target.**
Reporting this as met would be fabricated — the actual VERIFY step for
this task (`flutter test --coverage` shows >70% on both) does not pass
today. Recording the real number here rather than the target itself is
the point of this file.

### Why `lib/di` is 0.4%

`lib/di/*.dart` is pure `GetIt` registration wiring (`registerLazySingleton`/
`registerFactory` calls) — it only executes at real app boot
(`lib/bootstrap.dart`), which no test in `test/` calls. Widget/bloc tests
register their own mocks directly with `GetIt` instead (see any file in
`test/widget/` for the pattern) precisely to avoid needing the real DI
graph. This is expected, not a gap to chase — a coverage-driven test of
`features_di.dart` would just be re-asserting "GetIt.registerX was called",
not testing behavior.

### Closing the `lib/core` / `lib/features/prosthetic` gap

Not attempted as part of this task (out of scope: D/E/F only — see this
file's own history in `docs/DAILY_LOG.md` for what this task covered).
The biggest untested surfaces, from `lcov.info`, as of this snapshot:

- `lib/core`: the Dio client/interceptor chain has real coverage
  (`idempotency_interceptor_test.dart`, `error_interceptor_test.dart`,
  `go_router_refresh_stream_test.dart`), but `lib/core/network/dio_client.dart`
  itself, `lib/core/crash/crash_reporter.dart`'s non-PII-scrub paths, and
  most of `lib/core/router/app_router.dart`'s route table are untested —
  they're mostly wiring, but a router-guard regression there wouldn't be
  caught today.
- `lib/features/prosthetic`: `prosthetic_repository.dart`'s cache paths
  are covered indirectly through bloc/screen tests, but the laboratory
  CRUD screens and the attachments flow have thinner direct coverage than
  the case list/detail/payment paths.

## Test inventory

| Directory | Files | Notes |
|---|---:|---|
| `test/unit/` | see `docs/TESTING.md` | unit-level: exceptions, interceptors, storage, contract snapshot |
| `test/bloc/` | 18 | blocs/cubits — see `docs/TESTING.md` for the "phantom bloc" naming note |
| `test/widget/` | 12 | screen-level widget tests |
| `test/golden/` | 4 | new — see below |
| `test/helpers/`, `test/mocks/` | — | shared `pumpApp`/mock-repository fixtures reused across the above |
| `integration_test/journeys/` | 10 | 2 real (`auth`, `cycle_lifecycle`), 8 still 0-byte stubs — see `docs/TESTING.md` |

`docs/TESTING.md` remains the source of truth for the per-bloc/per-widget
breakdown and the `flutter_test` environment gotchas list; this file adds
the coverage numbers and the golden/integration guard notes those don't
cover.

## Golden tests (`test/golden/`, new)

4 screens, matching the brief: `login_screen.png`, `dashboard_screen.png`,
`label_detail_screen.png`, `prosthetic_case_detail_screen.png`. Each test
reuses the exact mock/`GetIt` wiring of that screen's existing
`test/widget/*_test.dart` file (see each golden test's own header comment)
and adds nothing new to what's mocked — only a fixed surface size
(`golden_helpers.dart`) and a `matchesGoldenFile` assertion.

**No `golden_toolkit` dependency** (not in `pubspec.yaml`, and this task's
own constraints rule out adding one) — plain `matchesGoldenFile` with
committed PNGs instead, per the brief's own fallback instruction.

**Read `docs/TESTING.md`'s "Golden tests → structural tests" section
before trusting these across machines.** That section records a real,
deliberate earlier decision: no golden tests, because a Windows-generated
PNG won't byte-match `mobile-test.yml`'s `ubuntu-latest` runner's font/
anti-aliasing rendering. This task's brief asked for golden tests anyway,
so here they are — but that cross-platform risk is real, not resolved by
wishing it away, and `test/golden/goldens/*.png` must be (re)generated on
the same platform that will compare them, not assumed portable:

- If generated on Linux (matching CI) — safe to compare in
  `mobile-test.yml` as-is.
- If generated on Windows/macOS and CI runs on `ubuntu-latest` — expect a
  first CI run to fail on pixel diffs even though nothing is functionally
  wrong, purely from platform font-rendering differences. Re-run
  `flutter test --update-goldens test/golden/` **on the same OS/container
  CI uses** and recommit the PNGs, rather than treating a red CI run here
  as a real regression.

No `golden_toolkit`/`alchemist` means no built-in perceptual-diff
tolerance either — this is a real limitation of the "no new dependency"
constraint, not an oversight.

## Integration tests (`integration_test/`, guard added)

Every journey with real content (`auth_journey_test.dart`,
`cycle_lifecycle_journey_test.dart`) now skips by default via
`integration_test/support/live_backend_guard.dart`
(`kSkipUnlessLiveBackend`, gated on
`--dart-define=RUN_LIVE_INTEGRATION_TESTS=true`), so a bare
`flutter test integration_test/` — which newer Flutter/`integration_test`
versions can attempt to run headlessly with no device flag — skips
instead of hanging or failing against a backend that may not be running.

**The other 4 named journeys in the brief (scanner+usage, prosthetic
case, waiting placement, offline+sync) are still 0-byte stubs**, same as
before this task. They are not written here: each existing real journey
(`auth`, `cycle_lifecycle`) required live-device iteration to get exact
French button text, timing (SnackBar hold durations, lazy-mount
scrolling), and seeded fixture data right — see their header comments and
`docs/DEVICE_TEST_LOG.md`. Writing the remaining 4 blind, without running
them against the live `steriqore` backend on real hardware, would be
fabricated coverage: tests that compile and pass trivially (or never run
at all) rather than tests that prove anything. Flagged here rather than
silently invented.
