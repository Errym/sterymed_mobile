# SteryMed — Ultimate Completion & Fixing Breakdown

## From 7.5/10 to a True 10/10 Deliverable

**Prepared after a full re-read of:** `SteryMed_Prosthetic_Workflow_Implementation_Brief_EN-compressed.pdf`, `Cahier_des_charges_MVP_SaaS_HealthTech_Dentaire (1).docx`, the mobile `flutter_codebase_dump.txt`, all 60+ docs under `docs/`, and the backend contract snapshot.

---

## Part 0 — What I Understand About Your Project (Read This First)

**You are building two co-deliverables under one clinic pilot:**

1. **The Cahier MVP** — a stock + sterilization traceability app for a French dental clinic: catalog, stock, purchases, cycles, labels (QR/DataMatrix), patients (pseudonymous references only), non-conformities, alerts, audit, exports, and 2D-code scan on mobile. Six mandatory modules, six demo journeys, ten weeks indicative, twelve-to-sixteen realistic.

2. **The Prosthetic Work Module** — a *separate* brief with its own workflow (impression → lab → returned → scheduled → placed → cancelled/remade), waiting-for-placement view with 0-7/8-14/15+ aging, six combined filters, payment tracking independent from clinical editing, and a "no dead KPI" dashboard rule.

**Two engineers:** Anas (backend, Laravel), Meryem (mobile, Flutter — you). Six backend roles: owner, admin, stock_manager, releaser, practitioner, viewer.

**Current source snapshot:** 424 Dart files under `lib/`, 111 test/integration files, 833 passing Flutter tests, analyzer clean, ~76.6% `lib/core` coverage / ~50.7% overall. Backend has 273 API tests passing in the isolated runner. All routes, DTOs, permissions and migrations exist and are live.

**What the audits honestly say (and I agree):**
- Feature-complete for both briefs' scope.
- Structurally excellent (feature/data/presentation layering, DI split, shared widget kit, outbox, sync engine, RBAC via `RoleGuard`).
- **Not yet deliverable** because: (a) zero device runs, (b) zero staging, (c) zero signed release, (d) a specific set of P0/P1 source defects still open, (e) nothing committed to git.

Below, I translate every remaining item into a checkbox, ordered so that each one unblocks the next. When every box in Sections 1-5 is ticked, you are at 10/10.

---

## Part 1 — THE HARD BLOCKERS (Cannot Ship Without These)

### B1. Bring the tree to a commit-ready state and commit it

Your `git status` shows substantial uncommitted work in both `sterymed_mobile` and `steriqore`, plus a whole untracked `docs/`, `graphify-out/`, `testing/clinic_fixture/`, and `_script_backups/` directory. Nothing else matters until this is fixed.

**Do in this exact order:**

1. Add to `.gitignore`: `graphify-out/`, `flutter_codebase_dump.txt`, `_script_backups/`, `_dartfix.log`, `.aider*`, `.claude/scheduled_tasks.lock`, `coverage/lcov.info`, `docs/phase0/*.local.json`.
2. Delete `.aider.chat.history.md` and `.aider.input.history` — the former contains a partial API key. **Rotate that key.**
3. Re-read `.gitignore` for `android/key.properties`, `android/local.properties`, `release-defines.json`, `.env*`.
4. Commit in logical checkpoints (your call on split, but suggested: docs, tests, features, backend module, backend fixes).
5. Verify `git log` shows a clean history and `git status` is empty on both repos.

**Why first:** Every remaining item below produces artifacts that need to be committed with their tests. Doing this last means one giant, incomprehensible commit — a "you didn't finish" signal to any reviewer.

---

### B2. Run the physical-device matrix — 20 scenarios, logged

`DEVICE_TEST_LOG.md` has zero entries. Every claim in your test suite is currently simulator-only.

**Required scenarios, each logged with date, tester, build SHA, and result:**

