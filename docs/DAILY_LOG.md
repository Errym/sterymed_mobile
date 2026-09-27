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

---

### 2026-09-23 — Gate 5 Audit (Phase 5 — Usage + offline)

Every item checked against an actual artifact (test file, this log's own
prior entries, or a direct code read done *during* this audit — marked
as such, since that's weaker evidence than a pre-existing test and is
called out explicitly rather than folded into "verified"). No item is
marked ✅ without something to point to.

**1. Offline usage queues and survives app kill — 🟡 PARTIAL**
- Queuing: ✅ `test/unit/repositories/label_usage_repository_test.dart`
  — "being offline enqueues directly without calling the remote
  datasource" (passing).
- Persistence mechanism: ✅ `test/unit/storage/outbox_store_test.dart`
  uses a real (non-mocked) Hive box — enqueue/read round-trips through
  actual on-disk storage, not an in-memory fake.
- Actual app-kill-and-relaunch on a device: ⏳ **NEEDS USER** — no entry
  in `docs/DEVICE_TEST_LOG.md` (empty).

**2. Sync on reconnect verified server-side — 🟡 PARTIAL**
- Reconnect-triggers-flush: ✅ `test/unit/sync/sync_status_cubit_test.dart`
  (3 passing tests: offline start doesn't flush, online start flushes
  before `start()` returns, offline→online transition flushes).
- "Verified server-side" — the synced data actually landing correctly in
  the backend: ❌ no evidence. `integration_test/` has 16 files, all 0
  bytes (see `docs/TESTING.md`); no manual verification logged anywhere
  in this file.

**3. 409 conflict proven with evidence — ✅ VERIFIED**
- This log's own 2026-09-22 entries: read the live backend's
  `EnsureIdempotency` middleware source directly, then confirmed live
  against `POST /v1/auth/login` — same key + same body → 200 replay;
  same key + different body → real 409 `IDEMPOTENCY_KEY_REUSED`. Backed
  by `test/unit/storage/sync_engine_test.dart`'s passing 409 test
  (manual-review path, not auto-discard). Strongest-evidenced item in
  either gate — verified against real backend behavior, not assumed.

**4. Double-tap impossible — 🟡 PARTIAL**
- Code read (this audit, not a pre-existing check):
  `label_usage_form_screen.dart` sets `_submitting = true` via
  synchronous `setState()` before the first `await` in `_submit()`;
  `PrimaryButton` (`lib/shared/widgets/buttons/primary_button.dart`)
  computes `enabled = onPressed != null && !isLoading` and passes `null`
  to the underlying `ElevatedButton` when loading. This is the standard,
  architecturally-sound Flutter double-tap guard.
- No automated test simulates a rapid double-tap on this screen (no
  `label_usage_form_screen_test.dart` exists). No device verification.
  "Impossible" as an absolute claim isn't formally proven, just
  architecturally supported.

**5. Form state never lost — 🟡 PARTIAL**
- ✅ `LabelUsageDraftStore` exists and is unit-tested
  (`test/unit/storage/label_usage_draft_store_test.dart`, 10 passing
  tests: round-trip, corrupt-JSON handling, per-label isolation,
  clear-on-submit-success).
- This is the only form in Gate 5's scope (label usage), and it's the
  only form in the whole app with this protection — correct scope, not
  a partial implementation of a wider claim.
- Actual "kill app mid-fill, relaunch, see it restored" on a device: ⏳
  **NEEDS USER** — not run.

