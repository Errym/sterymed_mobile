# SteryMed: clinic release master plan

**Fresh source review: 1 October 2026. Status: implementation and acceptance work remains.**

This is the continuation plan for the existing Flutter app and its Laravel backend. It was rebuilt from source and the two original documents in `pjdocs`. The previous `PRODUCT_COMPLETION_PLAN.md` and `project_dump.txt` were not used. This review does not certify a running deployment or guarantee that software can never fail.

**Release target:** the agreed clinic workflows work on the supported Android and iOS devices, all six roles have verified access, records survive interruptions, and no unresolved critical, high-severity, or workflow-blocking defects remain. A named clinic representative accepts the actual release build.

## 1. How to use this plan

1. Work through the phases in dependency order. Start the backend contract and Apple build work in Phase 0 while mobile foundation fixes proceed.
2. Use the task IDs below in branches, PRs, regression tests, and the completion ledger. Every task starts **OPEN** unless explicitly marked otherwise.
3. Each implementation PR includes its regression checks. Phase 8 adds complete system journeys; it is not the first testing phase.
4. Close a task only with a commit, passing checks, and evidence for its stated acceptance condition. A screen, DTO, test filename, or success toast alone is insufficient.
5. Recheck the source fingerprint before resuming later. Both repositories contained uncommitted work during this review; HEAD alone does not describe this snapshot.

Supporting records:

- [Source review scope and inventory](SOURCE_REVIEW_SCOPE.md).
- [Detailed source findings](SOURCE_AUDIT_FINDINGS.md).
- [Per-file review inventory](SOURCE_REVIEW_INVENTORY.csv), including explicit exclusions.

### Evidence baseline

| Item | What is established |
|---|---|
| Mobile checkout | `C:\Users\mery\sterymed_mobile`, HEAD `557d767904baa132f86a6f1373e34e746a0b543f`, plus working-tree changes |
| Backend checkout | `C:\Users\mery\steriqore`, HEAD `6af6b9cf2d6d5e1b51f4b1d2d1f5cc55a604b111`, plus working-tree changes |
| Original requirements | Full text of the DOCX and all 16 PDF pages in `pjdocs`; PDF text extraction is not a visual review of mockups |
| Existing test baseline | Previous session: 460 Flutter tests passed and analyzer was clean. The emitted LCOV report showed 34.5% line coverage; this is not proof of coverage of every source file |
| This review | Source inspection and planning. No new application/backend implementation changes or live clinical mutations |
| Still unproven | Current live backend acceptance, signed distribution builds, physical Android/iOS journeys, upgrades, printer/scanner compatibility, operational recovery, and clinic sign-off |

The user-deleted `pjdocs/New Text Document (2).txt` was not restored. Existing user changes and the untracked Windows test script were preserved.

## 2. Product assessment and scope

**The project has substantial feature implementation. Clinic readiness is still blocked by data integrity, session isolation, workflow completeness, and release validation.** A numerical completion percentage would conceal these differences.

Keep Flutter, BLoC/Cubit, GetIt, Dio, the existing feature/repository structure, shared visual components, and the Laravel API. Repair the actual routed paths before cleaning up unused alternatives. Do not spend the first phases on a redesign or broad dependency upgrade.

### What already exists

- Login, tenant registration, session storage, permissions, routing, and a shared French UI.
- Devices, programs, maintenance, cycle creation/transitions, instruments, controls, attachment upload/delete, label generation, and release decisions.
- Label scanner, label details, patient references, usage recording, non-conformities, alerts, audit, and evidence search.
- Product/supplier management, stock levels and movements, purchase orders, and partial receipts.
- Prosthetic dashboard, cases, status history, waiting placement, laboratories, independent payment permissions, upload/delete, drafts, and PDF generation. Restarting a cancelled case already exists.
- Data export requests, download, and opening files. They need completion and verification, not reimplementation.
- Unit/widget/contract/golden tests and two implemented live mobile journeys. Backend feature and web acceptance tests also exist.

### Requirements translated into deliverables

