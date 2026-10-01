# Coverage

**Measured snapshot, 2026-10-01**, from a real `flutter test --coverage --no-pub` run
(all 460 tests passing) parsed straight out of `coverage/lcov.info` â€” line
coverage, not a target restated as fact. Regenerate before trusting these
numbers again:

```bash
flutter test --coverage
python scripts/coverage_summary.py   # prints the table below from lcov.info
```

(`scripts/coverage_summary.py` is a small stdlib-only script added with
this doc â€” no new pub dependency, since Flutter/Dart ship no built-in
per-directory lcov summarizer and `lcov`/`genhtml` aren't installed on
this machine.)

## By module

| Module | Lines hit | Lines found | Coverage | Target | Met? |
|---|---:|---:|---:|---:|:---:|
| `lib/core` | 381 | 656 | **58.1%** | 70% | âŒ |
| `lib/features/prosthetic` | 853 | 1685 | **50.6%** | 70% | âŒ |
| `lib/features` (all other features) | 2509 | 9138 | 27.5% | â€” | â€” |
| `lib/shared` | 510 | 592 | 86.1% | â€” | â€” |
| `lib/di` | 1 | 245 | 0.4% | â€” | â€” |
| **Total** | **4254** | **12316** | **34.5%** | â€” | â€” |

These percentages describe the files included in the emitted coverage report;
they do not prove coverage of every source file or end-to-end clinic workflow.
The inventory and historical commentary below predate this measurement. See
[`docs/CLINIC_READY_MASTER_PLAN.md`](../docs/CLINIC_READY_MASTER_PLAN.md) for the
current test inventory, audit findings and ordered completion work.

**Neither `lib/core` nor `lib/features/prosthetic` meets the 70% target.**
Reporting this as met would be fabricated â€” the actual VERIFY step for
this task (`flutter test --coverage` shows >70% on both) does not pass
today. Recording the real number here rather than the target itself is
the point of this file.

### Why `lib/di` is 0.4%

`lib/di/*.dart` is pure `GetIt` registration wiring (`registerLazySingleton`/
`registerFactory` calls) â€” it only executes at real app boot
(`lib/bootstrap.dart`), which no test in `test/` calls. Widget/bloc tests
register their own mocks directly with `GetIt` instead (see any file in
`test/widget/` for the pattern) precisely to avoid needing the real DI
graph. This is expected, not a gap to chase â€” a coverage-driven test of
`features_di.dart` would just be re-asserting "GetIt.registerX was called",
not testing behavior.

### Closing the `lib/core` / `lib/features/prosthetic` gap

Not attempted as part of this task (out of scope: D/E/F only).
The biggest untested surfaces, from `lcov.info`, as of this snapshot:

- `lib/core`: the Dio client/interceptor chain has real coverage
  (`idempotency_interceptor_test.dart`, `error_interceptor_test.dart`,
  `go_router_refresh_stream_test.dart`), but `lib/core/network/dio_client.dart`
  itself, `lib/core/crash/crash_reporter.dart`'s non-PII-scrub paths, and
  most of `lib/core/router/app_router.dart`'s route table are untested â€”
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
| `test/bloc/` | 18 | blocs/cubits â€” see `docs/TESTING.md` for the "phantom bloc" naming note |
| `test/widget/` | 12 | screen-level widget tests |
| `test/golden/` | 4 | new â€” see below |
| `test/helpers/`, `test/mocks/` | â€” | shared `pumpApp`/mock-repository fixtures reused across the above |
| `integration_test/journeys/` | 10 | 2 real (`auth`, `cycle_lifecycle`), 8 still 0-byte stubs â€” see `docs/TESTING.md` |

`docs/TESTING.md` remains the source of truth for the per-bloc/per-widget
breakdown and the `flutter_test` environment gotchas list; this file adds
the coverage numbers and the golden/integration guard notes those don't
cover.

## Golden tests (`test/golden/`, new)

4 screens, matching the brief: `login_screen.png`, `dashboard_screen.png`,
`label_detail_screen.png`, `prosthetic_case_detail_screen.png`. Each test
reuses the exact mock/`GetIt` wiring of that screen's existing
`test/widget/*_test.dart` file (see each golden test's own header comment)
and adds nothing new to what's mocked â€” only a fixed surface size
(`golden_helpers.dart`) and a `matchesGoldenFile` assertion.

**No `golden_toolkit` dependency** (not in `pubspec.yaml`, and this task's
own constraints rule out adding one) â€” plain `matchesGoldenFile` with
committed PNGs instead, per the brief's own fallback instruction.

**Read `docs/TESTING.md`'s "Golden tests â†’ structural tests" section
before trusting these across machines.** That section records a real,
deliberate earlier decision: no golden tests, because a Windows-generated
PNG won't byte-match `mobile-test.yml`'s `ubuntu-latest` runner's font/
anti-aliasing rendering. This task's brief asked for golden tests anyway,
so here they are â€” but that cross-platform risk is real, not resolved by
wishing it away, and `test/golden/goldens/*.png` must be (re)generated on
the same platform that will compare them, not assumed portable:

- If generated on Linux (matching CI) â€” safe to compare in
  `mobile-test.yml` as-is.
- If generated on Windows/macOS and CI runs on `ubuntu-latest` â€” expect a
  first CI run to fail on pixel diffs even though nothing is functionally
  wrong, purely from platform font-rendering differences. Re-run
  `flutter test --update-goldens test/golden/` **on the same OS/container
  CI uses** and recommit the PNGs, rather than treating a red CI run here
  as a real regression.

No `golden_toolkit`/`alchemist` means no built-in perceptual-diff
tolerance either â€” this is a real limitation of the "no new dependency"
constraint, not an oversight.

## Integration tests (`integration_test/`, guard added)

Every journey with real content (`auth_journey_test.dart`,
`cycle_lifecycle_journey_test.dart`) now skips by default via
`integration_test/support/live_backend_guard.dart`
(`kSkipUnlessLiveBackend`, gated on
`--dart-define=RUN_LIVE_INTEGRATION_TESTS=true`), so a bare
`flutter test integration_test/` â€” which newer Flutter/`integration_test`
versions can attempt to run headlessly with no device flag â€” skips
instead of hanging or failing against a backend that may not be running.

**The other 4 named journeys in the brief (scanner+usage, prosthetic
case, waiting placement, offline+sync) are still 0-byte stubs**, same as
before this task. They are not written here: each existing real journey
(`auth`, `cycle_lifecycle`) required live-device iteration to get exact
French button text, timing (SnackBar hold durations, lazy-mount
scrolling), and seeded fixture data right â€” see their header comments and
`docs/DEVICE_TEST_LOG.md`. Writing the remaining 4 blind, without running
them against the live `steriqore` backend on real hardware, would be
fabricated coverage: tests that compile and pass trivially (or never run
at all) rather than tests that prove anything. Flagged here rather than
silently invented.