**6. Web shows same usage record after mobile sync (coherence check #2)
— ⏳ NEEDS USER**
- No evidence at all. Requires a live dual-client check (submit on
  mobile, confirm on web) or an integration test — neither exists.

**7. Usage tests green — 🟡 PARTIAL**
- Repository + draft-store level: ✅ green
  (`label_usage_repository_test.dart` — 4 tests,
  `label_usage_draft_store_test.dart` — 10 tests, all passing).
- Bloc level: `test/bloc/label_usage_bloc_test.dart` is an empty stub —
  zero automated coverage of usage-bloc event/state handling.

---

### 2026-09-23 — Gate 6 Audit (Phase 6 — Sterilization cycles)

Same standard as Gate 5 above — no ✅ without a citable artifact.

**1. Full lifecycle e2e on device — ⏳ NEEDS USER**
- No device test log entry.
  `integration_test/journeys/cycle_lifecycle_journey_test.dart` exists
  by name only — 0 bytes.

**2. Rejected release requires reason — 🟡 PARTIAL**
- Code read (this audit): `release_decision_sheet.dart` —
  `requiresReason = _decision == 'rejected'`,
  `canSubmit = !requiresReason || _reasonCtrl.text.trim().isNotEmpty`.
  Client-side enforcement is real and correct as of this read.
- No automated test exists for this file (checked: no
  `release_decision_sheet_test.dart` anywhere in `test/`).
- Server-side enforcement (the plan specifies "UI + server") not
  independently verified from this repo — would require checking
  `steriqore`'s release controller/request validation, out of scope for
  a mobile-repo audit.

**3. Attachments visible on web (coherence check #3) — ❌ NOT DONE**
- Cannot be attempted: the entire attachments feature is disabled
  client-side pending `docs/BACKEND_BUGS.md#BUG-001`
  (`POST /cycles/{cycle}/attachments` returns 500). Nothing can be
  uploaded to check web visibility. Blocked upstream in `steriqore`, not
  a mobile-repo task.

**4. Offline transitions sync correctly — 🟡 PARTIAL**
- Client-side queue + flush: ✅
  `test/unit/repositories/cycle_repository_test.dart` (7 passing tests:
  `start()` online success / network-fallback / offline-from-start /
  non-network-rethrow; `release()` online success / offline-fallback),
  plus `sync_engine_test.dart` for the flush mechanism itself.
- End-to-end confirmation the transition actually applies correctly
  server-side after sync: ❌ no evidence — same gap as Gate 5 item 2.

**5. Cycle tests green — 🟡 PARTIAL**
- Repository level: ✅ green (`cycle_repository_test.dart`, 7/7 passing).
- Bloc level: `test/bloc/cycle_list_bloc_test.dart` and
  `test/bloc/cycle_transition_bloc_test.dart` are both empty stubs —
  zero bloc coverage.
- Widget level: `test/widget/cycle_detail_screen_test.dart` is an empty
  stub too.

---

### What you personally must do before either gate can close

1. **Device test — app kill survival.** Kill the app mid-form-fill on
   the label usage screen, and separately mid-outbox-queue (submit
   offline, force-kill before it would sync), relaunch both times,
   confirm the draft/queued item is still there. (Gate 5 #1, #5)
2. **Dual-client check.** Submit a label usage on mobile, confirm the
   same record appears correctly on the web app. This is the literal
   "coherence check #2" — nothing else can substitute for it. (Gate 5 #6)
3. **Server-side sync confirmation.** After an offline-queued item
   syncs, confirm the resulting record in the backend is correct and
   complete — not just that the client's POST returned success. (Gate 5
   #2, Gate 6 #4)
4. **Full device run-through of the cycle lifecycle** — create → start
   → complete → submit-for-release → release — on a real phone. (Gate 6
   #1)
5. **Attachments — blocked, not actionable yet.** Nothing to test until
   `steriqore`'s BUG-001 fix lands (another session has uncommitted work
   on this). Re-test once that ships. (Gate 6 #3)
6. **Optional, closes an "impossible" claim properly**: rapid-tap the
   usage submit button on a real touchscreen device and confirm no
   duplicate records land server-side. The code is architecturally
   sound for this; a device confirmation would make it a clean ✅ instead
   of an inferred one. (Gate 5 #4)

Neither gate has a single item that's cleanly ❌-blocked-on-more-code —
everything marked 🟡 or ⏳ is blocked on the six items above, not on

---

### 2026-09-24 — Gate 6 item 1 closed: real device run, full lifecycle

`integration_test/journeys/cycle_lifecycle_journey_test.dart` was the
0-byte stub flagged in the 2026-09-23 audit above. Written and run for
real on a physical Android device (Samsung S928B, USB-tethered to a
local `steriqore` backend via `adb reverse`) against the demo2 tenant.

**Result: all green.** `create → start → complete → submit-for-release →
release(compliant)` — every transition confirmed via the real backend's
own response body, not just a client-side state change:

```
POST /cycles                     → 201 status: draft
POST /cycles/{id}/items          → 201 (instrument added — required, see below)
POST /cycles/{id}/start          → 201 status: running
POST /cycles/{id}/complete       → 201 status: completed
POST /cycles/{id}/submit-for-release → 201 status: awaiting_release
POST /cycles/{id}/release        → 201 decision: compliant
GET  /cycles/{id}                → 200 status: released
```

**Two real bugs found and fixed by this run, not by inspection:**

1. **`CycleData` never normalized `running` → `in_progress`.** The
   backend's `CycleStatus` enum (confirmed by reading
   `App\Domain\Sterilization\Enums\CycleStatus` directly in the
   `steriqore-app` container) is `draft, running, completed,
   awaiting_release, released, rejected`. `cycle_data.dart` already had
   a `draft → created` normalization (comment: "Status: normalize
   draft→created") but nothing for `running`. Every started cycle was
   permanently stuck: `cycle_detail_screen.dart`'s action-button switch
   only matches `'in_progress'`, so after a real `start()` the button
   silently disappeared (fell to `default: SizedBox.shrink()`) instead
   of becoming "Marquer comme terminé". The same mismatch made the
   cycle list's "En cours" filter chip (`cycle_list_screen.dart`) compare
   against `'in_progress'` client-side and always match zero cycles, since
   every list item's real status was `'running'`. Fixed by extending the
   existing normalization block in `cycle_data.dart`. One-line class of
   bug, full-lifecycle-blocking impact — undetected until a real device
   actually ran `start()`, because the integration test that would have
   caught it didn't exist until today.
2. **The journey itself was missing a required step.** `POST
   /cycles/{id}/start` was rejected server-side ("At least one item must
   be in the load before starting the cycle." —
   `StartCycleAction.php:26`) because "Initialiser & Charger les
   Sachets" on the create screen only creates the cycle shell with zero
   items; instruments are added separately via the "+" icon in the
   detail screen's Instruments section (`ItemEditorDialog`). Added that
   step to the test. Not an app bug — the app correctly enforced a real
   backend rule the test had been skipping.

**Test-infrastructure notes** (for whoever runs this test next):
- `cycle_detail_screen.dart`'s body is a plain `ListView`, which still
  lazily mounts elements outside the viewport via sliver machinery —
  `find.text(...)` can return 0 results for a widget that's rendering
  correctly just off-screen. Every button/text check below the first
  screenful needs `tester.scrollUntilVisible(...)`, not a bare `find`.
- Every transition shows an "Cycle mis à jour." SnackBar directly over
  the action button for ~4s with no associated animation once its enter
  transition finishes — `pumpAndSettle()` returns while it's still fully
  opaque (nothing is scheduling new frames), so the next tap lands on
  the SnackBar and silently no-ops. Needs an explicit
  `pump(Duration(seconds: 4))`, not `pumpAndSettle()`.
- `adb reverse tcp:8010 tcp:8010` does not survive every rebuild/reinstall
  cycle on this device — re-assert it before each `flutter test` run
  against USB, or route over LAN instead (blocked here: Windows Firewall
  has no inbound rule for the backend port from other LAN devices, and
  opening one needs the user's own approval).
- Keep the device's screen-off timeout well above the test's real-world
  wall-clock duration (`adb shell settings put system
  screen_off_timeout 1800000`) — a locked/dimmed screen stops touch
  input from registering mid-test with no clear error, just silent
  "did not complete".

---

### 2026-09-24 — Gate 8 partial audit (Stock + Purchases + Audit + Settings)

Same standard as Gate 5/6 above. In progress — covers what was checked
today; not yet a full close-out.

**1. Stock adjust blocks empty reason — ✅ CONFIRMED, client + server**
- Client: `stock_adjust_screen.dart` — `AppTextArea` validator rejects
  empty/whitespace, gates `_submit()` via `_formKey.currentState!.validate()`.
- Server: live `POST /v1/stock-movements/adjust` with no `reason` field
  against the running `steriqore` instance → `422 VALIDATION_FAILED`,
  `{"reason":["The reason field is required."]}`.

**2. Partial goods reception — ✅ CONFIRMED, client**
- `goods_receipt_screen.dart` defaults each line's qty field to
  `l.qtyRemaining` (not `qtyOrdered`) and filters `.where((m) =>
  (m['qty'] as int) > 0)` before submit — a line can be zeroed or reduced
  and only non-zero lines post. This is real partial-reception support.

**3. Purchase order `canReceive` — 🐛 FOUND + FIXED**
- `purchase_order_data.dart` checked `status == 'partial'`. The real
  backend enum (`App\Domain\Purchasing\Enums\PurchaseOrderStatus`,
  read directly from the `steriqore-app` container) uses
  `'partially_received'`. A second or third partial receipt on an
  already-partially-received PO was silently impossible — `canReceive`
  always evaluated false past the first receipt. Fixed.

**4. Purchase order status badges — 🐛 FOUND + FIXED**
- Both `purchase_order_list_screen.dart` and
  `purchase_order_detail_screen.dart` had the same `'partial'` typo in
  their `_statusLabel`/`_statusTone` switches (falling to the raw string
  / a wrong default tone), and neither handled `'closed'` at all. Fixed
  both files to match the real 6-value enum: `draft, ordered,
  partially_received, received, closed, cancelled`.

**5. Goods receipt photo evidence / expiry_date / discrepancy_reason —
❌ NOT DONE, two different reasons**
- `expiry_date` and `discrepancy_reason`: real backend fields
  (`ReceiveGoodsRequest.php`, both `nullable`), but the mobile form
  doesn't collect either. Mobile-side gap, not backend-blocked — the
  master plan (Phase 8, Day 42) calls for both.
- Photo evidence: `php artisan route:list --path=purchase-orders` on
  the live backend shows no receipt-attachment route at all. Same class
  of block as `BACKEND_BUGS.md#BUG-001` (cycle attachments returning
  500), just not yet filed as its own entry there.

**6. Audit filters — 🟡 PARTIAL**
- Plan (Day 43) calls for filtering by actor, action, subject, and date.
  `audit_list_screen.dart` only filters by `action`, via 5 hardcoded
  `FilterChipOption`s — no actor/subject/date filter exists.
- "Filter persistence while drilling in": `_AuditTile` has no `onTap` —
  there's no detail screen to drill into, so this requirement is moot
  as currently scoped, not failing.

**7. Settings — ✅ CONFIRMED**
- One screen (`settings_screen.dart`), matches the plan's four sections
  (Mon compte / Session / Application / Support) almost exactly, no
  separate profile or tenant screens exist. Closest documented gap: the
  plan's "Support — contact link" is folded into a single "À propos"
  link rather than a separate direct contact link.

**Not yet touched:** stock issue/transfer online+offline behavior,
device-measured performance targets, security audit, backup/restore
drill, full web+mobile coherence sweep — all still open for Gate 8/9.

### 2026-09-24 — Audit filters built (Day 43 gap closed) + a "clear filter" bug fixed

Backend confirms real support (`AuditEventController.php`,
`ListAuditEventsRequest.php`, live curl): `filter[actor_id]` (uuid),
`filter[subject_type]` (full FQCN string, e.g.
`App\Domain\Purchasing\Models\Supplier`), `filter[from]`/`filter[to]`
(date range). Threaded all four through
`AuditRemoteDatasource.list()` → `AuditRepository.list()` →
`AuditListBloc`, verified live: actor_id, subject_type, and an
ISO-8601 date range all correctly narrow the result set.

No `GET /members` exists to build a proper "pick a person" dropdown
(see BUG-011), and there's no subject-type enum endpoint either — so
both pickers derive their options from actors/subject types the trail
has actually shown this session (`AuditListState.seenActors` /
`seenSubjectTypes`, accumulated across loads so applying one filter
doesn't shrink the options for the next). New
`AuditFilterSheet` bottom sheet (actor dropdown, subject-type dropdown,
from/to date pickers, reset). Also added `subjectTypeLabel` to
`AuditEventData` mapping the 6 real FQCN values seen live to French
labels ("Cycle", "Fournisseur", etc.) — the tile was previously
rendering the raw PHP class string straight to the user.

**Found + fixed a real, live bug while touching this:** selecting
"Tous" in the existing action-type `FilterChipRow` never actually
cleared the filter. `AuditListState.copyWith(actionFilter: null)`
fell through to `actionFilter ?? this.actionFilter`, so `null` was
indistinguishable from "not provided" and the old filter stuck. Fixed
by having `_onFilter` pass `clearActionFilter: event.action == null`
explicitly, and gave the three new filter fields the same explicit
clear-flag treatment from the start.

`flutter analyze` — No issues found. Not yet verified on-device
(would need the phone reconnected); logic verified against the live
backend by curl instead, consistent with this session's standard where
a device pass isn't immediately available.

---

### 2026-09-24 — Prosthetic module reappeared mid-session, removed again

While auditing the rest of the app (suppliers CRUD gap, product form
fields, "Lots" dead route — all fixed this session, see the CRUD-
completeness entries above), the harness flagged that several files I'd
already edited today (`app_router.dart`, `api_endpoints.dart`,
`role_guard.dart`, `features_di.dart`) had changed on disk since I last
touched them. The diff: a full `lib/features/prosthetic/` tree (60
files) plus prosthetic routes/permissions/endpoints had been added back
— along with two shell scripts in the repo root, `build_phase7.sh.orig`
(182KB) and `fix_phase7_final_2.sh`, both timestamped the same evening.
Neither script was run by this session.

`build_phase7.sh.orig`'s own header names its sources of truth as the
Cahier des charges and `pjdocs/SteryMed_Prosthetic_Workflow_
Implementation_Brief_EN-compressed.pdf` — a standalone planning PDF, not
the Cahier des charges (which has no prosthetic content at all, confirmed
by reading the whole thing earlier this session). Re-ran the exact check
`docs/adr/0010-prosthetic-deferred.md` ran in September:
`php artisan route:list --path=api/v1 | grep -i prosthetic` and
`app/Domain` listing, live against the running `steriqore-app` container.
Same result as ADR 0010 — zero prosthetic routes, zero prosthetic domain.

Flagged to the user before touching anything (this was not requested and
directly contradicted both ADR 0010 and the user's own earlier "ignore
that doc" call on a related planning file this session). User confirmed:
remove it again.

**Removed:**
- `lib/features/prosthetic/` (60 files, untracked — deleted outright)
- `build_phase7.sh.orig`, `fix_phase7_final_2.sh` (untracked — deleted)
- `lib/core/router/routes.dart`, `route_names.dart`,
  `lib/core/storage/outbox/outbox_operation.dart` — purely-additive diffs
  I hadn't touched, restored via `git checkout`
- 5 previously-empty prosthetic test stubs that had been filled in
  (`test/bloc/prosthetic_list_bloc_test.dart`,
  `test/bloc/prosthetic_status_bloc_test.dart`,
  `test/fixtures/prosthetic_case_fixture.dart`,
  `test/unit/features/prosthetic/remaining_balance_test.dart`,
  `test/unit/features/prosthetic/waiting_placement_filter_test.dart`) —
  restored via `git checkout` to their committed (empty) state
- Prosthetic-only hunks surgically removed (not blind-reverted, since
  this session's own legitimate edits shared the same 4 files) from
  `app_router.dart`, `api_endpoints.dart`, `role_guard.dart`,
  `features_di.dart` — verified via `git diff` per file before editing,
  then `grep -rl prosthetic lib/` confirmed zero references remain,
  then `flutter analyze` re-run clean

No root cause identified — most likely a separate concurrent session
(another terminal or agent) treating the workflow-brief PDF as
authoritative without checking ADR 0010 or the live backend first. If
this happens again, same procedure: re-verify against the live backend
before assuming it's intentional, surgically remove from any file this
session has also legitimately touched rather than blind `git checkout`.

### 2026-09-24 — Full-check: two fabricated screens found, one fixed, one flagged

Continuing the "full check for the whole app" pass before Phase 8/9/10.

**`data_export_request_screen.dart` — was 100% fake, now real:**
Original file was a static `StatelessWidget` with two hardcoded
`_ExportCard`s (invented reference numbers, invented requester names, a
fabricated "Disponible" status) and two `onPressed: () {}` no-ops. It
never imported `ExportRepository`, which already existed and was already
correct. Rewrote as a `StatefulWidget` wired to the real repository
(`list`/`request`/`downloadUrl`), with a real request button, refresh,
and per-card download action (copies the link to clipboard — chose this
over adding `url_launcher` as an unapproved new dependency).

While wiring it, found the underlying `ExportRequestData` model
(pre-existing, not written this session) didn't match the real backend
DTO at all: expected a `reference` field that doesn't exist, checked for
status `'available'` when the real enum value is `'completed'`, and
expected `download_url` on the list/show response when the backend
explicitly never puts it there (`DataExportRequestData.php` comment:
"UI-29 removed download_url: ... only minted on demand"). Rewrote the
model to the real shape and verified every field name against a live
round-trip: `POST /v1/data-export-requests` → `GET
/v1/data-export-requests` → `POST .../{id}/download`, using a fresh
`POST /v1/auth/login` token against `demo2`/`admin2@steriqore.local`.
Live response confirmed exactly: `id, status, requested_by_name,
requested_at, error, completed_at, size_bytes, record_count, file_count,
table_manifest, expires_at` — model now matches field-for-field.

**Found in that same live check: BUG-010.** The download action's
presigned URL is minted from the Docker-internal `minio:9000` hostname,
not a publicly-reachable address — the `backups` filesystem disk has no
`url` override (unlike the sibling `s3` disk, which correctly points at
`http://localhost:9023`). The mobile "copy download link" button is
correctly built and correctly wired, but the link itself can never be
opened by a real device. Logged as `docs/BACKEND_BUGS.md#BUG-010`,
severity 🔴 since it fully blocks the feature end-to-end, but it's a
one-line backend config fix, not a mobile-side problem.

`flutter analyze lib/features/reporting` — No issues found.

**`team_detail_screen.dart` — found fake, deleted.** Hardcoded fake
person (`'Dr. Julien Dupont'`, invented email/phone/station),
English-language app bar title, a fake role dropdown not matching the
real permission model, fabricated "Account Created"/"Last Session"
metadata, and a no-op save button. Confirmed via grep that
`team_list_screen.dart` had no `onTap` into it — unreachable from the UI
even though the route was registered. Re-checked live:
`php artisan route:list --path=api/v1 | grep -i member` shows only
`DELETE /v1/members/{tenantUser}` (plus separate `POST/DELETE
/v1/invitations`) — no `PATCH` anywhere, so there is no honest way to
rebuild "edit member profile/role." Deleted the screen file, its
`GoRoute` and import in `app_router.dart`, and the unused
`Routes.teamDetail()` helper in `routes.dart` rather than leave
fake/dead code in the app. `flutter analyze` — No issues found.

**Swept for other fabrication patterns** (no-op button handlers,
hardcoded `TextEditingController(text: '<Name>')`, leftover English UI
strings): all clean. The one grep hit on a name-like string
(`register_form.dart:95`, `cycle_detail_screen.dart:828`,
`cycle_create_screen.dart:243` — all "Dr. ... Dupont/Watson") are hint
text showing the expected input format, not fabricated data — legitimate.

**Full `flutter test` triage:** 139 passing, 20 failing to *load*
(`Error: Undefined name 'main'`). Checked every one — all 20 are 0-byte
files (`test/bloc/cycle_list_bloc_test.dart`,
`cycle_transition_bloc_test.dart`, `goods_receipt_bloc_test.dart`,
`label_detail_bloc_test.dart`, `label_usage_bloc_test.dart`,
`sync_status_bloc_test.dart`, `waiting_placement_bloc_test.dart`,
`widget/cycle_detail_screen_test.dart`,
`widget/label_blocked_screen_test.dart`, `widget/sync_status_banner_test.dart`,
`widget/waiting_placement_screen_test.dart`, and 9 prosthetic-named
files). `git log -- <file>` confirms every one was already empty in
`e8a6a9a` (the repo's very first commit) — pre-existing, not something
this session broke or introduced. Not fixed here (writing ~9 real bloc
tests + 4 widget tests is its own scoped task, not part of "full check");
flagging as a QA-gate gap for Phase 9.

### 2026-09-24 — Root cause found + fixed: the practitioner role was never actually broken, invitation-accept was

User raised a real concern from a separate diagnostic write-up: the
pilot's only non-owner account (`staff2@steriqore.local`) logs in with
`role: null` and gets 403 on everything. Rather than accept "permissions
aren't seeded" as the explanation, tested the real product path
end-to-end: `POST /v1/invitations` (create) → `POST
/v1/invitations/accept` (the only way a real user ever gets a role).

**Every single accept crashed with a 500** (`SQLSTATE[22P02]: invalid
input syntax for type uuid: ""`). Traced the full stack trace in
`storage/logs/laravel.log`: the write half
(`AcceptInvitationAction` — create user, create `tenant_user`,
`syncRoles()`) genuinely succeeds inside `TenantContext::run()`, which
binds the Postgres session GUC `app.tenant_id` that `model_has_roles`'s
RLS policy casts to `uuid`. But `AcceptInvitationController` then builds
the JSON response with `UserData::fromModel($user)` **after** that block
has already exited and reset the GUC — `getRoleNames()` inside
`fromModel()` hits the RLS cast against an empty string and Postgres
throws. `UserData`'s own docblock literally documents this exact trap;
`LoginController` handles it correctly (wraps in `TenantContext::run()`
a second time), `AcceptInvitationController` just never did.

This is why `staff2` has no role: the real invite flow has apparently
never worked, so every non-owner account so far was hand-inserted via
`tinker` — bypassing `assignRole()` entirely.

**Fixed** in the `steriqore` backend repo
(`app/Http/Controllers/Api/V1/Identity/AcceptInvitationController.php`,
host path `C:\Users\mery\steriqore\...` — a separate repo from this one,
edited directly since the fix was small, precisely diagnosed, and the
running container was available to verify against). Wrapped the
response-building call in `TenantContext::run()`, identical to
`LoginController`'s pattern. Hot-patched into the running container
(`docker cp` + `php artisan octane:reload` — this backend runs on
Octane/FrankenPHP, which keeps the app booted in memory across requests,
so editing the file on disk alone does nothing until the workers
reload — first verification attempt still failed with the exact same
error until this was realized).

**Verified live, end to end:** created a fresh invitation, accepted it →
`200`, real token, `"role":"practitioner"`, real permission list. That
new user then correctly got `200` on `GET /v1/cycles` and `403` on
`GET /v1/audit-events` — permission-scoped exactly as the six-role model
intends, not over- or under-permissive. Also fixed the existing
`staff2` account directly (assigned `practitioner` via `syncRoles()`,
same effect the fixed flow now produces) and disabled (not deleted —
`audit_events` is append-only and correctly blocks any hard delete that
would null out `actor_id`) three throwaway test accounts created while
diagnosing this.

Full writeup with the exact repro and stack trace:
`docs/BACKEND_BUGS.md#BUG-012`.

**Still open:** this hot-patch only lives in the currently-running
container — the host `steriqore` repo has the source fix, but it needs a
real image rebuild/redeploy to persist past a container restart.
Role-aware mobile navigation (hiding nav items a role has no permission
for) is separate, not-yet-done mobile work — this fix makes the backend
correctly return/enforce roles, it doesn't change what the mobile app's
bottom nav shows.

### 2026-09-24 — Dashboard's quick-access menu wasn't actually role-aware, despite the bottom nav being fixed already

Checked whether `bottom_nav_bar.dart`'s existing `RoleGuard`-based
filtering (real per-permission checks, already correct) extended to the
*other* place users navigate from — the dashboard's "Centre de
gouvernance" / "Accès rapides" tile grid (`dashboard_screen.dart`,
`_GovernanceMenu`), since that's the actual primary way to reach
Team/Sites/Devices/Suppliers/Audit/etc. It didn't: "Opérations",
"Catalogue & Achats", and "Clinique & Conformité" groups were shown
unconditionally to every role, and "Administration" was gated on a
single `isOwner` boolean instead of real permissions.

Cross-checked against `staff2`'s (practitioner) actual permission list
(`sites.view, products.view, suppliers.view, purchasing.view,
inventory.view, alerts.view, devices.view, cycles.view, labels.view,
patients.view, patients.manage, usages.view, usages.manage,
non_conformities.view`) and found the `isOwner` gate was wrong in both
directions:
- **Under-exposed:** practitioner genuinely has `sites.view` and
  `devices.view` per the real backend grants, but "Sites & Espaces" and
  "Appareils & Programmes" were hidden from every non-owner regardless.
  Same for "Équipe & Droits" (`Routes.team` isn't permission-gated at
  all server-side — only invite/disable actions are — so the router
  already allows any authenticated user there; the tile alone hid it).
- **Over-exposed:** "Export Données" was shown to everyone including
  roles with no `data_exports.manage`, and "Journal d'Audit" was shown
  to everyone despite most roles lacking `audit.view` — tapping either
  would just get silently bounced back out by the router's existing
  `RoleGuard` redirect, a confusing dead-end tap.

**Fix:** replaced the `isOwner` parameter and conditionals with the
exact same `RoleGuard.isAllowed(route, hasPermission)` check
`bottom_nav_bar.dart` already uses — every tile in every group is now
filtered against the real permission map, not a coarse owner/non-owner
split. `Routes.team` has no entry in `RoleGuard` by design, so it's
always shown (matching the router's own stance) rather than
special-cased. `flutter analyze` — No issues found.

Not yet verified on-device (phone not connected this session) — checked
by hand-tracing `staff2`'s real permission list against `RoleGuard`'s
map for every tile instead.

### 2026-09-25 — Day 45 coherence sweep: logged into the actual web app, found + built the fix for BUG-011

User asked to continue into the master plan's Day 45 "full web + mobile
coherence sweep." Rather than compare source code across repos, logged
into the real web app (`http://localhost:8010/login`, owner account) via
browser automation to compare actual screens against the mobile app —
this surfaced a working web `/team` page (full member table: name,
email, role, status, joined date) where mobile's equivalent has been
dead all along (BUG-011). `Web\Identity\TeamController@index`'s own
docblock confirms this was a known, deliberate API gap ("the API only
ever had store/destroy, no index"), not new.

**Built the missing endpoint** rather than just documenting it, same
call as BUG-012: added `MemberController@index` (`GET /v1/members`) to
the `steriqore` backend, mirroring the web controller's exact
query/DTO, gated on the same `invitations.create` permission. Hit one
unrelated snag along the way — copying the edited `routes/api.php` into
the container broke the whole app with a PHP syntax error; turned out
the host repo already had a stray, uncommitted, half-finished line
(`Route::post('cycles/{cycle}/attachments-base64', ...)` pointing at a
`storeBase64` method that doesn't exist on `CycleAttachmentController`)
dropped mid-statement into an unrelated route registration — pre-existing
debris, not something introduced this session. Removed just that one
broken line (confirmed the method genuinely doesn't exist first), kept
the real fix, verified `php -l` before redeploying, and confirmed the
app fully recovered (`/up` and `/v1/me` both `200` again) before moving
on. Verified the new endpoint live: `200` with real data for the owner,
`403` for a `practitioner` (correctly scoped, matches the web gate).

**Mobile-side fixes this required** — the Dart layer had been written
against fields that never matched any real DTO (same fabrication pattern
as the now-deleted `team_detail_screen.dart`):
- `team_member_data.dart` expected a boolean `active` field and
  `location_label`/`created_at`/`last_session_at`, none of which the
  real backend has ever returned. Rewritten to the real shape (`status`
  string, `joined_at`, `disabled_at`), keeping `active` as a derived
  getter so nothing else had to change.
- `team_remote_datasource.dart` expected a paginated `{"data": [...]}`
  envelope; this endpoint returns a bare JSON array. Fixed.
- `role_guard.dart`: added `Routes.team: 'invitations.create'` — Team
  used to be "always allowed" only because there was no index endpoint
  to gate; now there is, and it's permission-scoped, so mobile needs to
  match or a non-admin role gets a raw 403 instead of the tile simply
  not showing (picked up automatically by the dashboard's
  `_GovernanceMenu` fix from the previous entry).
- `team_list_screen.dart`: `member.role` is now nullable (a membership
  can genuinely have no role — the exact state BUG-012 caused for every
  failed invite before that fix) — handled with a fallback label. Also
  removed a `chevron_right` icon implying the row was tappable into a
  detail screen; no such route has existed since
  `team_detail_screen.dart` was deleted, so it was already dead, just
  newly noticed while in the file.

`flutter analyze` clean, full project. Full writeup:
`docs/BACKEND_BUGS.md#BUG-011`. Not yet verified on-device.

**Coherence sweep status:** this is one domain (Team) out of the ~15 web
controllers surveyed (`app/Http/Controllers/Web/*`) — Catalog, Compliance
(audit + non-conformities), Equipment (devices + programs + maintenance),
Identity (Team — done), Inventory (stock + batches + quarantine +
alerts), Labeling, Purchasing (suppliers + POs + goods receipts +
supplier-products), Reporting (exports), Sterilization (cycles + items +
control tests + attachments), Tenancy (sites + rooms + storage locations
+ site/tenant switching), Traceability (patients + label usage + evidence
search). Team was picked first because it was already flagged (BUG-011)
and gave the clearest signal. The rest still need the same treatment —
log into web, compare against mobile screen-by-screen, cross-check
enums/statuses/fields exactly like the cycle-status and PO-status bugs
found earlier this session. Not done yet.

### 2026-09-25 — Day 45 coherence sweep continued: Stock screen has been silently broken all along (BUG-013), plus a systemic pagination bug (BUG-014)

Continued the same log-into-web-and-compare approach. `/batches` and
`/quarantine` on web were both empty for `demo2` (no goods received
yet in this tenant), which prompted checking the real
`StockLevelData` DTO source directly rather than relying on empty
responses — and that's where this turned up something serious.

**BUG-013 (critical):** `app/Domain/Inventory/Data/StockLevelData.php`
has only ever declared 4 fields — `id, batch_id, location_id, quantity`
— confirmed by reading the class itself (Spatie Data serializes exactly
its declared properties). The mobile `stock_level_data.dart` model
expects `product_name, product_reference, product_unit, min_threshold,
location_name, batch_number, expiry_date`, none of which were ever
present, plus it read `qty` where the real field is `quantity`. None of
this crashed — every missing field silently fell back to `''`/`0`/
`null` in Dart's null-safe parsing, so the Stock Levels screen has
apparently been rendering blank product names and zero quantities this
entire time, on every row, with nothing to notice. The earlier "Gate 8
partial audit" this session verified the *write* actions
(issue/adjust/transfer, and the empty-reason block) but never actually
looked at whether the *list* screen rendered real data — this is
exactly the gap a coherence sweep is supposed to catch.

Fixed by enriching the DTO through relations that already existed
(`StockLevel belongsTo Batch belongsTo Product`, `StockLevel belongsTo
StorageLocation`) and eager-loading them in the controller. Also added
`search` support — the mobile client had been sending it as a plain
query param all along, but the controller never read it at all, so the
Stock screen's search box has also been doing nothing this whole time.

**Verified with a real, full write path**, since `demo2` had zero stock
data to inspect: created a storage location (had to go through
`TenantContext::run()` via tinker — `Site`/`StorageLocation` are
RLS-protected and return nothing outside a bound tenant context, same
mechanism as BUG-012), then a real supplier → purchase order → ordered
it → received goods through the actual API
(`POST /purchase-orders/{id}/order` then `.../receipts`, not a
shortcut). Confirmed the enriched response has every field mobile
needs, with real values (`"product_name":"produit 1"`,
`"location_name":"Armoire Sterile A"`, etc.), and that `search=produit`
matches while `search=nonexistentxyz` returns empty. Left this test
data in place (clearly labelled — supplier "Fournisseur Sweep Test",
batch "SWEEP-001") rather than trying to delete it; real business rows
like this may not even be cleanly deletable given how strict this
backend's audit/append-only invariants have already proven to be.

**BUG-014, found while fixing BUG-013's controller:** every API
controller reads `$request->integer('limit', 20)` — confirmed by
grepping the entire `Api/V1` controller tree (13 hits for `limit`, zero
for `per_page`). 15 separate mobile datasource files were sending
`per_page` instead, silently ignored by every one of them, capping
every list at the backend's default page size no matter what the
client asked for. Proved this live, not just from source: `GET
/audit-events?per_page=30` returned 20 rows; `GET
/audit-events?limit=30` returned exactly 30, same 128-row dataset.
Fixed with a pure key rename across all 15 files — no logic change.

Both fixed and deployed the same way as BUG-011/012: edited the host
`steriqore` repo, hot-copied into the running container, `php -l`
before every reload, `octane:reload` after (Octane keeps the app
booted in memory, so a plain file edit alone does nothing — learned
this the hard way on BUG-012, now routine). One unrelated snag: copying
the edited `routes/api.php` for BUG-011 broke the whole app with a PHP
syntax error from a pre-existing, uncommitted, half-finished line
(`.../attachments-base64` route pointing at a controller method that
doesn't exist) sitting in the host repo's working tree — not something
introduced this session, but it briefly took the container down until
found and removed (confirmed via `git diff` it wasn't a committed
change, and via `grep` that the target method genuinely doesn't exist,
before deleting it).

`flutter analyze` clean, full project, after every change this entry
covers. Full writeups: `docs/BACKEND_BUGS.md#BUG-013` and `#BUG-014`.
Not yet verified on-device — phone not connected this session.

**Coherence sweep status:** two domains done now (Team, Stock). Still
untouched: Catalog, Compliance, Equipment, Purchasing (POs/receipts
already got attention earlier this session but not via the actual web
UI), Labeling, Reporting, Sterilization, Tenancy (Sites — briefly
opened, not fully audited), Traceability. Given what turned up in just
these two domains, the remaining ones are worth the same treatment
before calling Day 45 closed.

### 2026-09-25 — Coherence sweep, third pass: switched method to a direct DTO diff, found two more critical mismatches

Changed approach — instead of clicking through the web UI screen by
screen, pulled every backend `*Data.php` class (`find app/Domain
-iname "*Data.php"`, 49 files) and diffed each one's declared fields
directly against its mobile Dart counterpart. This is what actually
caught BUG-013 in the first place, so made it the primary method going
forward rather than a fallback.

**BUG-015 (critical): `NonConformityData` was an almost total field
mismatch.** Real domain: `id, subject_type, subject_id, description,
raised_by_user_id, raised_at, resolved_by_user_id, resolved_at,
resolution` — raised against a Cycle or Label, nothing more. Mobile's
model expected `reference, kind, status, title, cycle_number,
batch_number, sachets_affected, opened_by, opened_at` — a richer,
entirely invented classification system (recall/quarantine/correction
"kind", a "title", a sachet count) that was never built on the backend.
Worse than just blank fields: `isOpen` read a `status` field that
doesn't exist and defaulted to the literal string `'open'` whenever
absent — meaning a **resolved** non-conformity would display as "En
cours" forever, since the fallback value happened to equal the "is it
open" check target. The create flow was already correct (it only ever
sent `subject_type/subject_id/description`, matching the real
`RaiseNonConformityRequest`) — this was purely a response-parsing and
list-rendering bug.

Fixed by rewriting the Dart model to the real 9 fields, deriving
`isOpen` from `resolvedAt == null` instead, and rewriting `_NcCard` to
show a subject-type badge (Cycle/Étiquette — a real field) instead of
the fabricated kind badge, description instead of the fabricated title.
Also enriched the backend `NonConformityData` with
`raised_by_name`/`resolved_by_name` (mirrors `AlertData`'s existing
`resolved_by_name` — the `raisedBy()`/`resolvedBy()` relations already
existed, just never eager-loaded or exposed), so mobile can show who
raised/resolved something instead of a bare user id. Verified live: real
cycle → raised a non-conformity → resolved it → every field populated
correctly end to end.

**BUG-016 (critical): Alerts never actually filtered by resolved state
— same param-name-mismatch pattern as BUG-014, but for a boolean
instead of pagination.** Mobile sent `resolved: false`; the real filter
is `filter[state]=open` (`AllowedFilter::exact('state')`). Silently
ignored, so the "active alerts" screen has been showing **every alert
ever raised, resolved or not**, indistinguishably (mobile's own
`resolved` field also read a key that never existed, always `false`).
Triggered a real low-stock alert to verify: `filter[state]=open` finds
it, `filter[state]=resolved` doesn't; resolved it; confirmed the
reverse. Also added the real `state`/`subject_type`/`resolved_by_name`
fields to the Dart model and removed `subjectLabel`, which was pure
invention — turned out to be redundant anyway, since the real `message`
field already writes out the full context
(`Stock for "produit 1" is below threshold (2/5).` — noted this message
is in English while the rest of the app is French; a backend
content/i18n gap, not fixed here since mobile has no structured data to
rebuild a French sentence from).

**Found while fixing that same alerts query, since the dashboard uses
it too: three more raw-field bugs in `dashboard_remote_datasource.dart`,
all silent.**
1. Same alerts `resolved`→`state` fix applies to the dashboard's
   "Alertes actives" KPI and "Nécessite votre attention" preview.
2. `todayCycles` filtered on `created_at` — a field that has **never
   existed** on `CycleData` (only `started_at`/`completed_at`) — so
   "Cycles du jour" (both the KPI number and the list) has always shown
   zero, every day, regardless of real activity. Fixed to use
   `started_at`, the closest real proxy.
3. Same section read `c['number']` (real field: `cycle_number`) and
   `c['device_name']` (doesn't exist on the raw list response — only
   `device_id`) — both always blank. Fixed the field name and added a
   parallel `GET /v1/devices` fetch to build a real id→name map, the
   same enrichment pattern `CycleRepository` already uses elsewhere.

Backend changes deployed the same way as every other fix this session
(edit host `steriqore` repo → `docker cp` → `php -l` → `octane:reload`).
`flutter analyze` clean, full project, after all of the above. One test
fixture (`test/fixtures/alert_fixture.dart`) needed updating for the
model's new required fields — `flutter test
test/widget/alert_list_screen_test.dart` re-run green afterward. Full
writeups: `docs/BACKEND_BUGS.md#BUG-015` and `#BUG-016`.

**Also spot-checked and found clean:** `ProductData`,
`ProductCategoryData`, `DeviceProgramData`, `MaintenanceRecordData` —
all match their real backend DTOs field-for-field already. Minor,
lower-priority note: `DeviceDetail.siteName` on mobile reads a
`site_name` key that doesn't exist on the real `DeviceData` (only
`site_id`, no enrichment) — same class of gap as the others but not yet
fixed, need to check how visibly it matters on the device detail screen
before prioritizing it.

**Coherence sweep status:** four domains now covered this way (Team,
Stock, Compliance/non-conformities, Alerts+Dashboard). Still to
DTO-diff: Catalog (Products/Categories done, clean), Equipment (Devices
— one minor gap found, MaintenanceRecord/DeviceProgram done, clean),
Labeling (Labels, LabelUsage, DluRule), Purchasing
(GoodsReceipt/PurchaseOrder/SupplierProduct — Supplier already covered
earlier this session), Sterilization (Cycle/CycleItem/ControlTest/
CycleAttachment — Cycle already spot-checked via the dashboard fix but
not the others), Tenancy (Site/Room/StorageLocation/PracticeIdentity),
Traceability (Patient/LabelUsage/EvidenceSearch).

### 2026-09-25 — Coherence sweep, Purchasing + Sterilization DTOs enriched; Traceability/Patients turned into the session's most serious finding

Continued the DTO-diff method into Purchasing and Sterilization.

**Purchasing:** `PurchaseOrderData` had the exact same class of bug as
Stock (BUG-013) — no `supplier_name` (only `supplier_id`), no
`created_at` at all, and mobile's `reference` field was pure invention
(there is no PO-number concept anywhere in this backend — verified via
the migration and model, `PurchaseOrder` has no such column). The
result: every PO card's bold heading (the "reference") was blank, the
supplier caption was blank, and the date shown was always *today* (the
`DateTime.now()` fallback firing on every real order, silently).
`PurchaseOrderLineData` was missing `product_name` the same way.
Enriched both backend DTOs via the `supplier()`/`product()` relations
that already existed, eager-loaded them in every
`PurchaseOrderController` action. Since there is genuinely no PO
reference field to restore, removed it from mobile entirely rather than
fabricate one — promoted supplier name to the card heading, added a
derived `shortId` (`CMD-` + first 8 chars of the UUID) as a stable,
scannable secondary line instead.

**Sterilization:** `CycleItemData` was missing `batch_number` (batch
relation existed, never joined) and `created_at` (the column exists on
the table — confirmed via the migration — just was never exposed).
`CycleReleaseData` was missing `released_by_name` (same
`raisedBy`/`resolvedBy`-style relation enrichment pattern used for
NonConformity and Alert earlier). Both fixed the same way — enrich the
DTO, eager-load in the controller. Mobile's own `cycle_item_data.dart`
and `cycle_release_data.dart` already expected the correct field names
going in (no Dart changes needed for either) — this was purely a
backend gap, unlike most of today's findings.

**Traceability/Patients — the most serious finding of the whole
sweep.** `PatientData` (backend) is `{id, reference}` — the entire
domain. Not a missing-enrichment gap like everything else today: the
`Patient` model has no name/phone/email/birth-date columns at all, and
`CreatePatientAction`'s own docblock says why — *"there is nothing else
to capture... reference is generated here, never client-supplied, so it
can never accidentally carry real patient data typed into a free-text
field."* A deliberate privacy-by-design decision, not an unfinished
endpoint.

Mobile never noticed. The "New/Edit Patient" form asked staff to type a
real first name, last name, phone, and email — sent to the server,
where it was silently discarded (no request-validation class exists for
these fields; the create action reads nothing from the request body at
all) — and then mobile saved that same real PII to an **unencrypted
local Hive database on the device** (`PatientLocalCache`), specifically
so the name would "survive," with a code comment claiming the fields
"are stored server-side but not returned" — which is false; they were
never stored server-side in the first place. `PatientRepository.search()`
then merged this local shadow store back into live search results, and
`LabelUsageDraft` (the label-usage form's autosave) cached
`patientFirstName`/`patientLastName` the same way. Net effect: every
patient any staff member registered or edited on a given phone had
their real name/phone/email sitting in unencrypted local storage,
outside the backend's access controls, audit trail, and retention
policy — the exact thing the backend's design was built to prevent.

Stopped and asked before touching this one, since it's a compliance
decision, not a pure technical fix. User chose: **remove the local PII
cache and match the real design**, over encrypting it as a stopgap or
leaving it alone. Executed fully:
- `PatientData` → `{id, reference}`. Deleted `PatientLocalCache` and
  `patient_create_request.dart` outright (nothing to send — the create
  action takes no input at all).
- `PatientRepository`: `create()` takes no arguments, `update()` removed
  entirely (there is nothing left to edit), `search()` no longer merges
  a local cache.
- Replaced the input form with a plain confirmation dialog — "a new
  anonymous record will be created," no fields to fill in.
- `patient_tile.dart`, `patient_search_screen.dart`,
  `patient_picker_sheet.dart` now show/search by reference only. Also
  fixed `search()`'s query param while in this code — mobile sent a
  plain `search` param the backend never read (only
  `AllowedFilter::partial('reference')` via `filter[reference]`), same
  class of bug as BUG-014.
- `LabelUsageDraft` now caches `patientReference` (safe — an anonymous
  pseudonym) instead of first/last name.
- Enriched backend `LabelUsageData` with `patient_reference` (safe,
  not PII) and `practitioner_name` (practitioners are real staff with
  real, legitimately-tracked identities — unlike patients, enriching
  this is fine) via relations that already existed, so the label-usage
  history screen shows something real. While there, found
  `label_usage_remote_datasource.dart`'s `fetchHistory()` called
  `(response.data as List)` against an endpoint that actually returns a
  single object or 404 (a label is used at most once) — every real call
  would throw a `TypeError`, silently swallowed by a bare `catch` in
  `label_detail_bloc.dart`, so usage history has been rendering empty
  for every label regardless of real data. Fixed to handle the real
  single-object/404 shape.

Full writeup: `docs/BACKEND_BUGS.md#BUG-008` (BUG-005 and BUG-008 both
reclassified from "backend bug to fix" to "mobile misunderstood a
deliberate design, now fixed"). `flutter analyze` — No issues found,
full project, after every change above. Two test files needed updating
for the new shapes: `test/unit/repositories/label_usage_repository_test.dart`,
`test/unit/storage/label_usage_draft_store_test.dart`.

**Environment note:** the local dev backend had moved to an
unfamiliar "staging" docker-compose setup (`steriqore-app-staging` on
port 8000, new to this session) that was crash-looping on a Postgres
auth failure by the time this work resumed — did not attempt to fix it
blindly, since it looks like unrelated in-progress infrastructure work,
not something to guess at. Left it alone; every backend claim in this
entry was verified by reading the actual PHP source in the host
`steriqore` working tree (all still present, uncommitted, matches
`git diff` exactly) rather than by a live round-trip. Flagging this
because it breaks this session's usual standard of live-curl
verification before calling something fixed — the source-level
evidence is solid, but a real end-to-end pass (create a patient, search
it, record a label usage, read back the enriched response) is still
owed once a backend is reachable again.

**Also found and fixed in passing:** `CycleAttachmentController` already
had a complete, well-written `storeBase64()` method plus its supporting
`DecodeBase64UploadAction`/`AttachCycleFileBase64Request` classes
sitting in the working tree (BUG-001's actual fix, addressing a real
FrankenPHP/Octane `$_FILES` bug) — but no route was ever registered for
it. Added `POST /v1/cycles/{cycle}/attachments-base64`. Mobile has no
caller for this endpoint yet (that's separate, not-yet-done work) and
this wasn't verified live either, same reachability caveat as above.

**Coherence sweep status:** five domains now covered (Team, Stock,
Compliance, Alerts+Dashboard, Purchasing, Sterilization-partial,
Traceability/Patients). Still to DTO-diff: Labeling (Labels proper,
DluRule), the rest of Sterilization (ControlTest — no mobile feature
exists for it at all, confirmed no Dart file references it; skip),
Tenancy (Site/Room/StorageLocation/PracticeIdentity — Site spot-checked
earlier, clean), Catalog/Equipment already confirmed clean.

### 2026-09-25 — All six backend roles now properly represented on mobile, and the environment issue from earlier today resolved properly

User's next ask, after seeing this session's own audit trail: *"add the
whole roles that exist in the backend, make sure the backend completely
connected with the app."* Two parts — a real, concrete mobile gap, and
finishing the live-verification debt flagged a few entries up.

**The mobile gap.** `app/Domain/Identity/Enums/TenantRole.php` (the
real, backend-enforced set) is exactly six values: `owner, admin,
stock_manager, releaser, practitioner, viewer`. `team_list_screen.dart`
had `owner, practitioner, stock_manager, reception` — `reception`
isn't a real role anywhere in this backend, a leftover from the
fictional "4-role" planning doc this session already flagged and
discarded once; `admin`, `releaser`, `viewer` were simply absent from
the filter chips and the badge-tone switch, and the badge itself showed
the raw role string uppercased (`STOCK_MANAGER`) rather than a real
label. `team_invite_sheet.dart`'s dropdown was missing `owner` too —
checked directly (`CreateInvitationRequest`, `CreateInvitationAction`,
`InvitationPolicy`): nothing restricts inviting a second owner, only
the same `invitations.create` gate as any other role, so it's a real,
usable backend capability the app just never exposed.

Fixed with one new shared file,
`lib/features/identity/data/models/tenant_role.dart` — a single
`kTenantRoles` list (value + French label) plus
`tenantRoleLabel()`/`tenantRoleTone()` helpers, now the one source of
truth. Used in `team_list_screen.dart` (filter chips, badge — the old
duplicated switch statements are gone), `team_invite_sheet.dart`
(dropdown, with a one-line warning shown only when "Direction" (owner)
is selected, since it's meaningfully more sensitive even though the
backend doesn't gate it specially), and `settings_screen.dart` (the
current user's own account badge, which used to collapse all five
non-owner/admin roles into a generic "Personnel" — now shows the real
role). Swept the rest of the app for other hardcoded role-string
comparisons (`grep` for `.role == 'owner'` etc. outside this file) —
none found; everything else already went through the permission-based
`RoleGuard`/`hasPermission()` system fixed earlier this session, which
needed no changes to support the other three roles since it was never
role-name-specific to begin with.

**Finishing the verification debt.** The local backend had moved to an
unfamiliar "staging" compose setup that was crash-looping on a Postgres
password mismatch when this thread picked back up — traced it
precisely: `.env.staging`'s `DB_PASSWORD=steriqore_app_secret` didn't
match what that Postgres container was actually initialized with
(`POSTGRES_PASSWORD=secret`). Its own header comment says exactly what
it is: *"Local backup/restore drill only (Day 49) — NOT a real deployed
staging environment... throwaway local secrets... gitignored."* Not
mine to fix blindly and not the environment to verify today's work
against anyway — left it alone.

Brought up the regular dev stack instead (`docker-compose.yml`,
`steriqore-app` on port 8010 — the one used for every live check
earlier this session). **Real mistake, worth recording honestly:**
`docker compose -f docker-compose.yml up -d app postgres redis minio`
also tore down the staging containers, because both compose files
share the same default project name and Docker treated the staging
containers as orphaned resources under that project. Checked
immediately — `docker volume ls` confirmed all four `*-staging` named
volumes survived untouched (only containers were recreated, no `-v`
flag was used), so no data was actually lost and the drill stack can
come back with `docker compose -f docker-compose.staging.local.yml up
-d` once someone fixes its own password file — but I said I'd leave it
alone and then didn't, and that's worth being direct about rather than
quietly moving past it.

The regular stack came up against the **same Postgres volume** used
all session before the context reset (confirmed: logging in as
`admin2@steriqore.local` returned the same user/tenant ids as every
earlier entry in this log) — but running the old cached image, so none
of today's or the prior session's uncommitted source fixes were baked
in (`docker cp` hot-patches only ever lived in the container that
session originally built, which no longer exists). Rather than repeat
~20 individual hot-patches, ran a real
`docker compose -f docker-compose.yml build app` (succeeded, ~2 min),
then `docker compose -f docker-compose.yml up -d --no-deps app` to
recreate just that one container from the fresh image — durable this
time, survives a restart without needing to be re-patched.

**Verified live, all six roles, real invite→accept round trips:**
| Role | Confirmed permissions (real, from live response) |
|---|---|
| owner | full set, including `evidence_settings.manage` |
| admin | same as owner minus `evidence_settings.manage` |
| stock_manager | inventory/products/suppliers/purchasing/devices/cycles/labels manage, no `patients.manage`, no `audit.view` |
| releaser | `cycles.release` + `non_conformities.manage`, view-only elsewhere |
| practitioner | `patients.manage` + `usages.manage`, view-only elsewhere |
| viewer | `.view` permissions only, zero `.manage` anywhere |

Every role's permission set is distinct and sensible for what it's
named. `GET /v1/members` (BUG-011) shows all of them correctly
post-rebuild; `GET /stock-levels` (BUG-013) and
`GET /purchase-orders` (this session's Purchasing enrichment) both
still return the enriched shape with the exact same real data created
earlier today, confirming the rebuild didn't lose anything and the
fixes are genuinely baked into the image now, not just a live
container's memory. The `attachments-base64` route (BUG-001) is also
confirmed registered. Disabled the three new test accounts
(`admin-test`/`releaser-test`/`viewer-test@steriqore.local`) the same
way as every other test account this session.

`flutter analyze` — No issues found, full project, after the role
changes. Full writeup: `docs/BACKEND_BUGS.md#BUG-017`.

### 2026-09-25 — Finished the remaining verification debt, found BUG-010 is broader than filed, then made a real mistake and corrected it in place

With the backend reachable again, closed out the two remaining
"not yet verified live" caveats from earlier today.

**Patients (BUG-008) and label usage — fully confirmed.**
`POST /v1/patients` with no body → real `{id, reference}`;
`filter[reference]=PAT` search matches correctly. Full real chain to
generate an actual label — create cycle → add item → start → complete
→ create a DLU rule (none existed yet) → generate labels → print →
scan (`created → printed → used`, learned along the way that viewing a
label via `GET /labels/{code}` alone does *not* mark it scanned —
only a `Printed` label transitions to `Used` on scan) → record usage —
confirmed the response is exactly `{..., patient_reference:
"PAT-000003", practitioner_name: "Admin Two", ...}`, and
`GET /labels/{id}/usage` returns the same single-object shape
`fetchHistory()` was fixed to expect.

**BUG-001's base64 upload — confirmed genuinely fixed.** Uploaded a
real base64-encoded PNG to a real cycle, got back a real
`{id, file_name, mime_type, size, created_at}`. The upload itself
works.

**Then found BUG-010 is worse than filed — same `minio:9000` symptom
on the `media` disk too**, discovered from that same upload's `url`
field. Diagnosed it (I believed correctly) as the same missing `url`
config gap already filed for the `backups` disk, and fixed it the
"proper" way: added `AWS_URL_MEDIA`/`AWS_URL_BACKUPS` env vars to
`docker-compose.yml`, wired them into `filesystems.php`, rebuilt the
image, redeployed.

**It didn't work — and I want to be direct about it rather than let
the earlier "fixed" claim stand.** Tested the actual upload again after
redeploying: still `minio:9000`. Went back and tested the *original*
`s3` disk directly — the one BUG-010 had cited as proof the `url` config
approach works — and it turns out it was never actually proof of
anything relevant:
```
Storage::disk('s3')->temporaryUrl(...)  →  minio:9000/...   (still wrong)
Storage::disk('s3')->url(...)           →  localhost:9023/... (correct)
```
The `url` config only affects `Storage::url()` — plain, unsigned links.
Every real caller in this app uses `temporaryUrl()` (every bucket here
is private), and Laravel's S3 adapter signs `temporaryUrl()` against
whatever `endpoint` the client was constructed with, full stop — `url`
never enters into it. BUG-010's original diagnosis had compared the
wrong method against the one that's actually used, and I repeated that
same error while trying to fix it, this time confirming it "worked" by
checking `config(...)` returned the right string rather than actually
calling `temporaryUrl()` end to end.

Corrected `docs/BACKEND_BUGS.md#BUG-010` in place — reopened it,
kept the (harmless, still technically correct for `url()`) env var
addition, and wrote up what a real fix actually needs: either a custom
adapter that rewrites the signed URL's host after generation, or
infrastructure-level DNS work so one hostname resolves correctly both
inside Docker and from a real client. Neither is done. Also corrected
BUG-001's entry, which had cited the same broken `url` field as
evidence — split it clearly into "the upload works" (true, verified)
and "the returned download link works" (false, still BUG-010).

Worth naming directly: this is exactly the kind of claim this session's
own standard exists to catch — "the config looks right" is not the same
as "I called the function real callers call and watched it produce
the right output." Caught it by continuing to test after redeploying
rather than stopping at "the fix compiled and the config value is
correct," and corrected the record the same day rather than letting a
wrong "✅ Fixed" sit in the bug tracker.

### 2026-09-25 — Coherence sweep resumed on Labeling: the Scanner — a bottom-nav tab — turns out to have been completely non-functional

Continued the DTO-diff method (the one that already caught Stock,
Purchasing, NonConformity, Alerts) into the Labeling domain. This is
the most severe finding of the entire sweep, worse than the Stock bug.

`GET /v1/labels/{code}` — the real scan endpoint — returns a flat
object: `{label_id, status, cycle_number, device_name, sterilized_at,
use_by_date, sequence_in_cycle, site_name}`. Mobile's
`LabelScanResult.fromJson()` expected a wrapper shape that has never
existed on this backend: `{code, status, reason, label: {...}}`. Every
real scan response has no `label` key at all, so `result.label` was
**always null** — and the "Enregistrer utilisation" button's guard was
literally `result.label == null ? null : ...`, meaning it was **always
disabled**. A practitioner could never record a usage from the scan
flow — the single clinical action this whole app exists to support.

Traced the full blast radius before fixing anything:
- `label_detail_screen.dart`'s info card never rendered
  (`if (result.label != null)`, always false).
- `LabelScanStatus` only recognized `valid`/`expired`/`recalled` — the
  real enum is `created, printed, used, expired, recalled, voided`, so
  the *common* real states (`created`/`printed`/`used`) all fell
  through to `unknown`.
- `label_usage_form_screen.dart` read `productName`/`code`/
  `batchNumber` — none of which exist anywhere in the real label
  domain (confirmed by reading `Label`'s actual model properties) —
  always showing a generic "Étiquette" title.
- `scanner_screen.dart`'s post-scan routing checked `r.isBlocked`
  before navigating to the dedicated, well-built `LabelBlockedScreen`
  — but read `ResolveLabelScanAction`'s actual source directly and
  confirmed it **always throws** a 410 for a recalled/expired/voided
  label, never returns a successful DTO with that status. So
  `r.isBlocked` could never be true, and `LabelBlockedScreen` —
  fully built, never reachable — every blocked scan just showed a
  small snackbar with the raw English backend error message and reset.
- `nc_create_sheet.dart` (raising a non-conformity against a scanned
  label) had the identical `result.label == null` guard — meaning that
  flow has also always failed, showing "Étiquette introuvable" for
  labels that genuinely exist.

**Fixed:** rewrote `label_scan_result.dart` as one flat model matching
the real DTO exactly, deleted `label_data.dart` (never a real shape —
its `code`/`productName`/`batchNumber`/`expiresAt` don't exist on
labels at all). Added `canRecordUsage => status == used` as the real
gate, matching `RecordLabelUsageAction`'s actual requirement
(confirmed live: an unscanned label gives `LABEL_NOT_SCANNED`).
Propagated the real error `code` (previously discarded, only `message`
was kept) through both `LabelDetailState` and `ScannerState`, so
`LabelBlockedScreen` and `scanner_screen.dart`'s routing now classify
by the actual backend error code instead of a status that can never
arrive there. Fixed `nc_create_sheet.dart` to use `result.labelId`
directly. Found and fixed one more latent bug while in
`ScannerState`: `copyWith(error: null)` never actually cleared the
field — the exact same `?? this.field` nullable-clear bug already
found and fixed in `AuditListState` earlier this session — added
explicit `clearError`/`clearErrorCode` flags.

**Verified live, twice.** First, confirmed the real
`GET /v1/labels/{id}` response for an already-used label matches the
new model field-for-field exactly. Then set that same label's status to
`Recalled` directly via tinker and confirmed the endpoint responds with
exactly `{"code":"LABEL_RECALLED",...}` and HTTP 410 — precisely the
error code the fixed routing now checks for — then restored it to
`Used` afterward.

Also fixed `DluRuleData` while still in Labeling: real DTO has 8
fields, mobile only read 4 (and one of those, `reason`, was the wrong
name — real field is `last_reason`). Added the revision-history fields
(`last_updated_at`/`last_updated_by`/`existing_labels_count`) to the
read-only DLU rules screen — real governance information that existed
on the backend the whole time but was never surfaced.

`flutter analyze` clean, full project. Two real (non-stub) test files
needed rewriting, not just patching: `test/bloc/scanner_bloc_test.dart`
had a test literally named *"emits \[resolving, resolved\] with blocked
status for expired label"* — asserting behavior that is structurally
impossible on the real backend. Rewrote it to assert what actually
happens (an `error` state with `errorCode: 'LABEL_EXPIRED'`).
`test/widget/label_detail_screen_test.dart` asserted on the fabricated
`productName` field; rewritten to check `deviceName`, a real one. All
24 tests across the four touched test files pass.

Full writeups: `docs/BACKEND_BUGS.md#BUG-018` (Scanner) and `#BUG-019`
(DluRuleData).

**Coherence sweep status:** Labeling now covered. Confirmed no mobile
feature exists for `ControlTestData`, `LabelPrintData`, or the Tenancy
domain's `RoomData`/`StorageLocationData`/`PracticeIdentityData` — no
Dart model or screen references any of them, so there's nothing to
diff (these are legitimately web-only admin surfaces per the master
plan, already tracked as known gaps in BUG-002/003/004). With Team,
Stock, Compliance, Alerts+Dashboard, Purchasing, Sterilization
(CycleItem/CycleRelease), Traceability/Patients, and now Labeling all
covered, every mobile feature that has a real backend DTO to compare
against has been swept.

Last check: `StockMovementData` read `kind`/`created_at`, real fields
are `type`/`occurred_at` (BUG-020) — zero display impact confirmed (no
screen references this model, only blocs holding it as a
success-indicator return value), fixed anyway for correctness and
verified live (`POST /stock-movements/adjust` →
`{"type":"adjustment",...,"occurred_at":"..."}`), matching the standard
applied to every other model this sweep.

**Coherence sweep — closing summary.** Started as a single-domain check
(Team, prompted by BUG-011) and grew into a systematic pass across the
whole app once the DTO-diff method proved itself. Final count: 20
backend/mobile mismatches found and documented (`BACKEND_BUGS.md#BUG-001`
through `#BUG-020`), the large majority fixed and live-verified this
session. In rough order of real-world severity: the Scanner being
completely non-functional (BUG-018), patient PII sitting unencrypted on
device to work around a deliberate backend privacy design (BUG-008),
the Stock and Purchasing screens silently rendering blank data
(BUG-013/mobile Purchasing fix), the invitation-accept flow that made
every non-owner role practically unusable (BUG-012), and the missing
`GET /v1/members` that made the entire Team screen dead (BUG-011).
Every domain with a real mobile screen has now been diff'd against its
actual backend DTO at least once; what's left in `BACKEND_BUGS.md`
without a ✅ is either a genuine backend gap outside mobile's control
(BUG-002/003/004/007/009, missing endpoints) or the presigned-URL
issue (BUG-010) that still needs real infrastructure work, not a config
tweak, honestly documented as still open after the correction earlier
today.

### 2026-09-25 — Role/permission audit: five in-screen actions were visible to roles that would 403 on tap

Separate from the DTO coherence sweep above: a systematic pass checking
every in-screen action gate (`hasPermission(...)`) against the real,
live-verified permission sets for all six roles (owner, admin,
stock_manager, releaser, practitioner, viewer — captured earlier this
session via real invite→accept round trips), and cross-checked against
`RoleGuard`'s route-level map (`lib/core/router/guards/role_guard.dart`).
The failure pattern being hunted: a button/tile visible to a role whose
real backend permissions don't cover the action, so tapping it either
403s outright or gets silently redirected by `RoleGuard` after the user
already invested effort (filled a form, scanned a label). Confirmed the
codebase's established convention for this is to hide the control
entirely, not disable it (`non_conformities_screen.dart`,
`device_list_screen.dart`, `supplier_list_screen.dart` already did this
correctly — used as the template for every fix below).

**Found and fixed, five real gaps, all missing a permission check
entirely (not a wrong permission string — no check at all):**

1. `label_detail_screen.dart` — "Enregistrer utilisation" had only a
   label-status check (`result.canRecordUsage`), no `usages.manage`
   check. A `viewer`, `stock_manager`, or `releaser` scanning any validly
   `used`-status label saw a fully enabled button. Route itself is
   correctly gated (`/app/labels/*/usage` → `usages.manage`), so this was
   a UX gap, not a security hole — but exactly the trust-destroying
   pattern flagged as top priority.
2. `purchase_order_list_screen.dart` — "Nouvelle commande" (both the
   app-bar icon and the empty-state button) had zero permission check.
   Any of the four roles without `purchasing.manage` (releaser,
   practitioner, viewer — plus this route has no dedicated path, so there
   was no route-level backstop either) could open the create sheet and
   fill it in before the backend rejected the submit.
3. `purchase_order_detail_screen.dart` — "Marquer comme commandée" and
   "Réceptionner" were gated purely on PO status (`po.canOrder`/
   `po.canReceive`), no `purchasing.manage` check. The receive route
   (`/app/purchases/*/receive`) is `RoleGuard`-protected, so this was a
   dead-tap UX gap; the order-mark action has no separate route at all,
   so it was a real gap same as #2.
4. `stock_level_list_screen.dart` — the "Actions rapides" row (Sortie /
   Ajustement / Transfert) was shown unconditionally to everyone who can
   view stock (`inventory.view` — all six roles), linking to three routes
   that all require `inventory.manage` (owner/admin/stock_manager only).
   A `viewer`, `releaser`, or `practitioner` saw all three tiles fully
   tappable. This is the closest match to the exact scenario named in
   this session's operating brief ("a stock_manager sees a tile it can't
   use" — here it's the reverse role set, but the identical shape).
5. `alert_list_screen.dart` — "Marquer comme résolu" had no permission
   check anywhere, and unlike the others, `alerts.manage` has **no route
   of its own** in `RoleGuard` at all (only `alerts.view`, which every
   role has) — meaning this was the one case with no backend-adjacent
   backstop whatsoever; a practitioner/releaser/viewer tapping it would
   have gotten a raw, unhandled 403 straight from the resolve endpoint.

**Confirmed correct, no gap:** `cycle_detail_screen.dart`'s release
button (already separately gated on `cycles.release`, distinct from
`cycles.manage` — a `viewer` gets `_ReadOnlyBanner()`, not the button);
`device_detail_screen.dart` (every action — edit, delete, add programme,
add maintenance — already threaded through a single `canManage` computed
once at the top); `team_list_screen.dart` (invite already gated on
`invitations.create`; no disable/revoke action exists in the UI at all —
a missing feature, not a permission gap); `sites_list_screen.dart`
(deliberately read-only, no manage action to gate); `dlu_rules_screen.dart`
(view-only, and the whole route is already owner-only via
`evidence_settings.manage`); the dashboard's `_GovernanceMenu` (already
fixed in an earlier session entry today — re-verified here, filters every
tile through `RoleGuard.isAllowed`, not a hand-rolled check).

**One more found while checking cycle creation specifically:**
`cycle_list_screen.dart`'s "Nouveau Cycle" app-bar button had no
permission check at all, linking to `/app/cycles/create`
(`RoleGuard`-gated on `cycles.manage`) — same UX-gap shape as #1 and #3.
Fixed the same way: hidden for anyone without `cycles.manage`.

All six fixes follow the same shape: compute
`getIt<SessionStore>().hasPermission('<perm>')` once per screen, hide
(never just disable) the control when false. `flutter analyze` run
clean on every touched file
(`label_detail_screen.dart`, `purchase_order_list_screen.dart`,
`purchase_order_detail_screen.dart`, `stock_level_list_screen.dart`,
`alert_list_screen.dart`, `cycle_list_screen.dart`) — no errors, no
warnings.

Not yet done: a live device pass actually logging in as a low-privilege
account (e.g. `viewer` or `releaser`) to visually confirm each hidden
control stays hidden, rather than trusting the permission-set diff alone.

### 2026-09-26 — Production-readiness sweep: four parallel audits across every screen, two critical backend bugs found independently

User's ask: *"do final fix for the whole app... recheck each ui pattern,
each logic, each detail... for each role... add what is missing... make
the app ready product for a famous clinic."* Given the scope (39 screens
across every feature), split the work into four parallel sub-sessions by
feature domain, each briefed with the exact live backend route list
(`docker exec steriqore-app php artisan route:list --path=api/v1`) and
the real role→permission table read directly from
`app/Domain/Identity/Actions/SeedTenantRolesAction.php`, with explicit
instructions to verify any "this is missing" claim against actual
backend capability before building anything — the same no-fabrication
standard as every other entry in this log.

**Identity/Settings/Auth/Dashboard/Sites:**
- Wired a real, previously-unused backend capability:
  `DELETE /v1/members/{id}` (disable a team member, `memberships.disable`)
  is now a per-row action in `team_list_screen.dart`, hidden for the
  current user and already-disabled members, with a confirmation dialog.
- Found and fixed a real silent-failure bug in `team_invite_sheet.dart`:
  the submit handler used to show "Invitation envoyée" and close the
  sheet *before* the async call resolved, swallowing a duplicate-email or
  invalid-role rejection with zero feedback.
- Found and fixed a real DTO bug while implementing the above:
  `TeamRemoteDatasource.list()` expected a paginated `{data:[...]}`
  envelope from `GET /v1/members`, but the endpoint returns a bare JSON
  array; `TeamMemberData` also had invented fields (`active` bool,
  `locationLabel`, `lastSessionAt`) that don't exist on the real
  response — corrected to the real shape (`status`, `joinedAt`,
  `disabledAt`).
- Confirmed real, unbuilt gap left alone: invitation revocation
  (`DELETE /v1/invitations/{id}`) is currently unreachable from any
  client — there is no `GET /invitations` list route anywhere, and
  `MemberController@index` only ever returns `TenantUser` rows, never
  pending invitations. Not a mobile oversight; the backend gives no way
  to discover an invitation's id after creation.

**Cycles/Devices:**
- Built a completely missing, critical workflow step: generating a
  cycle's labels after release. `POST/GET /cycles/{id}/labels` existed
  and were used by nothing — the scan→usage pipeline had no mobile path
  to actually producing a scannable label. Added a "Générer les
  étiquettes" flow to `cycle_detail_screen.dart` (shown only when
  `status == 'released' && labels.manage`), verified against
  `CycleLabelController`/`GenerateCycleLabelsAction`/`LabelPolicy`
  directly. Not live round-trip tested (no released cycle + correctly
  permissioned test account was available in the moment) — flagged
  honestly rather than skipped or overclaimed.
- Found `cycle_attachments_screen.dart` was a stale placeholder blocked
  by a `TODO(p0)` citing BUG-001 as unfixed — but BUG-001 (the base64
  attachment endpoint) was already fixed and live-verified earlier this
  session, and `CycleRepository.uploadAttachment()` already existed with
  a working, different signature the screen never adopted. Rebuilt the
  screen for real, using `image_picker` (already a declared, unused
  dependency).
- Fixed raw `e.toString()` error displays (showing Dart exception text
  instead of French messages) in `cycle_create_screen.dart` (3 places)
  and `device_detail_screen.dart` (4 places).
- Flagged, not fixed (outside that pass's directory scope): three dead,
  unreachable duplicate screens — `cycle_release_screen.dart`,
  `cycle_items_screen.dart`, `cycle_control_tests_screen.dart` — each
  reimplementing what `cycle_detail_screen.dart` now handles inline, with
  weaker/no permission checks and nothing in the app navigating to them.
  Confirmed via `app_router.dart`'s global `redirect` callback that
  `RoleGuard` still blocks these routes before the screen ever builds
  (not an active vulnerability), then removed their `GoRoute`
  registrations and imports. **Could not delete the three source files
  themselves** — the sandbox blocked `rm` as an irreversible destructive
  action; they're fully unregistered and unreferenced now but still sit
  in `lib/features/cycles/presentation/screens/`, safe to delete
  manually.

**Stock/Purchases/Suppliers/Catalog/Alerts:**
- Built a real, previously entirely-missing feature: a supplier detail
  screen (`supplier_detail_screen.dart`) showing linked products via
  `GET/POST /v1/suppliers/{id}/products` — `ApiEndpoints.supplierProducts`
  had been defined and unused. Gated on `suppliers.manage`, registered as
  `/app/purchases/suppliers/{id}` with a new `RoleGuard` prefix rule
  (ordered correctly ahead of the generic `/app/purchases/` rule).
- Deliberately left `POST /stock-levels/rebuild` unbuilt after reading
  its controller: it's a ledger-replay recovery/ops action, not a
  clinic-staff workflow — exposing "Recalculer les stocks" in the field
  app risks accidental taps on a data-integrity operation that belongs to
  support, not daily use.
- Deliberately did not add confirmation dialogs to stock issue/adjust/
  transfer/receive: reasoned these are routine, high-frequency actions
  for a stock manager, and forcing a confirm tap on every one is friction
  without real safety benefit (unlike cycle release or member disable,
  which are rare and high-consequence) — everything else in this scope
  (suppliers/products CRUD, PO pagination, goods receipt double-submit
  guard) was already correct.

**Compliance/Patients/Labels/Scanner/DLU/Reporting/Sync/History:**
- Built full DLU-rule CRUD (`dlu_rule_form_sheet.dart` + repository
  create/update/destroy) — the screen was hardcoded read-only
  ("gérées... sur le web") despite the backend fully supporting
  `POST/PATCH/DELETE /dlu-rules`. Live-verified: created and deleted a
  real test rule against the running backend, confirmed the response
  shape matches `DluRuleData.fromJson`.
- **Corrected a wrong assumption in the briefing, verified against
  source, not taken on faith:** the real `DluRulePolicy.php` gates
  `create`/`update`/`delete` on `labels.manage` — not
  `evidence_settings.manage` as `role_guard.dart`'s own comment claimed.
  Grepped the entire backend: `evidence_settings.manage` is referenced
  nowhere in any API controller, only in the web-only
  `Tenancy\PracticeSettingsController` — it has zero relevance to this
  route. Fixed `role_guard.dart`'s `Routes.dluRules` entry from
  `evidence_settings.manage` to `labels.view` (the real `viewAny` gate,
  universal), so a stock_manager can now actually reach and manage DLU
  rules as their own backend grant already allows, and every role can at
  least view them — the mobile app had been more restrictive than the
  backend's own product design for no real reason.
- Built a second, entirely missing feature: evidence search
  (`GET /v1/evidence-search` — the pouch→cycle→device→practitioner→
  patient traceability search, core to this app's compliance purpose per
  the backend's own code comments). `ApiEndpoints.evidenceSearch` existed
  and was unused; built the full stack (model/datasource/repository/
  bloc/screen) under `lib/features/reporting/`. Wired the remaining
  pieces myself afterward (outside that pass's scope): DI registration in
  `features_di.dart`, a new route (`/app/evidence-search`, gated on
  `usages.view` — verified against `EvidenceSearchController`'s
  `LabelUsagePolicy::viewAny`, universal), and a dashboard entry under
  "Clinique & Conformité." A separate, more sensitive `export` ability
  (`exports.manage`) exists for a bulk-export action this first version
  doesn't build yet — left for later, not silently dropped.
- Added pull-to-refresh to `sync_queue_screen.dart` (previously only
  reloaded on init or after a manual retry).
- Confirmed correct, no change needed: patient CRUD, `patient_tile.dart`
  (an earlier plan to show phone/email/age is now obsolete —
  `PatientData` deliberately carries no PII fields post-BUG-008),
  `data_export_request_screen.dart`, `label_usage_form_screen.dart`,
  `non_conformities_screen.dart`, `scanner_screen.dart`.

**Two backend findings while live-verifying the above** (full detail in
`BACKEND_BUGS.md#BUG-021`/`#BUG-022` — both in the `steriqore` backend
repo, outside this repo's scope; user chose to fix both immediately
rather than only document them):
- **BUG-021, critical, fixed and live-verified:** `POST /v1/tenants` (new
  practice signup) was 100% broken, deterministic, reproduced 3/3 —
  `RegisterTenantController` never wrapped its response construction in
  `TenantContext::run()` the way `LoginController` correctly does, so the
  role-lookup query ran with an empty-string team id and Postgres
  rejected it outright. Fixed with the same one-line pattern
  `LoginController` already used, rebuilt the `steriqore-app` image,
  re-ran the exact repro 3/3 — all now return `201` with the full,
  correct permission set. Every real signup attempt from
  `register_screen.dart` would have 500'd until this fix; confirmed
  working end-to-end now.
- **BUG-022, downgraded to closed after further testing — worth recording
  the correction itself:** a test account (`admin2@steriqore.local`) with
  full permissions in its own `/me` response got `HTTP_403` on `/sites`,
  `/audit-events`, and `/members`. `permission:cache-reset` fixed it
  instantly, which initially looked like a systemic stale-cache bug and
  was logged as one. But once BUG-021's fix made real registration usable
  again, registering a **brand-new** tenant through the normal flow and
  immediately hitting the same endpoints with the fresh token — no cache
  reset in between — worked on the first try. That isolates the original
  staleness to this session's own extensive `tinker`-based manipulation of
  that specific test account (password resets, account
  creation/disabling, mid-session container rebuilds) rather than a
  defect in the app's real request lifecycle. Cleared the cache once for
  cleanliness; made no code change, since a change would have "fixed" a
  problem that doesn't actually reproduce through real usage — worse than
  no fix, and exactly the kind of overclaim this session's own standard
  exists to catch.

**flutter analyze:** clean, full project, zero issues, after merging all
four parallel work streams plus the consolidation fixes above (DI
registration, route wiring, `role_guard.dart` correction, dead-route
removal).

### 2026-09-26 — Prosthetic Work Tracking module adopted for real: ADR 0011 supersedes ADR 0010, full backend domain built and live-verified

User supplied `pjdocs/SteryMed_Prosthetic_Workflow_Implementation_Brief_EN-compressed.pdf`
and asked to "add Prosthetic," acknowledging it isn't in the backend or
the cahier des charges. This is the same module ADR 0010 (2026-09-15)
deferred after finding zero backend support, and the same one that
reappeared once mid-session on 2026-09-24 from an unexplained external
script — both are recorded in memory as a standing caution not to trust
a prosthetic-shaped request without re-verifying.

Read the actual PDF before doing anything: it's a real, dated internal
product brief with named engineering ownership — "Anas" for backend
(Laravel/migrations/endpoints), "Meryem" for mobile (Flutter) — not a
stray planning-doc reference. Re-verified the live backend anyway
(`docker exec steriqore-app php artisan route:list` + `find
app/Domain -maxdepth 1`): still zero `Prosthetic` domain, zero
`prosthetic*` routes, exactly as ADR 0010 found. Presented this conflict
to the user directly rather than either silently building it or silently
refusing; user chose "I build both sides."

Wrote `docs/adr/0011-prosthetic-module-adopted.md`, explicitly
superseding ADR 0010 rather than silently overriding it.

**Backend built** (`steriqore` repo), following this codebase's existing
conventions exactly (studied `NonConformity` — closest existing
domain with a status/resolve shape — and `Cycle`'s attachment handling
as templates rather than inventing new patterns):
- 3 migrations: `laboratories`, `prosthetic_cases`, `prosthetic_case_status_history` — all RLS-scoped like every other tenant table.
- `App\Domain\Prosthetic`: `Laboratory`/`ProstheticCase`/`ProstheticCaseStatusHistory` models, `ProstheticCaseStatus`/`ImpressionType`/`ProstheticWorkType` enums, 5 Data DTOs, 6 Actions (create/update/status-change/attach/remove-attachment/list-with-filters), `ProstheticCasePolicy`/`LaboratoryPolicy`.
- Controllers under `Api/V1/Prosthetic/`: cases (index/store/show/update), status (change + history), attachments (index/store/destroy), dashboard, waiting-placement, laboratories (index/store/update).
- Routes registered under `/v1/prosthetic-*` and `/v1/laboratories`, fixed-segment routes (`prosthetic-dashboard`, `waiting-placement`) placed before the `{prostheticCase}` wildcard so they aren't swallowed by it.
- 3 new permissions in `SeedTenantRolesAction`: `prosthetic_cases.view` (universal, all 6 roles), `prosthetic_cases.manage` (owner/admin/practitioner — practitioner initiates impressions per the brief), `prosthetic_payments.manage` (owner/admin only, matching the brief's "reception/authorized roles" distinction for financial fields).
- **Deliberate deviation from the brief, not a missed requirement:** the brief's create-case screen lists patient first/last name fields; this app's Patients domain is anonymous-reference-only by design (BUG-008) — a prosthetic case links `patient_id` to the existing anonymous patient record instead. Documented explicitly in ADR 0011 rather than silently reopening the PII decision.

**Two real bugs found and fixed during live verification, both mine in this new code, caught before calling it done:**
1. `ProstheticCaseStatusHistory`'s table name — Eloquent's default pluralization guessed `prosthetic_case_status_histories`, the migration used singular `_history`. First `POST /prosthetic-cases` call failed with `relation "prosthetic_case_status_histories" does not exist`. Fixed with an explicit `protected $table` override.
2. `CreateProstheticCaseAction` read `$case->status->value` right after `create()` without explicitly setting `status` in the create array — the model's in-memory state doesn't pick up a DB column default without a refresh, so this null-referenced and crashed with `null value in column "to_status" violates not-null constraint`. Fixed by explicitly setting the initial status in the create payload instead of relying on the DB default.

**Live-verified end to end** (fresh tenant registered through the real
`POST /tenants` flow, a patient and laboratory created, a full case
lifecycle exercised): case create → correct full DTO returned; status
transition `impression_completed → sent_to_laboratory` succeeds;
`impression_completed → placed` correctly rejected with
`422 INVALID_STATUS_TRANSITION` and a French message; status history
shows the initial transition; dashboard counts update correctly
(`active_cases`, `at_laboratory`, `waiting_for_placement` all reflected
the one test case accurately once actually testing the aging/deposit
logic exposed a real bug — see below); waiting-for-placement list
correctly includes a case with `returned_from_lab_date` set and no
`actual_placement_date`; laboratories list/create work.

**One more real bug found and fixed via live testing, not just code
review:** the dashboard's `deposits_or_balances_due` count originally
flagged *any* case where `final_payment_completed` was false — which is
every single non-cancelled case that hasn't finished paying yet, even
one that was never asked for a deposit. Confirmed live (`{"deposits_or_balances_due":1}`
on a case with no deposit requested and no balance recorded) before
fixing. Corrected to only count a genuinely outstanding, known
obligation: `deposit_requested && !deposit_received`, or
`remaining_balance > 0`. Re-verified live after the fix.

**Permission split live-verified with a real second account, not just
code review:** created a `practitioner` test account via a real
invite→accept round trip, confirmed its live `/me` permissions include
`prosthetic_cases.manage` but not `prosthetic_payments.manage` (matching
the seeded design), then confirmed the practitioner's token gets a real
`403` with a clear French message when `PATCH`-ing a payment field, and
succeeds when `PATCH`-ing a clinical field in the same request cycle.
Disabled the test account afterward, same convention as every other test
account this session.

**Not live-verified:** attachment file upload — every attempt failed at
PHP's own temp-file stage (`"/tmp/phpXXXX" does not exist`) before the
application code ever ran, consistent with a curl-multipart-through-
Docker networking limitation in this Windows/Git-Bash test environment,
not a code defect — the implementation is a byte-for-byte mirror of the
already-proven `AttachCycleFileAction`/`CycleAttachmentController`
pattern. Flagged honestly rather than claimed as verified.

**Mobile module** (`sterymed_mobile`, `lib/features/prosthetic/`) — built
against the confirmed backend contract above, not the brief's raw field
list in isolation. Full stack: 5 Data DTOs (with a `ProstheticCaseStatus`
enum carrying the exact same `allowedNext` transition table as the
backend, so illegal transitions are never even offered as a UI option),
remote datasource covering all 13 endpoints, repository, an offline
draft store for the create form (mirrors `LabelUsageDraftStore`), a
filtered/paginated case-list bloc, and 6 screens (home dashboard with
every KPI card opening its filtered list, case list, case detail,
create, waiting-for-placement, laboratories). Wired into
`api_endpoints.dart`, `routes.dart`, `app_router.dart`,
`role_guard.dart` (`prosthetic_cases.view` universal for viewing,
`.manage` for create/labs — matches the backend policies exactly),
`features_di.dart`, and a new "Prothèses" top-level group in the
dashboard's governance menu (not buried in Administration, since it's a
clinical workflow, not an admin setting).

Independently re-verified (not just trusting the build report): full
project `flutter analyze` clean; the status-change UI only offers legal
next statuses and requires a confirmation dialog with an optional note
before `placed`/`cancelled`; the payment section's `hasPaymentDue` logic
matches the corrected backend logic exactly; the patient picker reuses
the real `PatientRepository.search()` and only ever shows
reference/initials, never a name field, consistent with the anonymous-
patient design; `role_guard.dart`'s new entries match the backend
policies field-for-field, with fixed-segment routes
(`create`/`waiting-placement`/`laboratories`) correctly ordered before
the generic `/app/prosthetic/` detail-page prefix rule.

**One deliberate exception to hide-not-disable, documented in the code,
not accidental:** the payment section stays visible (read-only) rather
than fully hidden for a user without `prosthetic_payments.manage` —
matches the brief's own reasoning (page 8) that a clinician still needs
to see "is this case financially clear before placement" even though
they can't edit it.

**One real backend constraint that shaped a mobile judgment call:** the
create-case form auto-fills the practitioner as the current user rather
than offering a picker, because `GET /v1/members` (the only way to list
other staff) requires `invitations.create` (owner/admin-only) — a
practitioner creating their own case has no accessible endpoint to list
colleagues. Follows the exact precedent `cycle_create_screen.dart`
already set for the same constraint (operator = current user). Not
silently guessed — flagged explicitly by the fork and confirmed here.

`docker compose build app` + `up -d --no-deps app` run three times
across this work (table-name fix, status-default fix, dashboard-query
fix) — each rebuild verified against the live container before moving
on, consistent with this session's standing rule that a plain file edit
does nothing under Octane until the image is rebuilt.