| Original requirement | Current source position | Completion phase |
|---|---|---|
| One clinic/site pilot with web administration and Android/iOS | Broad scaffolding exists; first-use and release proof incomplete | 0, 3, 9, 10 |
| Six roles and accountable actions | Real grants exist; route/action parity and ownership edge cases need verification/fixes | 1, 3, 8 |
| Product search, details, quick creation, and 2D code workflows | CRUD exists; scanner currently resolves labels only | 3, 5 |
| Stock entry/exit by scan, quantity/reason, weak-network recovery | Movement forms/outbox exist; scan workflow and durable correctness incomplete | 2, 5 |
| Full/partial receipt, lot, expiry, photo proof | Partial receipt exists; first-stock location selection deadlocks and photo proof is missing | 3, 5 |
| Guided sterilization with controls, evidence, release, and history | Main flow exists; destructive editing and incomplete evidence reading block acceptance | 4 |
| Label preview/print/reprint on web; scan/details/use on mobile | Both sides exist; scan/reprint semantics and physical output need correction/validation | 4, 8, 9 |
| Alerts, dashboard, audit, search, exports | Implemented with silent errors, incomplete counts and evidence gaps | 7 |
| Prosthetic creation in under two minutes, lifecycle, waiting list, combined filters, payments | Implemented broadly; filtering, monetary validation, attachments and drafts need fixes | 6 |
| Offline minimum for prosthetic forms | Draft mechanism exists but ownership and save/restore races remain | 1, 2, 6 |
| Common screens under two seconds | A product acceptance target; no fresh device measurements here | 9 |
| Connector if access exists, otherwise documented mock | Establish the actual agreed connector and validate it against a fixture or sandbox | 0, 7 |
| Owner-controlled repositories/cloud/stores, backups, complete demo and written acceptance | Requires operational evidence and named owners | 9, 10 |

Product boundaries:

- French is the pilot language. Dark mode, AI recommendations, advanced billing, and broader analytics are not prerequisites unless explicitly added to the contract.
- Preserve the adopted pseudonymous patient-reference model in [ADR 0011](adr/0011-prosthetic-module-adopted.md). The PDF's patient-name examples do not automatically authorize adding identifiable patient data.
- The prosthetic brief puts attachments in both future scope and explicit mobile acceptance. Since uploads already exist, complete their basic selection/viewing/error flow; defer automation.
- Prosthetic notifications are deferred in that brief. Core alert delivery needs an explicit pilot channel; an OS permission switch does not implement notifications.
- Web administration owns site setup and label printing under the original brief. Mobile must nevertheless obtain usable lookup data and guide users through handoffs.

## 3. The six roles: current server grants

Authority: backend `SeedTenantRolesAction`, policies, request authorization, and controllers; mobile `SessionStore`, `RoleGuard`, and screen actions. There is no seventh `staff` or `receptionist` role.

All six receive read permissions for sites, products, suppliers, purchasing, inventory, alerts, devices, cycles, labels, patients, usages, non-conformities, and prosthetic cases. Read grants do not imply permission to execute a mutation.

| Capability | Owner | Admin | Stock manager | Releaser | Practitioner | Viewer |
|---|---|---|---|---|---|---|
| Common domain reads above | Yes | Yes | Yes | Yes | Yes | Yes |
| Products/suppliers/purchasing/inventory/alerts management | Yes | Yes | Yes | — | — | — |
| Devices/programs/maintenance and cycle preparation/transitions | Yes | Yes | Yes | — | — | — |
| Label management | Yes | Yes | Yes | — | — | — |
| Cycle release and non-conformity management | Yes | Yes | — | Yes | — | — |
| Patient/usage and prosthetic clinical management | Yes | Yes | — | — | Yes | — |
| Prosthetic payment management | Yes | Yes | — | — | — | — |
| Team invitations/revocation, membership disable, site management | Yes | Yes | — | — | — | — |
| Audit, bulk/evidence exports, practice settings | Yes | Yes | — | — | — | — |
| `evidence_settings.manage` | Yes | — | — | — | — | — |

Important source distinctions to resolve in Phase 3:

- DLU-rule API mutations use `labels.manage`; web evidence settings use `evidence_settings.manage`. Document and test the intended distinction instead of assuming the owner-only web rule covers the API.
- Prosthetic clinical and payment updates have different permissions. The controller rejects a mixed request containing unauthorized fields; the client must send only the authorized patch.
- Admin can currently invite an owner. Membership disabling lacks a self/last-owner guard. Agree the ownership policy and enforce it server-side.
- A label GET currently mutates state despite using a read permission. This undermines the viewer role and passive lookups; fixing semantics belongs to Phase 4.