| # | Scenario | What only a device can prove |
|---|---|---|
| 1 | Scanner reads printed label at 5/10/20/30/50 cm | Autofocus, print quality |
| 2 | Scanner at 0°/45°/90° | `mobile_scanner` crop geometry |
| 3 | Scanner in low light + screen glare | Real ISO/aperture |
| 4 | Scanner on wrinkled/scuffed label | Physical damage |
| 5 | QR **and** DataMatrix both resolve | Two code formats |
| 6 | Hardware back from Cycles/Purchases/Suppliers | `PopScope` fix (widget-tested only) |
| 7 | Cycle attachment image in full-screen viewer | `ImagePreviewDialog` |
| 8 | Cycle attachment PDF in OS viewer | `OpenFilex` return code |
| 9 | Prosthetic case PDF opens and prints | `prosthetic_case_pdf.dart` |
| 10 | Export archive downloads and opens | `ExportDownloadService` |
| 11 | Prosthetic photo upload — camera | `image_picker` permission flow |
| 12 | Prosthetic photo upload — gallery | Same |
| 13 | Airplane mode ON → issue stock → ON → verify sync | Real connectivity transitions |
| 14 | Kill app mid-form → relaunch → draft survives | Real process death |
| 15 | Account A logout → B login → no A data leaks | Real secure-storage |
| 16 | Background 5 min → fingerprint required | `AppLifecycleObserver` + `local_auth` |
| 17 | App switcher hides content | `FLAG_SECURE` MethodChannel |
| 18 | Camera permission permanently denied → recovers | OS permission state machine |
| 19 | Notification permission asked once on Android 13+ | Version behaviour |
| 20 | Slow 3G via throttle | Real-world response times |

Plus the two timed runs the prosthetic brief explicitly demands:
- **T6.6:** stopwatch a prosthetic case creation from home to saved. Target < 2 minutes. Log it.
- **T7.7:** measure render time of the 13 first-load screens. Server side is 0.31 s; the phone render is what the clinic feels.

**Fix every failure. Re-run. Log the fix in the same entry.**

---

### B3. Fix the eight named P0/P1 source defects

These are the "confirmed source" findings from your own audit that directly violate a brief clause. Each has a specific fix and a specific test.

**P0-1. Offline write duplicates a committed server record**
- **Where:** `stock_repository.dart::_submitWrite`, `label_usage_repository.dart::recordUsage`, `cycle_repository.dart::_submitTransition`, `purchase_repository.dart::receive`.
- **Why:** The offline path calls `generateIdempotencyKey()` twice per operation — once at the online attempt, once at the outbox enqueue. If the online attempt committed but the response was lost, the retry uses a fresh key and creates a duplicate. Violates Cahier §8 "opérations transactionnelles et idempotentes."
- **Fix:** Generate the key once, before the first network byte. Pass it through both the direct call and the `OutboxItem`. Never regenerate.
- **Test:** Add a fault-injection test in `test/unit/storage/` that simulates "response lost after commit", then replays. Assert exactly one business row exists server-side.

**P0-2. `SyncEngine._syncOne` strands items forever**
- **Where:** `lib/core/storage/outbox/sync_engine.dart`.
- **Why:** Items are marked `syncing`, then `remove`d or reset to `pending`. If the app is killed between those two steps, the item sits in `syncing` forever and is invisible to `pending()` selection. Violates Cahier §8 "aucune suppression silencieuse d'une preuve."
- **Fix:** On `SyncEngine.start()`, sweep all `syncing` items older than 30 seconds and reset to `pending` with the **original key and body**. Never regenerate.
- **Test:** Persist a `syncing` item, restart the engine, assert it is picked up on the next flush with the same key.

**P0-3. Cycle item edit loses `batch_id` via delete-then-create**
- **Where:** `cycle_detail_screen.dart::_editItem`.
- **Why:** The old item is deleted, then a replacement is added. The replacement omits `batch_id`. If the create fails, the item is gone. Violates Cahier §8 "aucune suppression silencieuse d'une preuve" and breaks batch traceability — the entire point of the app.
- **Fix:** Use the existing `PATCH /v1/cycles/{id}/items/{item}` (already implemented backend-side and refused once the cycle left draft with `CYCLE_LOAD_LOCKED`). Preserve `batch_id` in the payload. Wire it in `CycleRepository` and cover with a test.
- **Test:** `test/unit/features/cycles/cycle_item_edit_test.dart` — edit description, assert item id unchanged and `batch_id` unchanged.

