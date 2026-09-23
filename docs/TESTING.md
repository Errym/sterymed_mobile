# Testing

**Honest inventory, 2026-09-23.** 45 files matching `*_test.dart` exist;
**25 are real** (compile, have a `main()`); **20 are empty stubs** (0
bytes, left over from early scaffolding). CI and the pre-commit hook
both scope to the 25 real ones only — see `docs/CICD.md`.

```bash
# What CI/pre-commit actually run:
find test -name "*_test.dart" -exec grep -l "void main(" {} \;
```

## Real coverage, by directory

| Directory | Real / total | What it covers |
|---|---|---|
| `test/unit/core/` | 7/7 | `ApiException`/`ErrorMapper`, idempotency key generation, `PiiScrubber`, `RoleGuard`, validators |
| `test/unit/repositories/` | 3/3 | `CycleRepository`, `LabelUsageRepository`, `PurchaseRepository` — online/offline-fallback paths |
| `test/unit/storage/` | 3/3 | `OutboxStore`, `SyncEngine` (incl. the 409/422 manual-review paths), `LabelUsageDraftStore` |
| `test/unit/sync/` | 1/1 | `SyncStatusCubit` (flush-on-start/reconnect) |
| `test/bloc/` | 7/18 | Real: alert list, product list debounce, stock level list debounce, dashboard, and a few others. Empty: see below. |
| `test/widget/` | 4/10 | Real: dashboard, label detail, login (structural, not golden — see below), alert list. Empty: see below. |
| `test/unit/features/` | 0/0 | Directory exists, no files — see empty-stub note below (this held prosthetic-specific unit tests). |

Coverage report (`flutter test --coverage`, Day 48): 15.5% overall line
coverage. Low overall, but the highest-risk logic — the offline outbox
and all four fallback repositories — is the part that's actually tested;
most of the uncovered 84% is straightforward passthrough/UI code, not
untested business logic. See `docs/DAILY_LOG.md` for the coverage-gap
investigation that drove this.

## Golden tests → structural tests

The plan called for golden (pixel-diff) tests. None exist — developing
on Windows while CI runs `ubuntu-latest` means a Windows-generated golden
PNG won't byte-match Linux font rendering. Converted to structural
(finder-based: "does this text/icon/widget exist") tests instead for
login, dashboard, and label detail — verifies behavior and layout
presence, not pixel-perfect rendering. Deliberate tradeoff, not a gap.

## Empty test-file stubs (20)

**Prosthetic-related (11)** — the module they'd test was deleted per
ADR-0010. These aren't "missing coverage," they're stubs for code that
no longer exists:

- `test/bloc/prosthetic_case_detail_bloc_test.dart`
- `test/bloc/prosthetic_list_bloc_test.dart`
- `test/bloc/prosthetic_payment_bloc_test.dart`
- `test/bloc/prosthetic_status_bloc_test.dart`
- `test/bloc/waiting_placement_bloc_test.dart`
- `test/unit/features/prosthetic/prosthetic_status_transition_test.dart`
- `test/unit/features/prosthetic/remaining_balance_test.dart`
- `test/unit/features/prosthetic/waiting_placement_filter_test.dart`
- `test/widget/prosthetic_case_detail_test.dart`
- `test/widget/prosthetic_form_test.dart`
- `test/widget/waiting_placement_screen_test.dart`

Candidates for deletion in a cleanup pass (this doc-triage pass was
scoped to docs only, not code/test files — flagging, not doing it here).

**Real gaps for existing features (9)** — the feature is live, the test
just was never written:

- `test/bloc/cycle_list_bloc_test.dart`
- `test/bloc/cycle_transition_bloc_test.dart`
- `test/bloc/goods_receipt_bloc_test.dart`
- `test/bloc/label_detail_bloc_test.dart`
- `test/bloc/label_usage_bloc_test.dart`
- `test/bloc/sync_status_bloc_test.dart`
- `test/widget/cycle_detail_screen_test.dart`
- `test/widget/label_blocked_screen_test.dart`
- `test/widget/sync_status_banner_test.dart`

These are the honest "what's not tested yet" list for anything touching
cycle transitions, goods receipt, and label detail/usage at the bloc
layer, plus two widget screens. Repository-level logic for cycles/goods
receipt is covered (see `test/unit/repositories/`); the bloc layer atop
them isn't.

## Integration tests

`integration_test/` exists with 16 files — `app_test.dart`, a test
driver, 9 journey files named after demo journeys (`auth_journey_test`,
`cycle_lifecycle_journey_test`, `offline_sync_journey_test`,
`conflict_409_journey_test`, `goods_receipt_journey_test`,
`scanner_usage_journey_test`, `stock_issue_journey_test`,
`alert_resolve_journey_test`, plus two prosthetic ones now void per
ADR-0010), and 4 support files (`backend_reset`, `backend_seed`,
`test_data`, `test_user`). **Every single one is 0 bytes.** The names
and structure are right — they map to real demo journeys — but there is
zero integration test coverage today. This is the largest testing gap in
the repo.