### Required role journeys

| Role | Positive acceptance | Negative acceptance |
|---|---|---|
| Owner | Provision clinic, invite roles, configure agreed settings, perform exports, review traceability | Cannot cross tenants; cannot accidentally remove the final accountable owner |
| Admin | Run administration, stock/cycles/clinical/payment workflows within grants | Owner-only settings and ownership changes obey the agreed policy |
| Stock manager | Receive, issue/adjust/transfer, maintain devices, prepare cycles and labels | Cannot release, record a clinical usage, or edit prosthetic payment/clinical fields |
| Releaser | Read full controls and attachments, decide release/rejection, handle non-conformities | Cannot alter the load or stock; denied writes preserve the record |
| Practitioner | Select an eligible practitioner/patient reference, record usage, manage prosthetic clinical steps | Cannot change payment fields or release a cycle |
| Viewer | Read permitted records and evidence with accurate loading/error states | No accidental writes through scan/GET, deep links, stale buttons or replay |

Test every row through UI, direct routes, direct API calls, changed permissions during a session, and restored local state. UI hiding complements server enforcement.

The current seeder is not proof that deployed tenants have these grants. Verify actual `/me` responses and permission migration/reseeding on staging. No application-wide owner bypass was found in the reviewed policies/providers.

## 4. Release blockers that determine the order

Severity here is a delivery priority based on source behavior, not a claim that an incident has already occurred. **P0** means credible tenant/actor attribution, duplicate-write, evidence-loss, or unsafe state risk. **P1** means a required journey is blocked or materially misleading. P2 work remains required where it is in the agreed release scope.

| ID | Priority | Confirmed source problem | Tasks |
|---|---|---|---|
| F01 | P0 | Global cache/drafts/outbox lack owner scope; queued requests use the current token | S01–S03, O01–O03 |
| F02 | P0 | Online failure creates a new replay key; response loss can duplicate a committed write | O01, O04 |
| F03 | P0 | Worker can overlap; killed `syncing` items are stranded; session changes are not fenced | S01, O02–O03 |
| F04 | P0 | Cycle item edit deletes first and drops `batch_id` when recreating | C01 |
| F05 | P0 | Passive label lookup consumes printed labels; reprint can move Used/Expired back to Printed | C03–C04 |
| F06 | P0 | Prosthetic practitioner request validation accepts globally existing users without tenant membership | R02, P01 |
| F07 | P0 | Export copies attachments by filename, so identical names overwrite evidence | A04 |
| F08 | P1 | Device repositories cache different list types under `devices` | S04 |
| F09 | P1 | First receipt cannot choose a location when the tenant has no stock | R03, I01 |
| F10 | P1 | Release detail does not load the decision; evidence failures appear as empty sections; releaser cannot properly open evidence | C02 |
| F11 | P1 | Prosthetic page two loses filters; money input can clear values on invalid French decimals | P02–P03 |
| F12 | P1 | Dashboard failures become healthy-looking zeros; alert conflict/error states can be hidden | A01–A02 |
| F13 | P1 | Mobile release signing/identifiers and release pipelines are unfinished; physical acceptance absent | G02, D01–D03 |
| F14 | P1 | Media URLs target an emulator/internal host; attachment viewing is incomplete | C02, P04, D02 |
| F15 | P1 | Unencrypted local payloads and inadequate debug-log redaction conflict with confidentiality expectations | S03, S05 |
| F16 | P1 | Account recovery, complete lookups, scanned inventory and receipt photo contracts need completion | G01, R03, I01–I03 |
| F17 | P1 | Membership/ownership and identity deletion paths need protection; historical relations must survive archiving | R02, A04 |
| F18 | P1 | Deployment/CI has configuration gaps; Docker context can include a non-example environment file | G02, D04 |

Exact file and line evidence, secondary defects, and hypotheses requiring reproduction are in [the source findings](SOURCE_AUDIT_FINDINGS.md). Backend dependency work is included because the mobile client cannot correct an unsafe server transition or recover overwritten export evidence.

## 5. Phases and acceptance checks