**P0-4. The scanner makes a destructive GET**
- **Where:** `GET /v1/labels/{code}` in `LabelScanController`, called by your scanner and by `nc_create_sheet.dart`.
- **Why:** A `labels.view` permission (granted to *every* role including viewer) mutates the label from `printed` to `used`. A passive lookup is a write. Violates the viewer role's read-only contract and consumes a valid label just from scanning.
- **Fix (backend):** Split into `GET /v1/labels/{code}` (pure read, returns metadata for any status including expired/recalled) and `POST /v1/labels/{id}/usage` (the existing explicit usage action, gated by `usages.manage`).
- **Fix (mobile):** Update `LabelRepository.getByCode` and the NC create flow to use the read endpoint. The blocked-label screen's `410` path becomes a normal `200` with `status: recalled`.
- **Test:** Backend — viewer lookup leaves status `printed`. Mobile — NC create against a recalled label succeeds without mutating state.

**P0-5. Foreign practitioner IDs are accepted on prosthetic cases**
- **Where:** `CreateProstheticCaseRequest.php:31`, `UpdateProstheticCaseRequest.php:35`.
- **Why:** Only global user existence is checked. A UUID from another tenant can be saved as `practitioner_id` and its name read back. This is a cross-tenant leak.
- **Fix (backend):** Validate practitioner is an active member of `$request->user()->tenant`. Reject foreign UUIDs with 422.
- **Test:** Backend feature test with two tenants; create case with foreign user, assert 422 and no case created.

**P0-6. Re-registering a practice can 403 another practice everywhere**
- **Where:** `spatie/laravel-permission` global cache, `BUG-026`.
- **Why:** Documented as fixed via `TenantPermissionRegistrar`, but the fix is in the working tree, not committed and not deployed. It must survive a container rebuild.
- **Fix:** Merge the fix, run `scripts/verify_authorization_matrix.py`, rebuild the container, re-run. Only then close.
- **Test:** `PermissionCachePerTenantTest` (already written) + live script.

**P0-7. Data export silently drops duplicate-named files**
- **Where:** `GenerateDataExportJob.php:96`.
- **Why:** Two attachments with the same filename overwrite each other in `files/{file_name}`. Export is a legal/GDPR artifact; losing a file silently violates Cahier §8.
- **Fix:** Prefix the stored name with the media ID. Add a manifest with checksums. Fail the job if `put` returns false.
- **Test:** Backend feature test creating two same-named photos; download export; assert both present.

**P0-8. Cycle creation allows a program from another device**
- **Where:** `CreateCycleRequest.php:28`, `CreateCycleAction.php:38`.
- **Why:** `device_program_id` is validated only by tenant. A program belonging to device B can be attached to a cycle for device A. Traceability is false.
- **Fix:** Validate `$program->device_id === $request->device_id` and `$program->is_active`. Reject with 422.
- **Test:** `CycleCreationRulesTest` — cross-device rejection, inactive program rejection.

---

### B4. Deploy a staging environment with HTTPS

**Why:** `Env.assertSecureTransportInProduction()` makes the app refuse `http://` in production. All your API tests are against `localhost:8010`. The presigned URL fix works on dev but was never verified on staging. The demo the Cahier §10 requires happens on staging.

