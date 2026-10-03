# SteryMed Mobile — 10/10 Roadmap

**Sources read from scratch:** the Cahier des Charges (all 6 pages), the SteryMed Prosthetic Brief (all 16 pages), the backend source tree as dumped, and your Flutter codebase as dumped.

**Nothing else.** No prior roadmap, no prior rating doc, no DAILY_LOG conclusions reused as gospel — only what the three primary sources actually say plus what your code actually contains.

---

## Status ledger (updated 2 October 2026 — read this first)

This document was first written from a code dump. Re-checked against the live repositories and the dev backend on 2 October 2026, **several "gaps" below were already closed** and a few statements are no longer true. The ledger is the source of truth; the phase text keeps its original wording for the reasoning, and each phase carries a `Status:` line.

| Phase | Status | Evidence |
|---|---|---|
| 0 Truth freeze | ✅ code done · ⏳ owner items (T0.6 email, T0.7 accounts/printer) | commit `7cd9b3b`; analyzer clean; fixtures guard tests |
| 1 Session + storage isolation | ✅ code done · ⏳ real-device gate | commit `19d047f` + 2 Oct closing pass (PII patterns, cold-boot test, startup recovery screen) |
| 2 Durable writes + sync | ✅ done | commits `d34bdb4`, `ac76a6f`, `4e93410`; fault-injection tests in `test/unit/storage` |
| 3 Clinic setup, roles | ✅ done | commit `ee276a1`; role-matrix tests |
| 4 Sterilization + labels | ✅ code + live API proof · ⏳ printer/device day | `scripts/verify_sterilization_journey.py` all PASS |
| 5 Stock + purchasing | ✅ code + live API proof · ⏳ device run | `scripts/verify_stock_journey.py` all PASS (2 Oct); 2 Oct adds inventory counts, product code lookup, scanner product mode |
| 6 Prosthetic | ✅ code + live API proof · ⏳ device steps (T6.6 stopwatch, T6.9 PDF opens) | `scripts/verify_prosthetic_journey.py` ALL PASS (2 Oct); `prosthetic_phase6_test`, `prosthetic_list_bloc_test`, `prosthetic_waiting_placement_screen_test` (150 cases) |
| 7 Monitoring, UX | ✅ code · ⏳ device gate (journey 5 file opened, measured screen times) | version gate now also enforced server-side (`EnforceMinAppVersion`, `MinAppVersionTest`); `layout_resilience_test` (320x568 @130%, phone, tablet) green after fixing 6 real overflows (alerts row, login footer, info card, lock/update screens, date picker, buttons, evidence empty state) |
| 8 Prove the system | 🟡 code side done · ⏳ device journeys (T8.2 device files, T8.3 release build, T8.7) | authorization matrix ALL PASS, BUG-026 fixed, backend route tests, anomaly report, CI coverage floors; suite 833 pass, analyzer clean |
| 9 Release + operations | 🟡 code and dev proof done · ⏳ owner inputs (keystore, Play account, staging host/domain, Sentry projects, support owner) and phone/staging runs | `mobile-release-android.yml`, `docs/RELEASE.md`, `verify_media_links.py`, `verify_backup_restore.py`, Caddy staging stack |
| 10 | ⏳ not started | needs the clinic |

**Statements below that are no longer true** (kept for the audit trail):
- "Backend has no PATCH for cycle items" (T4.1) → `PATCH /v1/cycles/{id}/items/{item}` exists and the app edits in place.
- "Backend has no receipt-attachment endpoint" (T5.3) → `POST /v1/goods-receipts/{id}/attachments-base64` exists; the receipt photo uploads for real.
- "Cahier lists inventaire, no backend domain" → `/v1/inventory-counts` exists and the app has the screens.
- "Scanner resolves labels only" → scanner has a Produit mode backed by `GET /v1/lookups/code`.
- Gap 3 (PII) and the logging gap in Part 1 → closed in Phase 1 pass.

**Decisions the owner must confirm in writing** (cannot be settled by code):
1. *Patient identity.* The prosthetic brief §6 lists patient first and last name. The app stores a pseudonymous patient reference (ADR 0011 / BUG-008), which the Cahier §8 supports (RGPD/HDS analysis required before real patient data). Keep this unless the clinic accepts the legal gate.
2. *Reception role.* The backend has six roles (owner, admin, stock_manager, releaser, practitioner, viewer); there is no separate "reception". Payment fields are gated by `prosthetic_payments.manage` (owner/admin). Confirm reception = admin, or request a new backend role.
3. *iOS in the pilot?* No `Podfile`, no Mac. Android-first is the default.
4. *Timeline.* The Cahier §9 allows 12–16 weeks; this plan is 12 weeks part-time solo.

---

## Part 1 — What the sources actually require (verified, not assumed)

### The Cahier des Charges (the contract you signed)

**§2 — Users.** Four named types: *Administrateur de la structure*, *Responsable de stock / assistant(e)*, *Praticien*, plus the implicit "reception" (§8, §5.3). Each action must keep author, date, hour, old/new value.

**§3 — MVP limits.** Explicitly includes: **one pilot practice, one main site, simple roles, stock/orders/lots, light sterilization traceability, labels, scan, alerts, exports, web + mobile**. Explicitly *excludes*: advanced SaaS billing, marketplace, AI, complex multi-site, predictive analytics, universal compatibility, heavy customization, dozens of connectors.

**§4 — Mandatory MVP modules** (this is the entire scope of the pilot):

| Module | Web requirement | Mobile requirement |
|---|---|---|
| Account & security | Login, password reset, org, users, roles, permissions | Secure login, persistent session by role |
| Catalog | Products, families, units, photos/docs, min threshold, location, supplier | Search, product page, quick add, 2D code read |
| Stock & movements | Entries, exits, justified adjustments, simple transfers, history, stock calc | Scan in/out, quantity, reason, confirmation, weak-network mode |
| Purchases & lots | Suppliers, order, full/partial receipt, lots, expiry dates, reminders | Receipt, proof photo, lot/expiry, order view |
| Sterilization | Manual cycle, device/program, operator, controls, result, attachments, status | Guided cycle creation/validation, photo/report, history view |
| Labels & scan | Unique QR/DataMatrix, template, preview, print, justified reprint | Scan a label, consult lot/cycle, record usage |
| Monitoring | Dashboard, low-stock, near-expiry, failed cycle, inventory, journal, CSV/PDF export | Essential alerts, short indicators, filterable history |

**§5 — Six demo journeys** (this *is* the acceptance demo):