Owners: **M** mobile, **B** backend/web, **J** joint implementation, **C** clinic/product owner. These are responsibilities, not requests for extra staffing.

### Phase 0 — Freeze the contract and make validation repeatable

**Purpose:** resolve dependencies before implementing workarounds. No production clinical data is needed.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| G01 | J/C | Build a requirement-to-journey/API matrix from these documents and actual routes. Decide patient-reference scope, practitioner eligibility, clinical release prerequisites, DLU authorization, notification channel, ownership policy, and connector scope. Each decision has a named owner; no invented endpoint or silent reduction of required scope |
| G02 | J | Record source hashes, dirty-tree changes, SDK/toolchain pins, staging URLs and artifact configuration. Begin a clean Mac iOS build and Android release-signing setup immediately. Create backend tickets for F05–F07/F17/F18, idempotency, print layout, and deployment defects |
| G03 | J | Reproducible disposable fixtures: two tenants, all six roles, disabled/archived memberships, empty clinic, populated clinic, more than one page, all cycle/label/prosthetic states and duplicate attachment filenames. Fixture creation/reset must identify its test environment and never reset a clinic database |
| G04 | J | Run baseline analyzer/tests/build checks and capture exact commands/results. Make test runners propagate failure. Inventory tests of unused screens separately. Replace mutable hand-seeded journey prerequisites with fixture IDs and assertions |

**Exit:** contract gaps are explicitly owned, the same test state can be recreated, and toolchain/build failures are visible. G02 continues in parallel until Phase 9.

Contract work to record under G01/R03/R05:

| Client need | Current API source | Required next step |
|---|---|---|
| Forgot/reset password | Mobile constants exist; corresponding API routes do not | Add an agreed API flow or a working web recovery handoff; test actual links |
| Empty locations and complete batch choices | No API location/batch list; current mobile derives choices from stock levels | Supply authorized lookup endpoints with complete pagination and empty-location support |
| Eligible practitioner picker | `/v1/members` exists but team administration permission is too broad a requirement for a clinical picker | Define a minimal tenant-scoped eligible-practitioner response |
| Atomic cycle-item editing | Current API exposes list/create/delete, no update | Add atomic update or explicitly restrict editing; never simulate with destructive delete/create |
| Passive label details and NC subject lookup | `GET /v1/labels/{code}` also performs scan state changes | Separate lookup and explicit command semantics |
| Persisted release details | `GET /v1/cycles/{cycle}/release` exists | Wire the existing read contract into mobile detail |
| Receipt evidence/history | Receipt creation exists; dedicated receipt attachment/list APIs are absent | Complete the agreed contract, reusing existing web/domain behavior where applicable |
| Filtered evidence export | `GET /v1/evidence-search/export` exists | Wire the permitted mobile action and verify filter parity |
| Invitation acceptance | API accept exists; emailed web target has no matching web route | Implement the supported installed/uninstalled-app handoff and expiry recovery |

These describe the reviewed source, not the result of probing a deployed server. Newly added paths must be designed and versioned before client implementation.

### Phase 1 — Protect sessions, local data and diagnostics

**Depends on:** G01–G04. Main files: `lib/core/storage`, `lib/core/network`, `lib/core/cache`, `lib/features/auth`, `lib/di`, `lib/bootstrap.dart`.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| S01 | M | A single session lifecycle with an environment/tenant/user identity and generation. Stop/fence requests and worker results on replacement/logout. Clear local authenticated state before slow revocation completes; late logout/401 responses cannot clear a newer login. Prove A→logout→B with delayed requests |
| S02 | M | Separate invalid credentials from offline/server failure on restore. Validate session payloads, expire permissions deliberately, and define permitted offline reads/drafts. Render the first frame without waiting for queue replay; corruption becomes a recoverable state, never an unexplained boot crash |
| S03 | M | Versioned, encrypted, owner-scoped drafts/outbox/clinical caches with migration and key-loss handling. Preserve unsent legacy work in quarantine until ownership can be established; never assign it to the next login or silently wipe it. Test upgrade, process kill, account switch and missing key |
| S04 | M | Typed cache ownership/keys, including the device model collision; invalidate related lists/dashboard after confirmed writes and sync. Isolate in-memory BLoC state on logout. Repeated navigation between devices and cycles cannot throw or show another account's cached data |
| S05 | M | Structured allowlisted diagnostics; redact tokens, identifiers, URL queries and nested payloads. Normalize errors once, preserving safe code/field errors/request ID. Distinguish cancellation, transport, authentication, permission and validation. Tests inspect actual log/event structures |
| S06 | M | Own/cancel connectivity subscriptions; wire resume checks; initialize version metadata. Correct recovery/logout messaging, empty-name initials, stale fallback roles and disposal races. A failed global revocation must not claim every remote session ended |