**Checklist:**
1. DNS: point `API_DOMAIN` and `STORAGE_DOMAIN` at a real host.
2. Populate `.env.staging` from `.env.staging.example` — replace every `CHANGE_ME`.
3. Set `AWS_PUBLIC_ENDPOINT_MEDIA` and `AWS_PUBLIC_ENDPOINT_BACKUPS` to `https://<STORAGE_DOMAIN>`.
4. `docker compose -f docker-compose.staging.yml --env-file .env.staging up -d`.
5. Run migrations once with admin role: `RUN_MIGRATIONS=true`.
6. Verify from a phone on the LAN: `GET /docs/api.json` returns 200 over HTTPS.
7. Verify: upload a real photo through the API, copy the returned URL, open it from the phone. Bytes must match.
8. Set `MIN_APP_VERSION` above the current build, restart, confirm the app shows "Mise à jour requise".

---

### B5. Cut a signed release build

The application ID `com.sterymed.mobile` is provisional. It becomes permanent at first Play upload.

**Owner inputs needed (in writing, from the project owner):**
- Final `applicationId` (or explicit confirmation of the provisional one).
- Android upload keystore (`.jks`) + alias + passwords, stored in the *owner's* password manager.
- Google Play developer account (clinic-owned, not personal).
- Play App Signing enrolment.
- Production API base URL.
- Sentry DSN.

**Then:**
1. Add the four `ANDROID_KEYSTORE_*` secrets to the GitHub repo.
2. `mobile-release-android.yml` already builds an obfuscated AAB from a tag — tag `v1.0.0` and push.
3. Download the AAB and the symbols artifact.
4. Upload to the Play **internal testing** track.
5. Install on the physical test device. **Verify it upgrades over the debug build with a pending outbox item without data loss.**

---

### B6. Run the six Cahier journeys end-to-end on the phone against staging

This is the actual acceptance demo. Record each journey as a video, and log the result.

1. Create clinic → admin + assistant with different rights.
2. Create product + supplier → order → receive lot with expiry.
3. Print label on web → scan on mobile → record exit → verify no double-count.
4. Create + validate sterilization cycle; keep controls, attachment, operator.
5. Trigger stock/expiry alert → consult audit → export report.
6. Verify the same data on web and mobile.

**Pass criteria:** all six complete on a real device against staging, with no hidden fake data, and no critical anomaly. Anything else is a bug to fix.

---

## Part 2 — HIGH-PRIORITY ITEMS (Clinic Will Notice)

### H1. Replace every "silent zero" with an honest state

The dashboard currently turns a failed API call into `0` on KPIs and empty lists. That is clinically dangerous — a nurse seeing "0 alerts" when the fetch failed misses a real alert.

**Files:** `dashboard_remote_datasource.dart:102-107`, `alert_list_screen.dart:71`, `audit_list_screen.dart:157`, `evidence_search_screen.dart:162`, `stock_level_list_screen.dart:64-65`.

**Fix:** Introduce a `Unavailable` value distinct from `0` and from `Empty`. Show "Indisponible — réessayer" on the widget. Add a test in `dashboard_honesty_test.dart` for a 500 response asserting the KPI does NOT show `0`.

### H2. Persist prosthetic filters across a case open/close

Prosthetic brief §10 is explicit: "Filters must work together and persist while the user opens a case and returns to the list."

**Files:** `prosthetic_case_list_bloc.dart`, `prosthetic_remote_datasource.dart:47-48`.

**Fix:** Move filters into BLoC state, forward them through `loadMore`, add a request-generation guard so a late response from an old filter set never overwrites a newer one. Test: apply patient + lab + status → open case → back → filters intact.

### H3. Make the waiting-for-placement list count the whole result, not the loaded page

Aging buckets (0-7/8-14/15+) currently count only rows fetched so far. On a clinic with 200 waiting cases, the "urgent 15+" count is wrong.

**Fix (backend):** The `GET /prosthetic-cases/waiting-placement` already has a full-result query; expose aging bucket totals alongside the page. Or compute `daysElapsed` in the DB and add a `filter[aging]` param.
**Fix (mobile):** Display server-provided totals on the bucket chips.
**Test:** Create 150 waiting cases across all three buckets; assert the KPI chips match truth.

### H4. Complete the small-screen / large-text pass

Your `layout_resilience_test.dart` covers 320×568 at 130%. Extend to 320×568 at **150%** and to a real device with system font scaling set to "largest." Any text truncation on the Scanner, Alert list, or Cycle Detail is a fix.