1. Create clinic + admin + assistant with different rights
2. Create product + supplier → order → receive lot with expiry
3. Print label → scan on mobile → record exit without double-count
4. Create + validate sterilization cycle; keep controls, attachment, operator
5. Trigger stock/expiry alert → consult audit → export report
6. Same data correctly on web and mobile

**§6 — Deliverables.** Product (web, Android, iOS), code (private repos, clean Git, no secrets, license), conception (parcours, wireframes, architecture, data model, OpenAPI), **quality (critical unit tests, API tests, main e2e path, anomaly report, acceptance)**, exploitation (Docker, staging, prod, CI/CD, logs, minimal monitoring, backup+restore tested), transmission (README, install, variables, deploy, demo accounts, short user guide). *"Le porteur du projet doit conserver l'accès administrateur aux dépôts, au cloud, aux domaines, aux comptes stores, à la base de données et aux sauvegardes."*

**§7 — Architecture.** Mobile: **Flutter Android/iOS**, same API, camera scan, notifications, **limited local queue for weak network**. This is the only line in the Cahier about mobile architecture, and it maps *exactly* to your outbox.

**§8 — Non-functional.**
- Isolation stricte des cabinets. Permissions server-side. HTTPS. Secrets outside code. Validation. OWASP.
- **No silent deletion of proof.** Corrections and reprints carry reason, author, history.
- **Critical operations transactional and idempotent** — no double receipts, scans, validations.
- **Screens under 2 seconds** on correct connection. Paginated lists.
- Anonymized demo data. **RGPD/HDS analysis before any real patient data.**
- Android récent, iOS récent, **two modern desktop browsers**, test matrix kept.

**§9 — Timeline.** 10 weeks indicative. **"Cible, pas une promesse aveugle."** Requires two autonomous people, 20-25 h/week each, fast decisions, **frozen scope**. Otherwise 12-16 weeks **or reduce the MVP**.

**§10 — Acceptance.** Complete demo journey on staging without hidden fake data. Rights tested. Web and mobile consume the same API and stay coherent after create/edit/scan/sync. Critical error scenarios handled (double-tap/scan, interrupted network, invalid data, failed print). Zero blocking or critical anomalies. **Backup and restore actually tested.** Code, access, documentation, and recorded demo handed to owner. **"Une fonctionnalité seulement visible sur une maquette ou non testée n'est pas considérée comme livrée."**

### The Prosthetic Brief (a *separate* document)

**§1 Main goal.** Centralize prosthetic cases, prevent forgotten tasks, provide real-time visibility, improve coordination.

**§4 Target workflow.** Impression → sent to lab → received → scheduled → placed → cancelled/remade. Each status change stores date, time, user, optional note.

**§5 Home dashboard.** Widgets: active cases, at lab, returned, waiting for placement, placements today/this week, cases requiring reminder, deposits/balances to pay. **UX rule: every dashboard card opens the corresponding filtered list. No dead KPI.**

**§6 Create a case.** Four sections: Patient, Clinical, Laboratory & dates, Notes. **Searchable dropdowns, sensible defaults, prefilled dates.** Searchable.

**§7 Case details.** Patient + practitioner, current status + full timeline, impression type + work category, lab + dates, administrative/payment block, attachments, remarks + history. Actions: Edit, Print/Export.

**§8 Administrative tracking.** Remaining balance auto-recalculated. **Non-blocking warning before "Placed" if outstanding payment.** Financial fields editable by reception/authorized roles, visible to clinicians.

**§9 Waiting for placement.** Auto-inclusion: `returned_from_lab` exists AND `actual_placement` empty AND status not cancelled. Columns: patient, practitioner, lab, work type, return date, planned placement, **days elapsed**, current status. **Aging levels 0-7 / 8-14 / 15+ days.** Thresholds configurable later.

**§10 Search and filters.** Six filters: patient, practitioner, laboratory, work type, status, date period. **"Filters must work together and persist while the user opens a case and returns to the list."**

**§11 Post-MVP roadmap.** Attachments, automatic alerts, statistics, practice software integration, mobile optimization. Explicitly *not* MVP.

**§13 Backend.** REST endpoints for cases, filters, status transitions, payments, attachments, labs, dashboard counts. Never expose raw secrets, patient data or unrestricted file URLs.

**§14 Mobile responsibilities.** Home compact summary, list with search+filters one-handed, detail with timeline, quick status change one-tap, attachments with capture/upload, waiting-for-placement with days elapsed, notifications later, **"at minimum preserve form content during temporary connectivity loss; avoid silent data loss."**

**§15 MVP acceptance.** Create under 2 min. Track status + all transitions always visible. Find by any filter combination. Wait: auto-include with correct elapsed days. Admin: reception verifies deposit/balance/payment from case page. Dashboard: cards open correct filtered cases. Audit: every modification records user, timestamp, previous/next state. Responsive. Secure.

**§16 Implementation order.** Phase 1 Core (data model, CRUD, labs, statuses, history, search, filters). Phase 2 Operations (dashboard, waiting, payments, roles, fast actions). Phase 3 Documents (photos, PDFs, slips, file storage, export). Phase 4 Automation (alerts, reminders, statistics). Phase 5 Integrations.

### Your Flutter codebase — verified state

**Built and structurally sound:**
- All 8 Cahier modules have screens.
- All 6 Cahier demo journeys have code paths.
- Prosthetic brief Phases 1 and 2 are implemented (models, repos, list, detail, create, edit, status, waiting, dashboard, payments).
- Auth, session, RBAC (permission-based via `RoleGuard`), theme, router, DI, shared widget kit, cursor-paginated list, outbox, sync engine, sync status pill — all present.
- Sentry, PII scrubber, idempotency interceptor, retry interceptor, error mapper — present.

**Real gaps, verified in code (not from any doc):**

1. **Idempotency key duplication.** In `stock_repository.dart::_submitWrite`, `label_usage_repository.dart::recordUsage`, `cycle_repository.dart::_submitTransition`, `purchase_repository.dart::receive` — the offline path calls `generateIdempotencyKey()` twice per item. Violates Cahier §8 "opérations ... idempotentes."

2. **`SyncEngine._syncOne` strands items.** Item marked `syncing`, then `remove` on success or reset to `pending` on failure. If the app is killed between the mark and the reset, the item never returns to `pending()` and is invisible forever. Violates Cahier §8 "aucune suppression silencieuse" and §7's "file locale limitée."