**Exit:** two accounts and two tenants can share a device without local data exposure, wrong-actor replay, or late-response session corruption. Storage migration preserves pending records.

### Phase 2 — Make writes durable and synchronization honest

**Depends on:** S01–S05 and the server idempotency contract. Main files: `outbox/*`, `sync/*`, retry/idempotency interceptors, mutation repositories, queue/status UI.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| O01 | J | Create a durable operation before the first request: immutable ID/key, original event time, exact payload encoding, method/path, owner scope, schema, resource identity and attempt metadata. Online send and replay use that same operation. A server commit followed by dropped response results in one business mutation |
| O02 | M | One serialized worker for automatic/manual retries, startup recovery of interrupted attempts, persisted retry schedule, bounded backoff, per-resource ordering and explicit auth pause. Connectivity changes, resume and manual retry cannot create concurrent sends |
| O03 | M | Queue states distinguish pending/sending/unknown outcome/auth blocked/conflict/validation failure/confirmed. Show original owner and operation context only within the authorized scope. Correcting a rejected operation creates a deliberate replacement; deleting unresolved work requires explicit loss-aware confirmation |
| O04 | VERIFIED (backend, live) | Durable `api_operations` record written in the same transaction as the effect, tenant+user+key scoped, Postgres advisory lock held to commit, 90-day retention + `idempotency:prune`, 5xx/429/408 never remembered and a 5xx request's writes rolled back, uploads covered, `IDEMPOTENCY_IN_PROGRESS` for in-flight duplicates, public endpoints keep a 24 h cache so tokens are not stored. 14 Pest tests; live: 8 concurrent requests with one key created 1 row (8 before) and a key replays after worker restart + cache clear. PATCH/DELETE verified absolute (no increments), so not keyed |
| O05 | VERIFIED (unit + widget) | `used_at` captured at the clinical event and replayed unchanged; **pending marker** banner on cycle, label, purchase-order and stock screens ("waiting to be sent" / "could not be confirmed"), tested |
| O06 | VERIFIED (unit) | `OFFLINE_MATRIX.md` matches the engine. Online-only creates reuse their key after a lost answer (30 min, per app run), tested. Definitive 4xx answers (e.g. `409 INSUFFICIENT_STOCK`) are now rejections, not "unknown outcome" (bug found by fault-injection test). Prosthetic: draft kept, network required, as the plan's policy says |
| Phase 2 carry-overs | CLOSED | (1) Reconciliation after the window: replaced by a durable server record, so an unknown outcome is recovered by resending the original key for up to 60 days (server keeps 90); only a never-resent item older than that needs a manual check. (2) PATCH/DELETE: verified idempotent by construction; uploads now covered. (3) Web UI tests: 175 failing in this runner both before and after, identical sets (no Vite build), so not caused by the change. (4) Key reuse for online creates is per app run by design (queued writes persist their key). (5) Live proofs need the dev Docker stack: documented, opt-in. (6) Pending balance on stock screens is a Phase 5 task |
| Others | OPEN | Not started |

Historical passing tests do not close tasks introduced by this audit.

A clinic candidate is ready only when:

- Agreed requirements map to implemented, reachable and accepted journeys.
- All six roles and tenant boundaries pass positive and negative checks.
- Interrupted writes produce no duplicate/lost records or false success, including upgrade and account switching.
- Clinical evidence can be read, linked, exported and recovered with original identities/times intact.
- Required Android/iOS, printer/scanner, network and performance acceptance passes on the actual candidate.
- Deployment, backup restore, queue/jobs, support and ownership are exercised and documented.
- There are no unresolved P0/P1 issues; remaining limits are explicitly accepted by the clinic.

This provides a measurable finish line. It avoids confusing feature breadth, a green analyzer, or a test count with an accepted clinic product.