### H5. Wire the "journey 5" acceptance demo — alert → audit → export on device

The file must be opened on the phone from the Downloads folder. Not just "the URL returned 200." Log it in `DEVICE_TEST_LOG.md`.

### H6. Flesh out the User Guide

`docs/USER_GUIDE.md` currently has 19 `[Capture d'écran : ...]` placeholders. This is the primary deliverable for clinic staff. Take real screenshots on the phone and insert them. Add one page per role listing what that role sees.

### H7. Close the "invoice" gaps that will feel broken in a clinic

- **`P2` from the audit:** the payment block accepts `12,50` as French but sends `null` on malformed input. A receptionist typo silently wipes the amount. Add validation and a visible error.
- **`P3`:** remaining balance can show "Paiement à jour" when unknown. Distinguish `0 €` from `—`.
- **`I02`:** purchase-order edit has no backend endpoint. Either build it or remove the affordance. A "edit" button that 404s is worse than no button.

---

## Part 3 — MEDIUM ITEMS (Polish)

1. **Delete dead code** confirmed by the audit: `CycleItemsScreen`, `CycleControlTestsScreen`, `CycleReleaseScreen`, `RecentProceduresCard`, `CycleTile`, `TransitionConfirmDialog`, and the four stock blocs never constructed by a screen. Dead code in a delivered repo is an unfinished signal.
2. **Rename the five phantom test files** (`goods_receipt_bloc_test.dart` etc.) to match what they actually test (`*_flow_test`).
3. **Register the Inter font** in `pubspec.yaml` as a `fonts:` family, not just an asset. Otherwise the app renders in Roboto and every golden is stale.
4. **Rename/remove the `dentistrack_auth_bg.jpg`** — leftover from another project.
5. **Replace the placeholder launcher icon** with the real SteryMed mark.
6. **Regenerate goldens on Linux** or mark them `@TestOn('windows')` so CI does not fail on the platform mismatch.
7. **`.gitattributes` renormalization** for LF endings once, so Windows dev → Linux CI does not fight.
8. **Delete `_script_backups/`** and any tool-generated artifacts from the working tree.
9. **Fix the `flutter drive` connection** on your machine — the 8 integration journeys are written but have never been executed. This is the largest single testing gap. If Chrome is the problem, run them on the physical device with `flutter test integration_test/journeys/...`.

---

## Part 4 — WHAT THE CAHIER AND BRIEF STILL REQUEST THAT DOESN'T EXIST

Everything else in the briefs is built. Two small items are genuinely absent:

### 4.1 Receipt photo endpoint on mobile

The backend has `POST /goods-receipts/{id}/attachments-base64` (verified live). Mobile has no caller. The photo upload is a **mandatory MVP feature** per Cahier §4 (Purchases & lots: "Receipt, proof photo, lot/expiry"). Wire it in `GoodsReceiptScreen` — after the receipt is confirmed, prompt for a photo, upload via the base64 endpoint, show progress, allow retry.

### 4.2 Practice software connector — mock or real

Cahier §4 lists "Connector if access exists, otherwise documented mock." Phase 0 decision **D09** is still open. Either:
- Document the mock in `docs/CONNECTORS.md` and expose a clearly-labelled "demo connector" screen, or
- Get real sandbox credentials from the owner and build one.

Leaving this blank is worse than a labelled mock.

---

## Part 5 — WHAT'S ALREADY EXCELLENT (Don't Touch)

For confidence, these are done and correct:

