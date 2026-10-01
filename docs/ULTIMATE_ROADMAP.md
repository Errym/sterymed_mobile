# SteryMed: rating and ultimate roadmap to a clinic-safe product

**Written 1 October 2026 by a senior-mobile-engineer review of both repositories and both `pjdocs` documents.**
This file answers three questions: *where are we, how good is it honestly, and what exact sequence gets a clinic to use it safely.*
It sits on top of [`CLINIC_READY_MASTER_PLAN.md`](CLINIC_READY_MASTER_PLAN.md) (task IDs S/O/R/C/I/P/A/V/D/H, findings F01–F18) and does not replace it: the master plan is the **task catalogue**; this file is the **schedule, scorecard and gates**. Evidence for every finding is in [`SOURCE_AUDIT_FINDINGS.md`](SOURCE_AUDIT_FINDINGS.md).

---

## 1. What the product is (from `pjdocs` and the backend)

**Goal.** A multi-tenant SaaS for dental practices: sterilization **traceability** plus **stock** control, usable on the web (administration, label printing) and on a Flutter mobile app (scan, use, receive, validate, consult). Core loop, taken from the backend brief (`steriqore/CLAUDE.md`) and the *cahier des charges*:

> receive stock (lot + expiry) → prepare a load → run an autoclave cycle → record control tests → an authorized user **releases** the cycle → one unique 2D label per pouch → **scan at the chair** → link pouch → cycle → device → practitioner → patient reference → inspection-ready evidence.

Second module (prosthetic brief): track a dental-lab case from impression to placement, with status history, a "waiting for placement" list, a payment block, attachments and a dashboard where every card opens a filtered list.

**Non-negotiables the documents impose** (these define "safe" for this project):

| Rule | Source |
|---|---|
| A clinic can never read or change another clinic's data | Cahier §8, backend tenancy + RLS |
| No silent deletion of proof; corrections carry actor, time, reason | Cahier §8, backend invariants 3 and 7 |
| Double tap, double scan, lost network never double-count a stock movement, receipt or validation | Cahier §8 and §10 |
| Stock is derived from an append-only ledger, never set directly | Backend invariant 1 |
| No label for a cycle that is not released and compliant; a recalled or expired label returns a blocking error | Backend invariants 2 and 5 |
| Permissions enforced on the server, not only hidden in the UI | Cahier §8 |
| GDPR/HDS analysis **before any real patient data** | Cahier §8 |
| "Not delivered unless demonstrated and tested" | Cahier §10 |

**The backend (`steriqore`) is the stronger half.** Laravel 13, PostgreSQL 18 with row-level security as a second tenancy wall, append-only evidence tables with DB triggers, mandatory idempotency middleware, spatie permission/activity-log/backup, 94 API routes that exactly match `docs/openapi.yaml`, 33 permissions with zero dead grants, 77 test files, 56 migrations, scheduled alerts and backups. Its gaps are specific (see §3), not structural.

---

## 2. Honest rating

Scale: 10 = a clinic can rely on it today. Scores are my judgement from reading the source and docs and from running the checks below; they are not measurements.

