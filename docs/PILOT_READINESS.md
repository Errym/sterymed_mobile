# Pilot Readiness

**2026-09-26.** This is not built from "the master plan's 16 conditions"
verbatim — that numbered list was never received intact in this session
(garbled across every paste attempt). It's built instead from the
project's own real, evidence-based Gate audits already in
`docs/DAILY_LOG.md` (Gate 5 — usage/offline, Gate 6 — cycles, Gate 8 —
stock/purchases/audit/settings, all dated 2026-09-23/24), re-verified
today against everything that changed since — mainly Task 2's completion
(every bloc/widget test stub those audits flagged as empty is now real),
plus this session's own new work (prosthetic module, CI/CD, security
audit, documentation).

Same standard as those audits: no ✅ without a citable artifact (a
passing test, a live curl/device result, or a direct code read called out
as such).

## Legend

✅ Verified · 🟡 Partial (some evidence, real gap remains) · ⏳ Needs a
real device or another human — code-side work is done, this specific
item cannot be closed from a terminal · ❌ Blocked (backend gap, not
mobile) · 🐛 Bug found and fixed along the way

## Gate 5 — Label usage & offline (re-verified)

| # | Item | 2026-09-23 status | 2026-09-26 status |
|---|---|---|---|
| 1 | Offline usage queues and survives app kill | 🟡 queuing+persistence tested, device run missing | 🟡 **unchanged** — still no entry in `docs/DEVICE_TEST_LOG.md` |
| 2 | Sync on reconnect verified server-side | 🟡 client-side flush tested, server-landing unverified | 🟡 **unchanged** |
| 3 | 409 conflict proven with evidence | ✅ | ✅ **unchanged**, strongest-evidenced item in the whole audit |
| 4 | Double-tap impossible | 🟡 architecturally sound, unproven | 🟡 **unchanged** |
| 5 | Form state never lost | 🟡 unit-tested, device confirmation missing | 🟡 **unchanged** |
| 6 | Web shows same usage record (coherence #2) | ⏳ no evidence | ⏳ **unchanged** |
| 7 | Usage tests green | 🟡 bloc level was an empty stub | ✅ **upgraded** — `test/bloc/label_usage_bloc_test.dart` is now real (3 tests: draft restore, no-patient warning, full submit-with-real-payload path), Task 2 |

## Gate 6 — Sterilization cycles (re-verified)

| # | Item | 2026-09-23/24 status | 2026-09-26 status |
|---|---|---|---|
| 1 | Full lifecycle e2e on device | ⏳ → **closed 2026-09-24** | ✅ **still closed** — real device run, all 7 transitions confirmed server-side; found+fixed 2 real bugs (`running`→`in_progress` normalization gap, missing required-item-before-start step) |
| 2 | Rejected release requires reason | 🟡 client-side only, no test | 🟡 **unchanged** — still no `release_decision_sheet_test.dart` |
| 3 | Attachments visible on web (coherence #3) | ❌ blocked, BUG-001 | ❌ **partially unblocked, still not usable** — backend base64 endpoint now exists and is live-verified (BUG-001), but no mobile caller was ever built; still nothing to check on web |
| 4 | Offline transitions sync correctly | 🟡 client-side tested, server-landing unverified | 🟡 **unchanged** |
| 5 | Cycle tests green | 🟡 bloc + widget levels were empty stubs | ✅ **upgraded** — `cycle_list_bloc_test.dart`, `cycle_transition_bloc_test.dart`, `cycle_detail_screen_test.dart` are all real now (Task 2); the widget test also found+fixed a real `ConfirmationDialog` overflow bug |

## Gate 8 — Stock, Purchases, Audit, Settings (re-verified)

| # | Item | 2026-09-24 status | 2026-09-26 status |
|---|---|---|---|
| 1 | Stock adjust blocks empty reason | ✅ client+server confirmed | ✅ **unchanged** |
| 2 | Partial goods reception | ✅ client confirmed | ✅ **unchanged** |
| 3 | Purchase order `canReceive` | 🐛 found+fixed (`'partial'` → `'partially_received'`) | ✅ **unchanged, stays fixed** |
| 4 | Purchase order status badges | 🐛 found+fixed (missing `'closed'`, same typo) | ✅ **unchanged, stays fixed** |
| 5 | Goods receipt: expiry_date / discrepancy_reason / photo | ❌ mobile form collected neither field; no photo route | ✅ / ❌ **partially upgraded** — `goods_receipt_screen.dart` now has both `expiry_date` (`AppDatePicker`) and `discrepancy_reason` (`AppTextField`) fields, and `goods_receipt_bloc_test.dart` (Task 2) verifies both are sent when filled. Photo evidence is still ❌ blocked — no receipt-attachment route exists on the backend at all. |
| 6 | Audit filters | 🟡 action-only | ✅ **upgraded, closed same day (2026-09-24)** — actor/subject/date filters built and live-verified against the real backend, plus a real "Tous ne clears rien" bug found+fixed in the same pass |
| 7 | Settings | ✅ | ✅ **unchanged** |
| — | Stock issue bloc coverage | not yet touched | ✅ **already real** (predates this pass) — `test/bloc/stock_issue_bloc_test.dart`, 2 tests (submit success, 422 failure) |

## New since these gates were last run (this session, Tasks 1–6)

| Area | Status | Evidence |
|---|---|---|
| Prosthetic module | ✅ real and live | `docs/PROSTHETIC_MODULE.md`, ADR 0011. Full screen set, 3 permissions, real backend contract. No offline support for its writes — same class of gap as Gate 5/6/8's offline items above, tracked in `docs/OFFLINE_MATRIX.md`. |
| API contract drift | ✅ checked, 1 real gap found | `test/unit/contract/api_endpoints_test.dart` — 68 `ApiEndpoints` entries checked against the live spec; `ApiEndpoints.site(id)` points at a route that doesn't exist (BUG-025, dead code, zero call sites, not a live bug). |
| Error-code contract | ✅ checked, 1 real bug found+fixed | `test/unit/contract/error_codes_test.dart` — `ApiException`'s `isXxx` getters previously only matched the local lowercase fallback, never the real backend's UPPER_SNAKE_CASE codes. Fixed. |
| Secrets | ✅ clean | `gitleaks detect` against full git history (55 commits) — zero leaks. |
| PII scrubbing (Sentry) | 🐛 found+fixed | `beforeSend` only scrubbed `event.message`; `capture()` actually populates `event.exceptions[].value`, never scrubbed. Fixed — `test/unit/core/crash_reporter_scrub_test.dart`. `capture()` has zero call sites today, so nothing had actually leaked. |
| Dispose/leak audit | ✅ zero real leaks | `test/unit/core/leak_check_test.dart` — static scan of every controller/`FocusNode`/`StreamController` in `lib/`, manually cross-checked. |
| CI/CD | ✅ | 7 workflows, `flutter analyze --fatal-infos` + full `flutter test` on every push/PR, matching local dev bar exactly. iOS build and both release pipelines remain known, tracked gaps (see `docs/CICD.md`). |
| Test coverage | ✅ | 51/51 test files real (was 25/45 as of 2026-09-23) — every previously-empty stub now has genuine coverage or a documented reason it's intentionally a no-op (`docs/TESTING.md`). |
| Documentation | ✅ | All 9 formal handoff docs (`docs/README.md`'s own "6 user-facing + 3 internal" list) reviewed; several were actively wrong (prosthetic marked deleted, patient PII overstated) and fixed — see this session's memory log for the full list. |

## 2026-09-27 — Freeze + final QA pass

Version bumped to `0.2.0+1`, tagged `v0.2.0-pilot` (local only, not
pushed — the old `v0.1.0-pilot` tag already exists and is already
pushed to origin pointing at a 2026-09-17 commit; re-tagging it would
have force-moved a shared reference, so a new tag was used instead).
This session's full accumulated diff (prosthetic module, RBAC/security
hardening, test infra, docs) is now committed across 9 commits on
`phase-2-offline-outbox` — none of it was committed before this pass.

`flutter analyze` clean, full `flutter test` green (409+ tests), and
`flutter build apk --release` succeeded (74MB, SHA-256
`2a41b27e...3714e6`) — **debug-signed**, not production-signed; see item
4 below, unchanged from before this pass.

Two real bugs found and fixed during this pass, not just re-verified:
- 🐛 A previous security-hardening pass had gated `MediaUrl.resolve()`'s
  MinIO-hostname rewrite behind `kDebugMode`, silently breaking every
  export/attachment download in a release build against the still-open
  BUG-010 — reverted; that rewrite is a live interop fix, not a dev
  convenience to strip.
- 🐛 **Hardware back button exits the app** (was already flagged as a
  known, unfixed device-testing issue above) — root cause found
  (`context.go()` replaces the whole nav stack, leaving nothing to pop)
  and fixed with a `PopScope` on `ShellScreen`. Covered by a new widget
  test; **still needs a real-device re-run** to confirm against actual
  hardware (see item 1 below — no device was connected this session).

Live-verified against the real running `steriqore` backend (not
mocked): login for the 2 currently-active seeded accounts (owner,
practitioner), and the full `api_endpoints_test.dart` contract suite
(78 assertions) against the live route table. The other 4 roles
(admin, stock_manager, releaser, viewer) have real backend-sourced seed
accounts but they're currently `disabled` in the demo2 tenant — not
re-enabled here (a one-way action with no in-app undo); their
permission-gating is instead covered by `rbac_role_matrix_test.dart`,
built directly from the backend's real seed source, not live login.

## What still blocks a clean GO

1. **Nothing has been verified on a real, physical device this session** —
   every ⏳ item above (Gate 5 #1/#2/#5/#6, Gate 6 #4) needs an actual
   phone run, not more code or tests. `docs/DEVICE_TEST_LOG.md` has the
   setup steps and known gotchas but zero logged runs. This also applies
   to the back-button fix above and to any iPhone/iOS verification at
   all — no macOS/Xcode is available in this environment.
2. **Server-side landing after sync is never independently confirmed**
   anywhere in this repo (Gate 5 #2, Gate 6 #4) — every offline-queue test
   proves the client *queues and flushes* correctly, none proves the
   resulting record is *correct* on the backend after that flush.
3. **`integration_test/` is still 13/16 files empty** — `docs/TESTING.md`
   has the exact breakdown. The 3 real ones (auth, cycle lifecycle, the
   test-user helper) are a real, working pattern to extend, not a
   from-scratch problem.
4. **iOS has no working CI build** (missing `Podfile`) and **neither
   platform has a signed release pipeline** — known, tracked, explicitly
   out of scope for a pilot running debug builds.
5. **Attachments (cycle + prosthetic case) and purchase-order receipt
   photos are all unusable** — a mix of backend gaps (no route at all)
   and mobile gaps (route exists, no caller built). See
   `docs/MISSING_FEATURES.md`.

## Verdict

**Conditional GO for a pilot with debug builds, on the condition that
item 1 above (a real device pass) happens before real clinic data goes
through the app.** Every code-side gap this project's own audits have
found has either been fixed or is explicitly, honestly tracked — nothing
here is a surprise or a guess. The one thing no amount of additional
coding can substitute for is someone actually running the app on a phone
against the real backend for the offline/reconnect/app-kill scenarios;
until that happens, "offline support works" is a well-tested claim about
the client's *logic*, not a proven claim about the *end-to-end* pilot
experience.