- Layering, DI split, `CursorPage<T>`, error mapper, `RoleGuard`, shared widget kit.
- Backend prosthetic domain — migrations, models, actions, policies, controllers, RLS, live routes.
- Six-role permission matrix — enforced server-side and reflected mobile-side via `RoleGuard`.
- Offline outbox with durable command records, single serialized worker, HTTP 409/422/403 routing to manual review.
- Idempotency middleware with per-tenant cache isolation (`TenantPermissionRegistrar`).
- CI: analyze `--fatal-infos`, tests, coverage floors, Android release workflow, iOS as manual placeholder.
- The `docs/` folder itself — `ANOMALIES.md`, `CLINIC_READY_MASTER_PLAN.md`, `OFFLINE_MATRIX.md`, `ROLE_MATRIX.md`, `API_CONTRACT.md`, `BACKEND_BUGS.md` are all evidence of an engineer who thinks like a senior.

---

## Part 6 — SUGGESTED SEQUENCE (Two to Three Weeks)

**Week 1 — Commit and device**
- Day 1: B1 (commit tree, rotate key).
- Day 2-3: B2 (device matrix — fix what breaks).
- Day 4-5: B3 P0-1 to P0-8 (fix + test + re-run device).
- Day 6-7: H1 (silent zeros) + H4 (large text pass).

**Week 2 — Staging and release**
- Day 1-2: B4 (staging live, HTTPS, media URLs verified from phone).
- Day 3-4: B5 (signed release, Play internal testing, upgrade with pending queue).
- Day 5: B6 (six journeys on device against staging, recorded).
- Day 6-7: H2, H3, H5, H7 + Part 3 deletions.

**Week 3 — Polish and handoff**
- Day 1-2: H6 (user guide with real screenshots).
- Day 3: 4.1 (receipt photo) + 4.2 (connector decision).
- Day 4: Final acceptance rehearsal; anomaly report — zero open blocking/critical.
- Day 5: Handoff — code, access, docs, demo recording, written acceptance signed by named clinic representative.

---

## Part 7 — THE 10/10 CHECKLIST (Copy into an issue tracker)

```
[ ] B1  Tree committed; key rotated; graphify/aider backups gitignored
[ ] B2  20 device scenarios logged in DEVICE_TEST_LOG.md
[ ] B2  T6.6 stopwatch < 2 min; T7.7 screen times recorded
[ ] B3  P0-1 Offline key generated once per intent
[ ] B3  P0-2 Syncing items recovered on restart
[ ] B3  P0-3 Item edit uses PATCH, batch_id preserved
[ ] B3  P0-4 Label GET is pure read; NC uses it
[ ] B3  P0-5 Foreign practitioner rejected
[ ] B3  P0-6 Permission cache per tenant verified live
[ ] B3  P0-7 Export preserves same-named files
[ ] B3  P0-8 Cross-device program rejected
[ ] B4  Staging HTTPS reachable from phone
[ ] B4  Photo and export URLs open from phone
[ ] B4  MIN_APP_VERSION gate demonstrated
[ ] B5  Signed AAB uploaded to Play internal testing
[ ] B5  Upgrade over debug build with pending queue, no loss
[ ] B6  Six Cahier journeys recorded on device against staging
[ ] H1  No silent zeros anywhere
[ ] H2  Prosthetic filters persist across case open
[ ] H3  Waiting-for-placement totals come from server
[ ] H4  150% text pass on small screens
[ ] H5  Journey 5 file opens on phone
[ ] H6  User guide has 19 real screenshots
[ ] H7  Payment parse validation; "unknown" vs "0"
[ ] P3  Dead code removed; phantom tests renamed
[ ] P3  Inter font registered; icon replaced
[ ] P3  Goldens tolerant of Linux; .gitattributes fixed
[ ] 4.1 Receipt photo wired on mobile
[ ] 4.2 Connector mocked or built, documented
[ ] FIN Anomalies: zero blocking, zero critical
[ ] FIN Written acceptance signed by clinic
[ ] FIN All access handed to owner (repo, cloud, Play, keystore)
```

When every box is ticked, you have a 10/10 deliverable — not because the code is perfect, but because every claim is proven, every defect is closed with evidence, every access belongs to the owner, and a named clinic representative has signed off on a build that actually runs on the phone the nurse will hold.

You are extraordinarily close. The distance between 7.5 and 10 is measured in days of disciplined verification, not weeks of coding. Plug in the phone today.