| Dimension | Score | Why |
|---|---|---|
| **Feature breadth vs. the two briefs** | **8.0** | All seven MVP modules and the whole prosthetic lifecycle have screens, repositories and routes: auth, catalog, suppliers, purchase orders and partial receipts, stock movements, devices, cycles, controls, release, labels, scanner, usage, non-conformities, alerts, audit, evidence search, exports, prosthetic dashboard/cases/waiting/payment/PDF. This is the "8.6 out of 10" number, and it is a breadth number. |
| **Architecture and code quality** | **7.5** | Clean feature folders, BLoC + repository + GetIt + Dio, interceptors for auth/retry/idempotency/errors, a typed `ApiEndpoints` contract test, 37k lines in 425 files. Several routed paths bypass it (setState plus direct repository calls instead of the blocs the tests are named after). |
| **Write safety and offline** | **4.0** | The riskiest area. Per the audit: replays generate a *new* idempotency key on online failure (duplicate after lost response, F02); the sync worker can overlap and strands items killed mid-sync (F03); queued requests use whichever token is current (F01). Only 6 operations queue at all; every other write throws offline. Documented in OFFLINE_MATRIX; the repair is Phase 2. |
| **Security, session and privacy** | **4.5** | Good bones (secure token storage, PII scrubbing, no leaked secrets in 55 commits, role guard). But caches, drafts and the outbox are **not scoped to the user/tenant**, so account A's pending work can be replayed under account B (F01). Local payloads are unencrypted (F15; an encrypted `secure_box.dart` is now in progress). Backend: prosthetic `practitioner_id` is validated against *all* users, not the tenant (F06, confirmed in `CreateProstheticCaseRequest.php:28`). |
| **Clinical correctness** | **4.5** | Two P0s confirmed in code: a **passive label lookup consumes the label** (`ResolveLabelScanAction.php:63` marks it `Used` on a GET, so a viewer or a mere look burns a pouch), and editing a cycle item is delete-then-create and loses the batch link (F04). The release detail does not load the stored decision (F10). |
| **Backend contract completeness** | **6.0** | Mobile calls `POST /v1/auth/forgot-password`, which **does not exist** (only web Fortify). No `GET locations` / `GET batches`, so a brand-new clinic **cannot receive its first delivery on mobile** (F09). No receipt-photo route, no atomic cycle-item update, no prosthetic print/export, presigned URLs point at the internal Docker host (BUG-010). |
| **Test evidence** | **5.0** | Real and honest in places (409 replay proven live, contract tests, role-matrix test). But: LCOV line coverage was **34.5%**; **12 of 18** `integration_test` files are 0 bytes; several wire fixtures are mocked in shapes the backend does not emit; the unused-screen tests inflate the count. **Fresh run today: 488 pass, 13 fail** (sync status cubit, cycle detail screen, leak check, export download, crash scrub, error-code contract); analyzer shows 1 warning. The working tree is mid-refactor and red. |
| **Real-device proof** | **1.0** | `DEVICE_TEST_LOG.md` has zero logged runs. One full-lifecycle run on 2026-09-24 is the only physical evidence. Nothing on iOS. Offline, kill/relaunch, reconnect and dual-client coherence are unproven end to end. |
| **Release and operations** | **2.5** | Application ID is still `com.example.sterymed_mobile`; release signing is guarded but unconfigured; **no iOS `Podfile`**, so iOS cannot build; both release pipelines are skeletons; no TLS/domain/staging decision (backend OQ-10); production compose does not exist; restore never rehearsed end to end. |
| **Documentation** | **6.5** | Plentiful (35+ files) but **contradictory**: `PILOT_READINESS.md` says "conditional GO", while the 1 October source audit shows 18 blockers. Cleaned on 1 October: the superseded verdict and never-filled skeleton docs were deleted. |

### Overall

| View | Score |
|---|---|
| Feature completeness against the briefs | **8 / 10** |
| **Safe for a clinic to depend on today** | **≈ 4.5 / 10** |
| Realistic after Milestone M2 below (supervised pilot, test data) | ≈ 7.5 / 10 |
| After M3 (clinic production) | 9+ / 10 |

**One-sentence verdict:** it is a broad, well-structured app that demonstrates the whole product, but today it can still duplicate a write, replay one user's work under another, burn a clinical label by looking at it, and cannot onboard an empty clinic or recover a password, and none of that has been proven on a real phone. Nothing here needs a rewrite. It needs a sequence of repairs, then proof.

---

## 3. Requirement coverage against the two briefs

Legend: ✅ works as specified · 🟡 exists, with a blocker listed · ❌ missing.

### Cahier des charges MVP (§4 mandatory modules)

| Module | Mobile requirement | Status | Blocking issue (master-plan ID) |
|---|---|---|---|
| Account and security | Secure login, persistent session by role | 🟡 | Session not fenced; late 401 can clear a new login (S01); no password recovery API (R05); no inactivity lock (X03) |
| Catalog | Search, product page, quick add, 2D scan | 🟡 | Scanner resolves **labels only**, no product/batch code lookup (I01) |
| Stock and movements | Scan in/out, quantity, reason, weak network | 🟡 | Queue unsafe under lost response (O01); more than 100 stock rows and unused locations unreachable (R03, I01) |
| Purchasing and lots | Receipt, **proof photo**, lot/expiry, orders | 🟡 | Empty clinic cannot pick a first location (F09); no receipt photo contract (I03); lot invented from a timestamp (I02) |
| Sterilization | Guided cycle, validation, photo/report, history | 🟡 | Item edit loses batch (C01); release decision not loaded (C02); attachments disabled in UI (BUG-001 caller never built) |
| Labels and scan | Scan, view lot/cycle, record use | 🟡 | GET consumes label (C03); reprint can revive a used label (C04) |
| Monitoring | Alerts, short indicators, filterable history | 🟡 | Dashboard errors shown as zeros (A01); alert resolve errors hidden (A02); no delivered notification channel (A02) |
| **Inventory counts ("inventaire")** | Cahier lists inventories under stock manager and monitoring | ❌ | No backend domain at all (backend OQ-12). The master plan flags the decision; this roadmap makes it an explicit gate (X01) |
| Exports CSV/PDF | Export report | 🟡 | Same-filename attachments overwrite each other in the archive (A04); filtered evidence export not wired (A03); media URLs unreachable (BUG-010) |