3. **`PiiScrubber` covers 5 fields only.** `token`, `password`, `patient_id`, `practitioner_id`, `Bearer <token>`. Missing: `name`, `email`, `phone`, `reference`, `patient_reference`, `notes`, `procedure`, `description`, `administrative_comments`. And `LoggingInterceptor` calls `.toString()` on parsed `Map`s — the Dart string form is `{name: Jean}`, not `{"name":"Jean"}` — the regex never matches. Both bugs are silent. Violates Cahier §8 "confidentialité."

4. **`cycle_detail_screen.dart::_editItem` does delete-then-create.** Loses `batch_id`. If the create fails, the item is gone. Violates Cahier §8 "aucune suppression silencieuse d'une preuve."

5. **Two prosthetic screens have no `dispose()`:** `_LaboratoryFormSheetState` (4 controllers), `_ProstheticCaseCreateScreenState` (3 controllers). Violates nothing contractual but is a leak.

6. **No release keystore**, `applicationId = com.example.sterymed_mobile`, `mobile-release-android.yml` and `mobile-release-ios.yml` are empty files. Violates Cahier §6 "compilables" and §10 "démonstration du parcours complet."

7. **iOS `Podfile` missing**, iOS CI fails. Violates Cahier §6 "applications Android/iOS compilables."

8. **`integration_test/` is 13 of 16 files empty.** Violates Cahier §6 "parcours end-to-end principal" and §10 "fonctionnalité ... non testée n'est pas livrée."

9. **No real-device log.** `docs/DEVICE_TEST_LOG.md` has zero entries. Violates §10 by definition.

10. **Test coverage floors unknown** but the rating audit says LCOV was 34.5%. Cahier §6 requires "tests unitaires critiques." Critical-path coverage on `lib/core/` and `lib/features/*/data/` is what matters.

11. **No staging deployment.** Backend has a local Docker skeleton, no prod. Cahier §6 requires staging/production separated. §10 requires demo on staging.

12. **Backup/restore not drilled.** Cahier §10 explicitly requires "sauvegarde et restauration ont été réellement testées."

13. **`team_invite_sheet.dart` and other invite flows are not tested against the real backend.** Cahier §5.1 requires "créer ... un administrateur et un assistant avec des droits différents."

14. **`goods_receipt_screen.dart` dead-ends on empty clinic.** Derives locations from `/stock-levels` — empty clinic has none. Violates Cahier §5.2 (journey 2 is literally "receive a lot").

### What the sources do NOT require (drop from scope)

- Complex multi-site
- Advanced billing / SaaS subscription management
- Marketplace
- AI / predictive analytics
- Universal browser/OS compatibility
- Dozens of connectors
- The prosthetic brief's §11 post-MVP items (statistics, automatic alerts beyond the basic, practice-software integration)

### What the prosthetic brief's own §16 says about ordering

The prosthetic brief explicitly separates Phase 1 (Core) from Phase 2 (Operations). Your code has both. Phase 3 (Documents) is partially built (attachments upload/delete exist). Phase 4 (Automation) is explicitly deferred. Phase 5 (Integrations) is explicitly deferred.

**Conclusion:** the prosthetic module is not a "v1.1 cut." It is a *co-deliverable* with the Cahier pilot, but its own §16 says "Phases 3-5 come after." The 10-week Cahier target can't hold both at full depth, but Prosthetic Phases 1-2 are already built. Do not cut them.

---

## Part 2 — The honest current status

Score against the sources:

| Requirement | Weight | Current | Gap |
|---|---|---|---|
| §4 all 8 modules have functional screens | 20% | **19/20** | Minor: receipt photo, attachments in some flows |
| §5 six demo journeys work end-to-end | 25% | **14/25** | J2 blocked empty-clinic; J5 needs verify; J6 not proven |
| §6 quality deliverables (tests, anomaly report, acceptance) | 15% | **7/15** | Real tests exist for many; e2e empty; acceptance not signed |
| §6 exploitation (Docker, staging, CI/CD, backup tested) | 10% | **3/10** | No staging, no restore drill, no release pipeline |
| §6 transmission (README, guide, demo accounts) | 5% | **4/5** | Docs exist; demo accounts; user guide skeleton |
| §8 non-functional (isolation, idempotency, PII, no silent delete, 2s, RGPD/HDS) | 15% | **6/15** | Session, idempotency, PII, item-edit, backup all gap |
| §10 acceptance conditions | 10% | **2/10** | Not one of the six conditions is provable today |
| Prosthetic §15 (co-deliverable) | n/a | **~70%** | Phases 1-2 done; aging uses loaded page; filters lost on return; money parse fr; leaks |
| **Total** | **100%** | **≈ 55%** | **Ready to demonstrate, not ready to accept** |

Translation: **the app demonstrates the whole product but cannot be signed off on any single §10 condition today.** You are roughly at the end of the Cahier's "étape 3 — Traçabilité" of §9, not at "étape 5 — Stabilisation."

**The 10/10 roadmap is therefore not "finish building."** It is "close §10 conditions one by one and get the acceptance signed."

---

## Part 3 — The 10/10 roadmap

Twelve phases. Each phase closes one or more §10 conditions plus the specific §4/§5/§8 requirements it serves. Each phase has a binary gate. No phase starts until the prior gate is green.

**Total duration: 12 weeks part-time solo (or 8 weeks full-time solo).** This matches the Cahier §9 escape clause exactly.

```
Week:        1   2   3   4   5   6   7   8   9  10  11  12
P0 truth     ███
P1 session      ██████
P2 sync              ████████
P3 clinic-setup           ██████
P4 steril+labels                ██████████
P5 stock+purch                       ██████████
P6 prosthetic                    ████████ (parallel to P4/P5)
P7 monitoring                            ██████
P8 proof                    ░░░░░░░░░░░░░░░░░░░░████████ (continuous)
P9 release                                      ██████
P10 accept                                              ██████
```

---

### PHASE 0 — Truth freeze and green tree

**Status: ✅ code · ⏳ T0.6/T0.7 are owner actions (scope email, Play account, keystore, printer sample, Sentry DSN, support channel).**

**Duration: 4 days. Closes: none by itself. Unblocks everything.**

**Why:** you cannot prove any §10 condition from a red tree.

### Tasks