### Prosthetic brief (§15 acceptance criteria)

| Criterion | Status | Gap |
|---|---|---|
| Create a complete case in under 2 minutes | 🟡 | Form exists, drafts race (P05); practitioner/lab lookups incomplete (P01); **never timed with a real user** (P06) |
| Track status + all previous transitions | ✅ | Lifecycle and history exist; needs concurrency-safe transitions (P06) |
| Find by patient/practitioner/lab/type/status/period, filters combine and persist | 🟡 | Filters lost on page 2 (F11, P02) |
| Waiting-for-placement with correct elapsed days | 🟡 | Aging only over the loaded page (P02) |
| Reception verifies deposit/balance/payment | 🟡 | French decimal input can clear money fields (P03) |
| Dashboard cards open the filtered list | 🟡 | Drill-downs must match counts (P02, A01) |
| Audit user + time + before/after | ✅ | History exists; immutable DB trigger missing (P06 note) |
| Responsive web, quick mobile updates | 🟡 | Mobile fine; attachments not viewable (P04) |
| Secure file access | 🟡 | Unrestricted URL risk on media host; presigned host wrong (BUG-010, D02) |

**Scope decision kept:** the app stores a pseudonymous patient *reference*, not names (ADR 0011). The PDF's name examples do not authorize adding identifiable data. This keeps the GDPR/HDS risk low and should stay.

---

## 4. The plan in one picture

Seven principles shape the sequence:

1. **Safety before features.** The app already has the features. Fix duplicate, wrong-actor and evidence-loss risks first (P0), then unblock journeys (P1).
2. **Contract before client.** Every mobile workaround for a missing endpoint is deferred until the backend contract is agreed. No success-looking form pointed at an absent route.
3. **Backend track runs in parallel from week 1.** Seven of the P0/P1 items are server defects that no mobile change can fix.
4. **Each change ships with its regression test**, not in a final testing phase.
5. **Prove with the exact bytes.** The release candidate APK/IPA, on the real phone, against staging with a restricted DB role, through the intended distribution channel.
6. **Real patient data only after the legal gate.** Test data until X04 is signed off.
7. **No ✅ without a citable artifact** (the project's existing no-fabrication rule stays).

### Three milestones (so "done" is never vague)

| Milestone | Meaning | Data allowed | Target |
|---|---|---|---|
| **M1: Safe to demonstrate** | All P0 closed with regression tests; tree green; demo journey runs on a real Android phone | Fake/demo data | end of week 5 |
| **M2: Supervised pilot** | P0 + P1 closed; all six roles verified; offline matrix proven on device; signed Android build on the owner's account; staging with TLS and restored backup | Test data in the clinic, staff watching, paper process still running in parallel | end of week 12 |
| **M3: Clinic production** | Every gate in §9 passes on the candidate build; written acceptance by a named clinic representative; support owner named | Real patient references, after X04 | end of week 17 |

Estimates assume what the cahier assumes: **two people (one mobile, one backend/web) at 20–25 h/week**, decisions made within days, scope frozen. If either person has less time, multiply. Phases overlap (see the Gantt below); the critical path is S → O → C → V → D → H.

```
Week:        1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17
P0 contract  ███
P1 session       ██████
P2 durable           ████████
P3 setup (J)             ██████
P4 clinical                  ██████████
P5 inventory                         ██████████
P6 prosthetic                    ████████
P7 trust UX                              ██████████
P8 proof     ·   ·   ·   ·   ░░░░░░░░░░░░░░░░░░░████████ (continuous, final weeks 11–14)
P9 release   ░░░░ (starts wk1: signing, Mac)           ██████████
P10 accept                                                     ██████████
Backend track ████████████████████████████████ (F05–F07, idempotency, lookups, export, deploy)
             |------- M1 ------|            |----- M2 -----|                  |--- M3 ---|
```

---

## 5. Phase-by-phase roadmap

Task IDs refer to the master plan. For each phase: goal, what changes, first concrete steps, the proof that closes it, and the main risk.

### Phase 0: Freeze the truth and make validation repeatable (week 1, parallel with 1)

**Goal.** Stop building on a moving, red tree and settle every cross-team decision.

| Step | Detail |
|---|---|
| 0.1 | **Get green.** The tree today has 13 failing tests and 1 analyzer warning, with ~86 modified files (many are CRLF line-ending noise; `.gitattributes` already added). Triage the 13: decide per failure whether the test or the in-progress refactor is wrong. Commit the in-progress work (secure box, queue harness, fixtures) in reviewable slices. **Never "make it pass" by resetting the queue.** (G04) |
| 0.2 | **Fingerprint** the two checkouts, toolchain (Flutter 3.47.2, Dart ≥3.12) and staging URLs; pin them. (G02) |
| 0.3 | **Decision workshop with the clinic owner (45 min, written outcome).** Seven decisions, each with a named owner (G01): practitioner eligibility; clinical release prerequisites (which controls must pass); DLU rule authority; **inventory count scope (X01)**; notification channel (push, email, in-app); owner/admin policy (can an admin invite an owner? last-owner guard); which connector or the documented mock. |
| 0.4 | **Open backend tickets** (J/B) for F05, F06, F07, F17, F18, idempotency (O04), lookup endpoints (R03), atomic item update (C01), receipt photos (I03), password recovery (R05), media URL host (BUG-010). Each ticket gets acceptance text from the master plan. |
| 0.5 | **Disposable fixtures (G03):** two tenants × six roles, empty clinic, populated clinic, > 1 page of data, all cycle/label/prosthetic states, duplicate attachment filenames. A fixture refuses to run against a database that does not carry a `TEST_ENV` marker. |
| 0.6 | **Start long-lead items now** (they block M2/M3 and cost weeks of calendar, not effort): borrow or rent a Mac for the iOS archive; create the owner's Google Play and Apple developer accounts; generate and escrow the Android upload keystore; pick hosting and the domain; order a **label printer test sample**. |

**Proof.** `flutter analyze --fatal-infos` clean; `flutter test` 0 failures with the log stored; decisions document signed; fixtures re-creatable with one command.
**Risk.** Decisions slip. Mitigation: each unresolved decision falls back to the master plan's stated safe default and is logged.

### Phase 1: Protect sessions, local data and diagnostics (weeks 1–3) — closes F01, F08, F15

**Goal.** Two accounts on one phone can never see or replay each other's data; a restart never loses or exposes anything.

Work order (S01 → S02 → S03 → S04 → S05 → S06):

1. **Session lifecycle object** with `(environment, tenant, user, generation)`. Every dispatched request carries the generation; a response from an older generation is dropped. Logout clears local state *before* the slow server revoke. Regression test: A logs in → request in flight → logout → B logs in → A's late 401 arrives → B is still logged in (S01).
2. **Boot that never blocks or crashes.** First frame renders without waiting for queue replay; corrupt storage becomes a recoverable "needs attention" screen. Invalid credentials vs. offline vs. server error are three different restore outcomes (S02).
3. **Owner-scoped encrypted storage.** Finish the in-progress `SecureBox` (`lib/core/storage/secure_box.dart`): per-box AES key in secure storage, legacy plaintext boxes **quarantined, never silently wiped or assigned to the next login**, key-loss yields a recovery state. Migrate drafts, outbox and clinical caches (S03).
4. **Typed cache keys** that include the owner; fix the `devices` key collision (device list vs. device detail model) that can throw on navigation; invalidate dashboard/list caches after confirmed writes (S04).
5. **Structured diagnostics.** Allow-list logging; redact tokens, ids, query strings, nested payloads; normalize errors once (S05).
6. Connectivity subscription ownership, resume check, version metadata (S06).

**Proof (V03 subset).** A→logout→B with delayed requests; kill during migration; upgrade from the previous build with pending items; missing key; token never present in any captured log or Sentry event (inspect real event objects).
**Risk.** Migration bugs destroy pending offline work. Mitigation: migration is copy-then-flush-then-verify-then-mark; plaintext is removed only after a read-back match; test against a recorded legacy box.

### Phase 2: Durable writes and honest synchronization (weeks 3–6) — closes F02, F03

**Goal.** For every mutation, "success" means exactly one business effect, including after crash, timeout-after-commit, double tap and reconnect.

1. **One durable operation per intent, created before the first send** (O01): immutable id/key, original event time, canonical body, method/path, owner scope, schema version. Online sending and offline replay use *the same record and the same key*. Delete the interceptor behaviour that mints a fresh key on retry.
2. **Single serialized worker** (O02) with startup recovery of items stuck in `syncing`, persisted backoff, per-resource ordering (a cycle's start must precede its complete), auth-pause when the session is invalid.
3. **Explicit queue states** (O03): pending, sending, unknown outcome, auth-blocked, conflict, validation-failed, confirmed. Deleting an unresolved item shows a loss-aware confirmation.
4. **Server side (B/J) (O04):** make the idempotency middleware concurrency-safe (two identical keys racing), scope the key by tenant + endpoint + body hash, and decide what happens after the 24 h replay window: an old uncertain operation shows "outcome needs checking" and is reconciled against the business record, **never blindly re-sent under a fresh key**.
5. **Clinical time** (O05): `used_at` is captured at the moment of use, not at the moment of replay.
6. **Truthful sync UI** (O06): counts include in-flight and blocked items; no green "synchronized" while work is unresolved. The existing sync pill is reused, not rebuilt.

**Proof (V03 core).** Deterministic fault injection with real server counts: response lost after commit → one stock movement; two concurrent sends → one; kill between persist/send/ack → one; reconnect with reordered events; 401/403/409/422/429/5xx each leave a correct record and an understandable state. Assertions read **server-side counts and stock deltas**, not just the response body.
**Risk.** Largest single change in the plan. Mitigation: ship behind the existing `OutboxOperation` API; migrate one operation type at a time starting with `stockIssue`; keep the live idempotency contract test (already passing) as a tripwire.

### Phase 3: Role-correct clinic setup and complete lookups (weeks 5–8)

**Goal.** An empty clinic can be provisioned on web and receive its first delivery on mobile; each of the six roles can do exactly its own work.

1. **Backend lookups (R03, B):** `GET locations`, `GET batches` (complete, paginated, unused locations included), a minimal eligible-practitioner list that does **not** require the invitations permission.
2. **Tenant-safe practitioner assignment (R02, B):** replace `Rule::exists('users','id')` with a tenant-membership + eligibility rule in create/update/usage requests. Add last-owner and self-disable guards. Test foreign, disabled and archived ids through direct API calls.
3. **Mobile consumption (R03/R04):** replace the "derive pickers from the first stock page" mitigation (BUG-002/003) with real lookups; async pickers; archived selections remain visible; nullable PATCH clears; locale-safe validation.
4. **Account recovery (R05, J):** choose one of two designs and finish it. (a) Add `POST /v1/auth/forgot-password` and `/reset-password` that reuse Fortify's broker, with a deep link back into the app; or (b) open the existing web recovery page and return to login. Do not ship the current form (it calls a route that does not exist).
5. **Permissions audit (R01):** every routed screen and action against the six-role table, including deep links, camera use, exports, and mixed clinical/payment prosthetic patches (send only the authorized fields).

**Proof.** The empty-clinic fixture becomes a standing acceptance test. `V01` matrix: six roles × (UI, direct route, direct API, permission-changed-mid-session).
**Risk.** Role names or grants drift between seeder and deployed tenants. Mitigation: verify real `/me` responses on staging; add a reseed step to deployment.

### Phase 4: Finish sterilization, label use and traceability (weeks 6–10) — closes F04, F05, F10

**Goal.** The full chain *prepare → load → controls → complete → submit → release → print → scan → patient use → evidence* is correct with server read-back.

1. **Passive vs. active label lookup (C03, B/J).** Split `GET /labels/{code}` (pure read, safe for viewers and incident selection) from an explicit `POST …/use` command. Remove the `Used`/`Expired` mutation from the GET path. This is the highest-value single backend change in the plan.
2. **Reprint rules (C04).** A reprint requires a reason, increments the counter, and **cannot move a Used/Expired/Recalled label back to Printed**. Render the selected format; validate DataMatrix and QR on the real printer and a real reader.
3. **Cycle items (C01).** Add `PATCH /cycles/{id}/items/{item}` (atomic, preserves item id and batch id, only in an editable state), or restrict editing explicitly. Delete-then-create is removed.
4. **Release evidence (C02).** Load `GET /cycles/{id}/release`; show decision, reason, actor, time; per-section evidence states ("could not load" is never rendered as "no evidence"); full image/PDF viewer; releaser can read what they must sign.
5. **Guided creation (C05)** filtered to active devices/programs belonging together (server validates that the program belongs to the device); concurrency recheck under lock before start/release.
6. **Scanner robustness (C06).** Camera permission and resume, manual fallback, one lookup per scan intent, a network error is never shown as "unsafe label", usage history failure never says "no usage".
7. **Non-conformities (C07):** searchable subjects, resolution, recall handoff.
8. **Attachments (BUG-001 caller).** Build the missing mobile caller for the working base64 endpoint with progress and retry; or keep the screen disabled and drop it from M2. Decision logged.

**Proof.** Journey `J-STERIL`: two roles, real device, real printed label, scan, usage, evidence export; then the negative set: rejected cycle (no labels), recalled label (410 + audit), expired label, used label, duplicate use, viewer scan (no state change).
**Risk.** Clinical rule ambiguity. Mitigation: decisions from Phase 0; do not invent regulatory durations.

### Phase 5: Complete inventory and purchasing (weeks 8–12)

**Goal.** An empty clinic orders, receives (partially, then fully), scans, moves and consumes stock with correct lots and no duplicate deltas.

1. **Scan modes (I01):** product/batch code lookup endpoint (agreed in Phase 0) and scanner mode switch (label / product); constrain source location + batch + available quantity; valid transfer destinations only.
2. **Receipt validation (I02):** positive quantities, remaining quantity, locale prices, a *manufacturer* lot and expiry captured from the user, never a timestamp-invented lot.
3. **Receipt photo (I03):** backend route + mobile capture/upload with progress and retry; define the case where the receipt commits but the photo upload fails (the receipt is not rolled back; the missing proof is a visible task).
4. **Draft order edit/cancel, receipt history, supplier detail (I04).**
5. **Stock correctness under concurrency (I05):** expired/recalled/insufficient stock; two operators; retries; pending change shown separately from confirmed balance; archived site/location containing stock must transfer or block.
6. **X01, inventory counts** if the clinic confirms it is required for the pilot: design the count session (open, count lines, close, generate Adjustment movements through the existing ledger action) as a backend-first feature; otherwise record the exclusion in the written acceptance so the cahier line is not silently dropped.

**Proof.** `J-STOCK` journey with server read-back of ledger deltas; partial receipt then completion; lost response mid-receipt → one movement.

### Phase 6: Prosthetic work (weeks 6–9, runs in parallel with Phase 4)

**Goal.** The prosthetic acceptance criteria pass with the real team.

P01 tenant-valid lookups; P02 filters preserved across pagination/refresh/back and race-safe, KPI drill-downs equal their counts, aging uses the server's agreed date/timezone over the full result; P03 French decimals, non-negative amounts, never turn malformed input into a null PATCH, non-blocking warning before "Placed"; P04 open/download attachments, camera/gallery/document, expired URL recovery, PDFs that paginate; P05 durable drafts including dates/selectors, awaited save-submit-clear, stale id validation; P06 lifecycle with concurrency-safe transitions plus the append-only DB trigger for history.

**Proof.** A real receptionist and a real practitioner create a case in under two minutes (stopwatch recorded), move it through impression → sent → received → scheduled → placed, with a payment outstanding warning and a cancel/restart, and find it with combined filters.

### Phase 7: Trustworthy monitoring, records and everyday UX (weeks 9–13)

A01 dashboard counts that distinguish **unavailable / stale / zero**; A02 alert resolve with per-id state and code-specific errors, plus the **core notification channel with delivery proof** (decision from Phase 0); A03 audit/evidence search without first-load failures, with the filtered export wired; A04 export archives with unique paths and manifest/checksum (fixes F07), failure and expiry handling; A05 shared list/search semantics, small screens, large text; A06 connector or labeled mock, accurate About/privacy/help text.

**X02, minimum-version gate (new, small).** `GET /v1/me` or a header returns `min_supported_app_version`; the app shows a blocking "update required" screen when below it. Without this, a backend contract fix can strand clinics on old builds.
**X03, inactivity lock (new, small).** After N minutes in the background, require device biometrics/PIN before the session is shown again; hide screens in the app switcher. A shared tablet in a surgery needs this more than most apps.
**X05, production telemetry.** Sentry DSN per environment, release/dist upload, PII scrub test on real event objects, error budget alert to the support owner.

### Phase 8: Prove the whole system (continuous; formal run weeks 11–14)

| ID | Deliverable |
|---|---|
| V01 | Six roles × two tenants × direct-API authorization matrix |
| V02 | **Fill the 12 empty `integration_test` files** with real journeys (scan/use, stock, receipt, conflict, offline/restart, alert, prosthetic lifecycle, waiting placement), each on isolated fixtures with server read-back |
| V03 | Fault injection suite (response lost, concurrent sends, kill points, stale 401, permission change, migration) |
| V04 | Backend regression tests: prosthetic/laboratory routes, label transitions, export filename collisions, restricted-role jobs, deployment config; a missing contract snapshot must **fail** CI, not skip |
| V05 | CI gates: analyze, unit/widget/contract, **changed-code coverage threshold**, web checks, reproducible build. Raise whole-repo line coverage from 34.5% to ≥ 60% on `lib/core` and ≥ 50% overall as a floor |

**Rule:** a test that is empty, skipped, mocked in a wire shape the server does not emit, or aimed at an unrouted screen does not count.

### Phase 9: Release artifacts and operations (starts week 1, completes weeks 13–16)

1. **Identity and signing (D01).** Replace `com.example.sterymed_mobile` with the owned application id; Android upload key + Play App Signing; iOS bundle id, **create the missing `ios/Podfile`**, signing, archive; version from a release pipeline. Debug-signed APKs must not leave the building.
2. **Hosting and TLS (D04).** Decide platform (OQ-10), terminate TLS in front of FrankenPHP, production compose, secrets from a manager, separate staging, migration role set up on a **fresh** deployment, Docker context excludes `.env`.
3. **Media (D02).** Presigned URLs must resolve to a public host. Remove the `minio:9000` rewrite hack from the production path once fixed.
4. **Physical matrix (D03).** At least: one recent mid-range Android, one small-screen Android, one tablet, one iPhone; fresh install and upgrade with a pending queue; large text; 3G/flaky Wi-Fi profile; **measure** the "common screens under 2 seconds" requirement with a written device/network profile.
5. **Printer and scanner** (D02): the real clinic label printer and a real 2D scanner/phone camera under surgery lighting.
6. **Operations (D04/D05).** Backup restore rehearsed end to end (database and media), rollback rehearsed with realistic alert history, queue and idempotency store durability across Redis restart, monitoring on errors/queues/certificates, support owner and runbook.
7. **Store and distribution.** Play internal-testing track and TestFlight for the pilot; no public listing until after M3.

### Phase 10: Clinic acceptance and handoff (weeks 15–17 and the pilot)

H01 clinic staff run the demo on the **candidate build** (the cahier §5 journey: create clinic and users → order/receive lot with expiry → print/scan/use without double counting → cycle with controls and attachment → alert → audit → export → same data on web and mobile); H02 triage — zero open critical/high, no blocked required journey, no record loss/duplication/wrong-tenant attribution; H03 written acceptance naming build, backend deployment, devices, printer, roles, evidence, known limits, plus French user guide, runbook, backup/restore, release and support documents and all credentials transferred to the owner; H04 rollout under a named support owner, daily inspection of sync and failed jobs for the first two weeks, practiced rollback.

---

## 6. What was **not** in the master plan and is added here

These are proposals; each needs an owner's yes/no in Phase 0.

| ID | Item | Why |
|---|---|---|
| X01 | **Inventory count (inventaire)** decision and, if required, a backend-first implementation | The cahier lists inventories for the stock manager and under monitoring. The backend has no such domain (OQ-12). Either build it or record the exclusion in writing. |
| X02 | **Minimum supported app version gate** | Lets the server retire a bad build and prevents silent contract drift between app and API. |
| X03 | **Inactivity lock + app-switcher privacy** | Shared clinical devices hold patient references and clinical records. |
| X04 | **Legal gate: GDPR/HDS analysis, hosting location, data-processing agreement, retention, device-loss procedure** | The cahier forbids real patient data before this is done. HDS-certified hosting may change the platform choice in D04, so decide *before* paying for infrastructure. |
| X05 | **Production telemetry and alert routing** | Without it a clinic's failure is learned from a phone call. |
| X06 | **Staged rollout and rollback of the app** | Play staged percentage + TestFlight groups; keep the previous signed build installable. |

---

## 7. Parallel tracks and ownership

| Track | Owner | Weeks | Content |
|---|---|---|---|
| Mobile core | M | 1–8 | Phases 1, 2, mobile half of 3 |
| Backend safety | B | 1–8 | F05/F06/F07, idempotency, lookups, atomic item update, label split, export collision, deployment defects |
| Mobile features | M | 6–13 | Phases 4, 5, 6, 7 on top of the finished contract |
| Joint proof | J | 5–14 | Fixtures, V01–V05, device runs |
| Release ops | J | 1–16 | Signing, Mac/iOS, hosting, restore, printer |
| Clinic | C | 1, 8, 12, 15–17 | Decisions, scheduled demo rehearsals (weeks 8 and 12), acceptance |

Two **clinic rehearsals** (week 8 on M1, week 12 on M2) are deliberate: the clinic sees working software early, and the acceptance in week 17 contains no surprises.

---

## 8. Risk register (top ten)

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Storage migration loses queued offline work | Medium | **Critical** | Copy-flush-verify-mark; quarantine, never wipe; test on recorded legacy data |
| 2 | Backend and mobile ship incompatible contracts | High | High | Contract snapshot test fails CI; X02 version gate; changes agreed in the matrix first |
| 3 | Clinical rules undefined at build time | Medium | High | Phase 0 decisions with named owner; safe defaults logged; no invented regulatory durations |
| 4 | iOS cannot be built or distributed in time | **High** | High | Mac and Apple account in week 1; Android pilot first, iOS a named later milestone if needed |
| 5 | Scope creep (dark mode, AI, billing, analytics) | High | Medium | Frozen by the cahier §3; additions only through the decisions log |
| 6 | Presigned media URLs unreachable from phones | **Certain** until fixed | High | BUG-010 fix is a Phase 0 ticket; verified on physical devices (D02) |
| 7 | Real patient data enters before legal clearance | Low | **Critical** | X04 gate checked in H01; demo data only before it |
| 8 | Printer/scanner mismatch discovered late | Medium | High | Printer sample ordered in week 1; tested at M1 rehearsal |
| 9 | Two-person capacity (20–25 h/week) shorter than assumed | Medium | High | Estimates scale linearly; M2 is the guard rail: a safe supervised pilot, not a feature race |
| 10 | Green tests mask real failures (mocked shapes, empty journey files, 34.5% coverage) | High | High | V05 rule: only routed, server-read-back, fixture-isolated tests count |

---

## 9. Definition of done (clinic-safe)

All must be true on the **exact release candidate**, with the evidence stored in the ledger (master plan §8):

1. Every required journey in §3 maps to a reachable screen and an executed test or recorded device run.
2. All six roles and both tenant boundaries pass positive **and** negative checks, through UI and direct API.
3. A write interrupted at any point (kill, timeout after commit, offline, double tap, account switch, upgrade) produces **exactly one** correct record and a truthful screen.
4. Clinical evidence (cycle, release, label, usage, movement, audit) can be read, linked, exported and recovered with original identities and times; no passive read changes clinical state.
5. A new clinic can be provisioned and receive its first delivery without a database edit.
6. Signed Android (and iOS, if in scope) builds from the owner's accounts install, upgrade and report errors to monitoring; media opens on a real phone.
7. Backup **restore** and rollback have been performed on staging; TLS, queues, scheduled jobs and monitoring are live; a support owner is named.
8. The GDPR/HDS gate (X04) is signed off before real patient references enter.
9. Zero open P0/P1; each lower-severity limitation has an owner, a workaround and the clinic's written approval.
10. A named clinic representative signs the acceptance of this build.

---

## 10. What to do on Monday (the first five working days)

1. **Day 1.** Triage the 13 failing tests and the one analyzer warning; commit the in-progress Phase 0/1 work (secure box, queue harness, fixtures, release-config verifier) in small commits, tests green.
2. **Day 1.** Send the Phase 0 decision list (§5, step 0.3) to the clinic owner and book the 45-minute session.
3. **Day 2.** Open the backend tickets (step 0.4), starting with the three P0 server defects: label GET mutation (F05), tenant-unsafe practitioner (F06), export filename collision (F07). These are small, high-value and independent of any mobile work.
4. **Day 2–3.** Begin S01 (session generation) with the A→logout→B regression test written *first*.
5. **Day 3–5.** In parallel: order a Mac/iOS access, create the store accounts, generate and escrow the Android upload key, pick the printer sample, choose hosting after the HDS question (X04) is asked.

By the end of week 1 the tree is green and decided; by the end of week 5 the app cannot lose, duplicate or mis-attribute a clinical write (M1); by week 12 a supervised pilot can run with test data in the real surgery (M2); by week 17 the clinic accepts it in writing (M3).