- [ ] `T0.1` `flutter analyze --fatal-infos` → 0 issues.
- [ ] `T0.2` `flutter test` → 100% green. Store log at `build/test_baseline.log`.
- [ ] `T0.3` Categorize every modified file in `git status`. Commit or delete. Nothing uncommitted.
- [ ] `T0.4` `.gitattributes` renormalization committed once.
- [ ] `T0.5` Write `docs/DEMO_BASELINE.md`: run the six Cahier journeys manually on your dev machine. Record for each: works / broken / blocked. This is your honest starting point.
- [ ] `T0.6` Send the scope email to the product owner. Subject: *Confirmation de périmètre et de planning — Cahier §9*. Body: quote §9 "condition de délai" verbatim, state the four Cahier roles, state that the prosthetic module is co-deliverable per its own brief §16, propose 12 weeks part-time solo, request written confirmation. **Print the reply and file it.**
- [ ] `T0.7` Long-lead items started today:
  - [ ] Android upload keystore generated, stored in `android/key.properties` (gitignored), backed up in a password manager
  - [ ] Play Console account created ($25)
  - [ ] **Confirm with owner: is iOS in pilot?** Yes → start the Apple Developer account and Mac access path now. No → proceed Android-only for pilot; iOS lands in v1.1.
  - [ ] Label printer sample ordered (clinic's actual printer model)
  - [ ] Sentry project DSN in hand for staging
  - [ ] Support channel named (email alias or shared inbox)

### GATE 0 — binary

- [ ] Analyzer clean, test suite green, tree committed
- [ ] `docs/DEMO_BASELINE.md` written
- [ ] Scope email sent, response filed
- [ ] Keystore + Play + printer sample started
- [ ] iOS in-scope decision recorded in writing
- [ ] Sentry DSN + support channel named

---

### PHASE 1 — Session safety and local storage isolation

**Status: ✅ code complete 2 Oct 2026. Open: the real-device gate items (A→logout→B on a phone, no unencrypted box on disk) — no phone was attached; run per `docs/DEVICE_TEST_LOG.md`.**

**Duration: 6 days. Closes: §8 "isolation stricte des cabinets" + §8 "confidentialité" for local data.**

**Why:** §8 requires strict cabinet isolation and RGPD-appropriate handling. Two accounts on one clinic device today can see each other's drafts and replay each other's writes.

### Tasks

- [ ] `T1.1` `lib/core/session/session_generation.dart`: `(environment, tenantId, userId, generation)`.
  - [ ] Stamp generation on every request.
  - [ ] Drop responses from older generations.
- [ ] `T1.2` `lib/core/storage/secure_box.dart`: per-owner AES-256 Hive box.
  - [ ] Keys in `flutter_secure_storage`, derived from `(environment, tenantId, userId)`.
  - [ ] `KeyLossException` → "Storage needs attention" screen, never silent wipe.
- [ ] `T1.3` Migrate `steriymed.outbox`, `steriymed.kv`, `steriymed.cycle_notes` to per-user boxes.
  - [ ] Migration = read → write to encrypted → verify byte-for-byte → delete plaintext.
  - [ ] Failure → quarantine under `quarantine:{timestamp}`, surface recovery screen. Never assign to the next login.
- [ ] `T1.4` Non-blocking boot: rewrite `bootstrap.dart` so the first frame renders **before** any network call, queue read, or Sentry init.
  - [ ] Corrupt Hive → renders "Storage needs attention", not a crash.
- [ ] `T1.5` Structured allow-listed logger.
  - [ ] `Logger.info(event, fields: {...})` with an allow-list per event.
  - [ ] `LoggingInterceptor` uses it, never `response.data.toString()`.
  - [ ] `CrashReporter.beforeSend` walks `event.exceptions[].value` and `event.extra`, scrubs by key name.
  - [ ] Extend `PiiScrubber` patterns to `name`, `email`, `phone`, `reference`, `patient_reference`, `notes`, `procedure`, `description`, `administrative_comments`.
- [ ] `T1.6` `ConnectivityService`: hold upstream subscription, cancel on dispose.
- [ ] `T1.7` Wire `AppLifecycleObserver` → on resume: refresh `/me`, flush outbox.

### Tests

- [ ] A logs in → request in flight → A logs out → B logs in → A's late 401 arrives → B still logged in.
- [ ] Upgrade from current build with pending outbox items → items migrate to current user, all preserved.
- [ ] Kill during storage migration → idempotent, restarts clean, no data loss.
- [ ] Cold boot with 500-item outbox → first frame < 500 ms.
- [ ] Log a request containing a patient name → Sentry event shows `[REDACTED]`.
- [ ] Log an error whose message embeds a patient reference → Sentry event shows `[REDACTED]`.

### GATE 1 — binary

- [ ] A→logout→B regression passes **on a real device**
- [ ] Kill during migration → no data loss, no crash
- [ ] Cold boot with 500-item outbox → first frame < 500 ms
- [ ] No unencrypted box on disk
- [ ] Patient name never appears in any log or Sentry event
- [ ] All Phase 1 tests green

---

### PHASE 2 — Durable writes and honest sync

**Status: ✅ done.**

**Duration: 8 days. Closes: §8 "opérations critiques transactionnelles et idempotentes" + §7 "file locale limitée."**

**Why:** §8 is explicit. A double receipt, double scan, or a lost validation is a contract violation.

### Tasks

- [ ] `T2.1` Fix the double-key bug in four repositories (`stock_repository`, `label_usage_repository`, `cycle_repository`, `purchase_repository`). One key per user intent, generated before the first send, reused on retry, offline queue, and replay.
- [ ] `T2.2` Rebuild `OutboxItem`:
  - [ ] `id`, `idempotencyKey` (immutable, generated once).
  - [ ] `method`, `path`, `payload`, `originalEventAt`, `ownerGeneration`, `schemaVersion`, `attemptCount`, `nextAttemptAt`, `status`, `lastError`, `lastRequestId`.
- [ ] `T2.3` Rebuild `SyncEngine`:
  - [ ] Single-flight `flush()` via `Completer`.
  - [ ] Startup recovery: items stuck in `syncing` → reset to `pending`, same key.
  - [ ] Auth pause: 401 → stop flush, don't burn retries.
  - [ ] Ordering: `createdAt` plus dependency chain (`cycles/{id}/start` before `cycles/{id}/complete`).
  - [ ] Persisted backoff per item.
  - [ ] Explicit states: `pending`, `sending`, `confirmed`, `unknown_outcome`, `auth_blocked`, `conflict`, `validation_failed`, `manual_review`.
  - [ ] `unknown_outcome` **never auto-retries with a fresh key.** Reconcile against the business record first (fetch the resource; if the effect is present, mark confirmed; if absent, resend with the original key).
- [ ] `T2.4` Truthful sync UI: `pendingCount = pending + sending + auth_blocked`; `manualReviewCount = manual_review + conflict + validation_failed`. Pill always visible.
- [ ] `T2.5` `used_at` at clinical moment: capture `DateTime.now()` on submit in `LabelUsageFormScreen`, pass through the whole chain.

### Tests (fault injection with server-side readback)

- [ ] Response lost after commit → replay → exactly one business row.
- [ ] Timeout after commit → replay → exactly one business row.
- [ ] Kill between persist and send → restart → recovered → exactly one row.
- [ ] Kill between send and ack → restart → recovered → exactly one row.
- [ ] Two flushes racing → one send.
- [ ] 401 during flush → pause → re-login → resume → exactly one row.
- [ ] Offline usage form → kill → restore → submit → sync → `used_at` preserves original event time.

### GATE 2 — binary

- [ ] Every fault-injection test passes with server-side row-count assertion
- [ ] Sync pill never green while items pending or in manual review
- [ ] `used_at` preserved across offline replay
- [ ] All Phase 2 tests green

---

### PHASE 3 — Clinic setup and empty-clinic bootstrap

**Status: ✅ done.**

**Duration: 6 days. Closes: §5.1 (create clinic + users with rights) + §5.2 (order + receive lot).**

**Why:** the current goods-receipt screen derives locations from `/stock-levels`. Empty clinic → dead end. Cahier §5.2 is literally "receive a lot with expiry."

### Tasks

- [ ] `T3.1` Goods receipt empty-clinic handling: when no locations exist, show French card "Créez un emplacement sur le web" with a link to the web admin URL. Never dead-end.
- [ ] `T3.2` Same handling on `stock_issue_screen`, `stock_adjust_screen`, `stock_transfer_screen`. Card already exists — extend to goods receipt.
- [ ] `T3.3` Team roster: `TeamRepository.practitioners()` filters `active && role ∈ {owner, admin, practitioner}`.
- [ ] `T3.4` Role matrix sweep: for every screen listed below, verify in-screen actions are gated per Cahier §2 (Administrateur, Responsable de stock, Praticien, Reception) and per Cahier §4 module requirements:
  - [ ] `label_detail_screen` → Enregistrer utilisation → `usages.manage`
  - [ ] `purchase_order_list_screen` → Nouvelle commande → `purchasing.manage`
  - [ ] `purchase_order_detail_screen` → Mark ordered, Recevoir → `purchasing.manage`
  - [ ] `stock_level_list_screen` → Actions rapides → `inventory.manage`
  - [ ] `alert_list_screen` → Marquer comme résolu → `alerts.manage`
  - [ ] `cycle_list_screen` → Nouveau cycle → `cycles.manage`
  - [ ] `dlu_rules_screen` → Create/edit/delete → `labels.manage`
  - [ ] `team_list_screen` → Invite/disable → `invitations.create` / `memberships.disable`
  - [ ] `prosthetic_case_detail_screen` → clinical vs payment split
  - [ ] `device_detail_screen` → all actions
- [ ] `T3.5` Rule: hide the control, never just disable it. A user must not see a button that 403s.
- [ ] `T3.6` Password recovery: backend has no `POST /v1/auth/forgot-password`. Ship French message with support email + web reset URL. Never a silent-fail form.
- [ ] `T3.7` `rbac_role_matrix_test.dart` covers every Cahier role × every screen with in-screen actions.

### Tests

- [ ] Empty clinic → goods receipt → CTA visible → tap opens web admin.
- [ ] Disabled practitioner not selectable in any picker.
- [ ] Archived laboratory selectable in edit with "(archivé)".
- [ ] Role matrix green for all four Cahier roles × all screens with in-screen actions.

### GATE 3 — binary

- [ ] Empty clinic can receive its first stock (or see honest CTA to web)
- [ ] Disabled practitioner not selectable anywhere
- [ ] Role matrix covers all four Cahier roles × all screens
- [ ] Forgot-password screen calls no missing endpoint
- [ ] All Phase 3 tests green

---

### PHASE 4 — Sterilization + labels end-to-end

**Status: ✅ code + live API proof. Open: T4.8 printer/scanner day on a real device.**

**Duration: 10 days. Closes: §5.3 (print, scan, record use without double-count) + §5.4 (cycle with controls and attachment) + §4 sterilization + label modules.**

**Why:** this is the clinical heart of the Cahier and the two demo journeys that carry the safety risk.

### Tasks

- [x] `T4.1` Cycle item edit — **done differently**: the backend now has `PATCH /cycles/{id}/items/{item}` (atomic, keeps item id, position and batch link; refused with `CYCLE_LOAD_LOCKED` once the cycle left draft). The app edits in place; delete-then-create is gone. Proof: step 5 of `verify_sterilization_journey.py`.
- [ ] `T4.2` Release decision readable:
  - [ ] `CycleDetailBloc._onLoad` calls `GET /cycles/{id}/release` when status is `released` or `rejected`.
  - [ ] Release card always rendered for those statuses with decision, reason, actor, timestamp.
- [ ] `T4.3` Attachment viewer:
  - [ ] `CycleDetailAttachmentTile` `onTap` → `ImagePreviewDialog` (images) or `OpenFilex.open` (PDFs).
  - [ ] Actual image loads via `MediaUrl.resolve(...)`, not placeholder.
- [ ] `T4.4` Scan → detail:
  - [ ] `ScannerBloc` calls `GET /labels/{code}` **exactly once per intent**.
  - [ ] Result stored on bloc, reused by detail (no re-fetch on navigation).
  - [ ] `canRecordUsage => status == used`, matching the real backend (`LABEL_NOT_SCANNED` otherwise).
- [ ] `T4.5` `used_at` captured at clinical moment (verified again in Phase 2's test).
- [ ] `T4.6` Evidence dossier:
  - [ ] Wire `GET /labels/{label}/usage/dossier` to an "Exporter PDF" button on label detail.
  - [ ] Save PDF → `OpenFilex.open`.
- [ ] `T4.7` Cycle labels generation:
  - [ ] Verify `POST /cycles/{id}/labels` is called only for `status == released`.
  - [ ] Handle `CYCLE_LABELS_ALREADY_GENERATED` with a clear French message.
- [ ] `T4.8` Real-device scanner day:
  - [ ] Print labels from the actual clinic printer.
  - [ ] Test at 5, 10, 20, 30, 50 cm.
  - [ ] Test at 0°, 45°, 90°.
  - [ ] Low light.
  - [ ] Damaged and wrinkled labels.
  - [ ] Screen glare.
  - [ ] Both QR and DataMatrix.
  - [ ] Log every result in `docs/DEVICE_TEST_LOG.md`.
  - [ ] Fix every failure.

### Tests

- [ ] Scan `created` label → detail says "imprimer d'abord", no CTA.
- [ ] Scan `printed` label → CTA enabled → usage form → submit → server records with correct `used_at`.
- [ ] Scan `used` label → detail says "déjà utilisé" with usage history.
- [ ] Scan `recalled` label → 410 → `LabelBlockedScreen`.
- [ ] Double scan within 400 ms → second is blocked.
- [ ] Load released cycle → release card shows decision and actor.
- [ ] Tap image attachment → full-screen viewer.
- [ ] Tap PDF attachment → device PDF viewer.
- [ ] Exporter PDF on label detail → file opens.
- [ ] Cycle lifecycle end-to-end on device (create → start → complete → submit → release).

### GATE 4 — binary

- [ ] Cycle item edit doesn't lose `batch_id` (or refuses and explains)
- [ ] Release decision readable on every released/rejected cycle
- [ ] Attachments open in real viewer on device
- [ ] Scan → detail is one network call; blocked labels go to `LabelBlockedScreen`
- [ ] `used_at` preserved across replay
- [ ] Evidence dossier export works end-to-end on device
- [ ] Scanner proves correct on a real device with real printed labels
- [ ] Cycle lifecycle e2e passes on a real device
- [ ] All Phase 4 tests green

---

### PHASE 5 — Stock and purchasing complete

**Status: ✅ code + live API proof (`verify_stock_journey.py`). Open: device run, T5.6 two-device concurrency on phones (server side proven: second issue refused 409).**

**Duration: 10 days. Closes: §5.2 (partial receipt, lot, expiry) + §4 stock + purchases + lots modules.**

### Tasks

- [x] `T5.1` French decimal parsing (`lib/core/utils/decimal_input.dart`, tested):
  - [ ] `purchase_order_create_sheet.dart` and `goods_receipt_screen.dart`: parse via `NumberFormat.locale('fr_FR').parse(text)`.
  - [ ] Reject negative/zero in validators.
- [x] `T5.2` Receipt validation (`ReceiptLineDraft`, tested):
  - [ ] Quantity: positive, ≤ remaining.
  - [ ] Batch number: required, min 2 chars.
  - [ ] Expiry date: required for consumables, must be in the future.
  - [ ] Discrepancy reason: required if quantity < ordered.
- [x] `T5.3` Receipt photo — **done differently**: the backend has `POST /goods-receipts/{id}/attachments-base64`. The receipt is recorded first; the photo is sent right after; if that fails the stock stays correct and the screen says the proof is still missing (retry from receipt history). No "local only" fiction needed.
- [ ] `T5.4` Stock movements already queue via outbox — verify in Phase 2's fault-injection suite.
- [ ] `T5.5` Empty-location limitation on stock screens: keep the empty-state card, add text "Certains emplacements inutilisés n'apparaissent pas. Contactez votre administrateur."
- [ ] `T5.6` Two-device concurrency: script two clients issuing the same batch simultaneously. Verify server rejects second → app surfaces error correctly.

### Tests

- [ ] `12,50` → 12.50 sent. `-5` → validation error.
- [ ] Zero quantity on receipt → error, no submit.
- [ ] Empty batch number → error.
- [ ] Past expiry date → error.
- [ ] Two-device concurrent issue → second receives server error, app displays it.
- [ ] Full purchase journey on device: order → partial receipt → final receipt → stock delta correct.

### GATE 5 — binary

- [ ] French decimal works for prices
- [ ] Receipt validation rejects zero/negative/empty
- [ ] Receipt photo is honest about local-only
- [ ] Stock deltas after issue/adjust/transfer are correct server-side
- [ ] Two-device concurrency produces correct error
- [ ] Real-device run: order → partial receipt → issue → transfer → all verified on web
- [ ] All Phase 5 tests green

---

### PHASE 6 — Prosthetic workflow complete (parallel to P4/P5)

**Duration: 8 days. Closes: Prosthetic Brief §15 MVP acceptance.**

**Why:** the prosthetic brief is a co-deliverable. Its §16 Phase 1 (Core) and Phase 2 (Operations) are what the pilot needs. Phases 3-5 remain post-pilot.

### Tasks

- [x] `T6.1` Controllers disposed in `_LaboratoryFormSheetState` and `_ProstheticCaseCreateScreenState` (verified 2 Oct; `leak_check_test.dart` guards it).
- [x] `T6.2` Filters persist (Brief §10: "filters must work together and persist while the user opens a case and returns"): **(done: `prosthetic_list_bloc_test`, race-safe generation counter)**
  - [ ] The six filters (patient reference, practitioner, laboratory, work type, status, period) live in `ProstheticCaseListBloc` state, survive page 2, refresh, open-case-and-back, and a dashboard drill-down pre-fills them.
  - [ ] A late response from an old filter set never overwrites a newer one (race-safe).
- [x] `T6.3` Dashboard cards (Brief §5 "no dead KPI card"): each of the seven widgets opens the list pre-filtered, and the list's total equals the card's number. **(done: `prosthetic_phase6_test` dashboard group; live script step 11 = all seven cards equal their list total)**
- [x] `T6.4` Waiting for placement (Brief §9): inclusion rule computed by the server over the **whole** result, not the loaded page; days elapsed from the server date; aging 0–7 / 8–14 / 15+; quick actions schedule, note, open. **(done: `prosthetic_waiting_placement_screen_test` 150 cases; live script step 12)**
- [x] `T6.5` Payment block (Brief §8): French decimals (`decimal_input.dart`), non-negative, remaining balance recalculated live, malformed input never becomes a null PATCH, non-blocking warning before "Placed" when a balance is outstanding. Payment fields only for `prosthetic_payments.manage`; clinicians read them. **(done: `prosthetic_phase6_test` payment group; live script step 10)**
- [ ] `T6.6` Create in under 2 minutes (Brief §15): searchable practitioner and laboratory pickers (active only), prefilled impression date, draft survives kill (durable, awaited save/clear). **Time it with a stopwatch on a phone and record it in `DEVICE_TEST_LOG.md`.** **(code + draft tests done; the phone stopwatch run is still owed)**
- [x] `T6.7` Status lifecycle: every transition stores user, time, note; critical transitions (Cancelled, Placed) ask for confirmation; server rejects invalid transitions and the app shows the French reason; history always visible. **(done: `prosthetic_status_flow_test`, `prosthetic_phase6_test`; live script steps 4-9)**
- [x] `T6.8` Attachments (Brief §16 phase 3, light): capture or pick, upload with progress and a clear retry state, open image/PDF; expired URL recovers by re-fetching. **(done in code: progress + Réessayer + expired-URL reload; capture needs the device run)**
- [ ] `T6.9` Print/Export (Brief §7): PDF of the case from the detail screen (server PDF exists); opens on device. **(PDF is built on the phone, `prosthetic_case_pdf_test`; opening it on a device is still owed)**
- [x] `T6.10` Roles: `prosthetic_cases.view` everyone; `.manage` owner/admin/practitioner; payments owner/admin. Hidden, not disabled (T3.5). **(done: `prosthetic_phase6_test` roles group; live script read-only member)**

### Tests

- [ ] Filters survive: apply 3 filters → open case → back → same list, same filters.
- [ ] Card count equals filtered list total for each of the seven cards.
- [ ] Waiting list with 150 cases shows correct aging buckets beyond page 1.
- [ ] `12,50` deposit saved as 12.50; `abc` blocks submit with a message.
- [ ] Placed with outstanding balance → warning shown, transition still allowed.
- [ ] Practitioner role: sees payment block read-only, no edit button.
- [ ] Live script `scripts/verify_prosthetic_journey.py`: create → impression→sent→received→scheduled→placed with history read-back, invalid transition refused, wrong-tenant practitioner refused.

### GATE 6 — binary

- [ ] Brief §15 criteria each map to a passing test or a recorded device run (create < 2 min stopwatch included)
- [ ] No dead KPI; filters persist; aging correct beyond page 1
- [ ] Live prosthetic journey script all PASS
- [ ] All Phase 6 tests green

---

### PHASE 7 — Monitoring, records and everyday UX

**Duration: 6 days. Closes: Cahier §4 "Pilotage" + §5.5 (alert → audit → export).**

- [x] `T7.1` Dashboard honesty: a failed call shows "indisponible" with retry, never a zero. Distinguish unavailable / stale / zero. **(done: `dashboard_honesty_test`)**
- [x] `T7.2` Alerts: list filterable by type and state; resolve shows per-alert result and the real French error; low stock, near expiry (DLC), failed cycle, overdue control all reachable. **(done: `alert_list_screen_test`; the server raises 4 kinds: low stock, near expiry, expired, failed cycle. It raises no "overdue control" alert, so the app does not invent one)**
- [x] `T7.3` Audit/journal: filter by action, actor, subject, period; first load never fails silently; evidence search by label/lot/patient reference. **(done: `audit_phase7_test`, evidence search screen)**
- [x] `T7.4` Exports CSV/PDF (Cahier §4): download, save, share; failure and expiry handled; filtered export wired where the backend supports it; archives never overwrite same-named files. **(done: `export_buttons_test`, `data_export_request_screen_test`, unique file names in `FileExportService`)**
- [x] `T7.5` Minimum-version gate: the app shows a blocking "mise à jour requise" screen when the server says the build is too old (small backend change; agree it in the contract first). **(done 2 Oct: app `VersionGate` + server `EnforceMinAppVersion`, 5 backend tests in `MinAppVersionTest`)**
- [x] `T7.6` Inactivity lock: after N minutes in background, require device biometrics/PIN; hide content in the app switcher (shared surgery devices). **(done: `app_guard_test`, `InactivityLock`, `PrivacyScreen`)**
- [ ] `T7.7` Small screens, large text (scale 1.3), tablet layout sanity, every list paginated, every screen < 2 s on a normal connection (measure; record device and network). **(layout part done 2 Oct: `layout_resilience_test` 320x568 at 130%, phone, tablet, 7 screens; server side measured 2 Oct with `scripts/measure_api_times.py`: slowest screen 0.31 s of the 2 s budget, all 13 screens OK; the render time on a named phone and network is still owed)**
- [x] `T7.8` Honest About/privacy/help text: no claims the app cannot back (a connector is a labeled mock). **(done 2 Oct: the fake "Recevoir les alertes" switch was removed because there is no push infrastructure; About text corrected; `settings_screen_test`)**

### GATE 7 — binary

- [ ] Journey 5 (alert → audit → export) runs on a device with the file opened
- [ ] No screen shows a zero or empty state for a failed load
- [ ] Measured screen times recorded (< 2 s target, device + network named)
- [ ] All Phase 7 tests green

---

### PHASE 8 — Prove the whole system

**Duration: continuous; formal run 8 days. Closes: Cahier §6 quality + §10 conditions 1–4.**

- [x] `T8.1` Authorization matrix: six roles × two tenants × (UI, direct route, direct API, permission changed mid-session). Positive and negative. A tenant can never read or write another's data (Cahier §10.2). **(done 2 Oct: `scripts/verify_authorization_matrix.py` ALL PASS: 6 roles x 29 probes with valid bodies, tenant wall by id/list/credentials/cross-practice case, role changed mid-session refused on the same token. Found and fixed BUG-026 on the way)**
- [ ] `T8.2` Fill the empty `integration_test` files with real journeys, each with server read-back: scan/use, stock, receipt, conflict, offline/restart, alert, prosthetic lifecycle, waiting placement. **(written 2 Oct, NOT yet executed: `journeys/stock_issue`, `conflict_409`, `goods_receipt`, `scanner_usage`, `alert_resolve`, `prosthetic_case`, `waiting_placement` each read the server back after the UI step; the offline journey needs airplane mode so it is a manual device scenario and its empty stub was removed; the 4 other empty stubs were removed too. Tick this box when they have been run, see ANOMALIES A-03)**
- [ ] `T8.3` Fault injection: response lost, timeout after commit, double tap, double scan, kill points, stale 401, account switch, upgrade with a pending queue (re-run the Phase 2 suite on the release build). **(partly: Phase 2 fault-injection suite in `test/unit/storage` + `test/live/queue_lost_response_live_test`, `verify_idempotency.py` and `verify_idempotency_concurrency.py` PASS 2 Oct; the re-run on a release build and the upgrade-with-pending-queue run need the signed build, Phase 9)**
- [x] `T8.4` Backend regression tests for the routes this app depends on (prosthetic, laboratories, inventory counts, code lookup, label transitions, idempotency); a missing contract snapshot fails CI. **(done 2 Oct: `ProstheticWorkflowTest` now covers laboratories and waiting-placement, 14 pass; `OpenApiContractTest` snapshot regenerated and passing; `PermissionCachePerTenantTest`, `MinAppVersionTest`)**
- [x] `T8.5` CI gates: analyze `--fatal-infos`, unit/widget/contract, coverage floor (≥ 60% `lib/core`, ≥ 50% overall), reproducible build. **(done 2 Oct: `flutter analyze --fatal-infos` in CI, `scripts/coverage_summary.py --enforce` floors lib/core 60% and overall 50% added to `mobile-test.yml`; measured lib/core 76.6%, overall 50.7%, which is only just over the floor)**
- [x] `T8.6` **Anomaly report** (`docs/ANOMALIES.md`): every defect found, severity, status. Cahier §10.5: zero open blocking/critical. **(done 2 Oct: `docs/ANOMALIES.md`; no blocking or critical item open; A-01 High must close on staging)**
- [ ] `T8.7` The six Cahier journeys run end to end on a phone against staging, screen-recorded, results in `DEVICE_TEST_LOG.md`. **(owed: needs a phone and staging)**

### GATE 8 — binary

- [ ] Authorization matrix green, including wrong-tenant attempts
- [ ] Journeys 1–6 recorded on a device with no hidden fake data
- [ ] Anomaly report with zero open blocking/critical
- [ ] CI green on the candidate commit

---

### PHASE 9 — Release artifacts and operations

**Duration: 8 days (long-lead items start in Phase 0). Closes: Cahier §6 exploitation + §10.5 backup/restore.**

- [ ] `T9.1` Identity and signing: replace `com.example.sterymed_mobile` with the owned application id; Android upload key + Play App Signing; version from the pipeline; no debug-signed APK leaves the building. iOS: bundle id, create `ios/Podfile`, signing and archive **only if iOS is in the pilot**. **(code done 2 Oct: provisional id `com.sterymed.mobile` for the owner to confirm, version from the tag and run number, Gradle refuses an unsigned or debug-signed release, `verify_release_config.py --mode android-release` passes, and a signed obfuscated release bundle builds (68 MB, exit 0, signature verified with a throwaway test keystore on 2 Oct). Owed: the real upload keystore, owner-confirmed id, iOS stays out of scope)**
- [x] `T9.2` Release pipelines: `mobile-release-android.yml` builds a signed AAB from a tag; iOS pipeline only if in scope. **(done 2 Oct: `mobile-release-android.yml` builds the signed AAB from a `v*.*.*` tag after analyze and tests; iOS workflows are manual-only placeholders; setup in `docs/RELEASE.md`)**
- [ ] `T9.3` Staging separate from production: HTTPS with a real certificate, production compose, secrets from a manager, migration role set up on a **fresh** deployment, Docker context excludes `.env`. **(code done 2 Oct: Caddy with automatic HTTPS, app not published on a host port, `.dockerignore` excludes `.env*`, env template completed; compose and Caddyfile validate. Owed: an actual staging host, domain and secrets, and the first fresh migration run there)**
- [ ] `T9.4` Media: presigned URLs resolve on a public host from a phone (BUG-010); verify on a physical device. **(fixed and proven on dev 2 Oct: `PublicPresigner`, `verify_media_links.py` ALL PASS, `PublicPresignerTest`, BUG-010 closed; owed: the same on staging and from a phone)**
- [ ] `T9.5` **Backup and restore actually performed** (database and media) on staging, timed, written up in `docs/BACKUP_RESTORE.md`; rollback rehearsed. **(performed and timed on the dev stack 2 Oct: `verify_backup_restore.py` ALL PASS, dump 7 s, restore 20 s, counts equal, media restored in 8 s, written up in `BACKUP_RESTORE.md` and `RELEASE.md`; owed: the same on staging, and a rehearsed rollback there)**
- [ ] `T9.6` Monitoring: Sentry DSN per environment with release upload; alert routing to the support owner; queue and certificate checks. **(partly: Sentry DSN per environment is wired through the release workflow secret and `SENTRY_LARAVEL_DSN`; owed: the projects, release upload of symbols, alert routing to a named support owner)**
- [ ] `T9.7` Physical matrix: one recent mid-range Android, one small-screen Android, one tablet (and an iPhone if iOS is in scope); fresh install and upgrade with a pending queue; flaky 3G profile. **(owed: needs physical phones)**
- [ ] `T9.8` Distribution: Play internal-testing track for the pilot; no public listing before acceptance. **(owed: needs the Play account; steps in `RELEASE.md` section 2)**

### GATE 9 — binary

- [ ] Signed build installs, upgrades and reports an error to Sentry
- [ ] Staging is HTTPS and separate from production
- [ ] Restore performed and timed; rollback rehearsed
- [ ] Media opens on a real phone from staging

---

### PHASE 10 — Acceptance and handoff

**Duration: 8 days plus pilot. Closes: Cahier §10.6 and the "validation écrite de la recette".**

- [ ] `T10.1` Demo rehearsal with the clinic on the **candidate build**: the six journeys of Cahier §5, recorded.
- [ ] `T10.2` Triage: zero open critical/high; every lower item has an owner, workaround and the clinic's written approval.
- [ ] `T10.3` Handover (Cahier §6, "propriété et accès"): repositories, cloud, domains, store accounts, database and backups, keystore, Sentry; **no critical component tied to a developer's personal account**.
- [ ] `T10.4` Documents: README, install, variables, deploy, demo accounts, short French user guide, runbook, backup/restore, release and support documents, privacy note.
- [ ] `T10.5` Legal gate: RGPD/HDS analysis, hosting location, processor agreement, retention, device-loss procedure. **Real patient references enter only after this is signed**; until then anonymised demo data.
- [ ] `T10.6` Written acceptance naming build, backend deployment, devices, printer, roles, evidence and known limits, signed by a named clinic representative.
- [ ] `T10.7` Pilot rollout under a named support owner; daily check of sync failures and failed jobs for the first two weeks; practiced rollback.

### GATE 10 — binary

- [ ] Signed acceptance on file
- [ ] Every access handed over and confirmed by the owner
- [ ] Recorded demo delivered
- [ ] Support owner named

---

## Part 4 — Definition of done (Cahier §10, one line each)

1. Full demo journey on staging, no hidden fake data → Phase 8 + 10
2. Rights tested; a clinic never reads or writes another's data → `T8.1`
3. Web and mobile on the same API, coherent after create/edit/scan/sync → journey 6, `T8.7`
4. Critical error scenarios handled (double tap/scan, network cut, invalid data, failed print) → Phase 2 + `T8.3`
5. No open blocking/critical anomaly; backup and restore truly tested → `T8.6`, `T9.5`
6. Code, access, documentation and recorded demo handed over → Phase 10

*"Une fonctionnalité seulement visible sur une maquette ou non testée n'est pas considérée comme livrée."* — a box is ticked only with an artifact: a passing test, a script run, or a dated device-log entry.
