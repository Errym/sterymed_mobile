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
| O04 | B/J | Make idempotency concurrency-safe and define expiry/reconciliation. Current cache retention is finite, so old uncertain operations must not be blindly resent. Address endpoint/body/tenant scoping, concurrent identical keys, multipart behavior and unavailable replay storage. Prove server-side counts and stock deltas, not only identical response text |
| O05 | M | Surface pending operations on the affected record, deduplicate taps, preserve last confirmed data, refresh after acknowledgement and reconcile rejected actions. Capture `used_at` at the clinical event, not on eventual server replay |
| O06 | J | Publish and implement the offline matrix below. Flush on a valid session/reconnect/resume without blocking launch. Counts include in-flight and blocked work; no green “synchronized” state while work is unresolved |

**Exit:** kill/relaunch, timeout after commit, duplicate tap, reordered events, two-device conflicts, 401/403/409/422/429/5xx and retry after retention expiry all preserve correct server records and an understandable user state.

### Phase 3 — Complete role-correct clinic setup and lookups

**Depends on:** Phase 1; mutation screens also depend on Phase 2.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| R01 | M/J | Audit every actual route and action against the six-role matrix. Include deep links, camera/usage, attachments, exports, DLU and mixed prosthetic fields. Refresh permissions; denied actions cannot keep stale success state. Do not rely on unused screens to prove authorization |
| R02 | B/J | Enforce tenant-member practitioner assignment and agreed active/role eligibility. Protect ownership transfer/invitations/self-disable/last owner; preserve identities needed by historical records when accounts are removed. Test foreign, disabled and archived IDs through direct API requests |
| R03 | J | Add/complete authorized, paginated lookup contracts for locations, batches, products and eligible practitioners. Read real empty locations independently of stock quantities. An empty clinic can be provisioned on web and receive its first delivery on mobile without database edits |
| R04 | M | Complete catalog/device/supplier edit behavior: async selection options, archived selections, nullable PATCH clears, locale validation, ID detail reads, real refresh and complete pagination/search. Existing populated records can be opened and changed without dropdown assertions or unrelated fields being erased |
| R05 | J | Finish account recovery and any required invitation acceptance handoff against real server routes. Handle expired links, invalid tokens, retry and return to login. A screen pointing at a missing API is not a completed recovery workflow |

**Exit:** each role can enter a correctly provisioned clinic, retrieve complete permitted choices, and perform only its actions. The empty-clinic journey is a first-class acceptance fixture.

### Phase 4 — Finish sterilization, label use and incident traceability

**Depends on:** Phases 1–3. Clinical rules in this phase require the clinic's G01 decision; software must then enforce the same rule on client and server.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| C01 | J | Replace delete-then-create cycle item editing with a supported atomic update or an explicitly restricted edit flow. Preserve item/batch identity. Expose real batch linking and remove misleading “link later” guidance. A failed edit leaves the original load intact |
| C02 | M/J | Load persisted release decision and per-section evidence states. Provide read access, full image/PDF viewing and retries for releasers/viewers, with mutation actions separately gated. Missing/failed loads cannot look like verified empty evidence. Reopened cycle shows decision, reason, actor and time |
| C03 | B/J | Separate passive label lookup from a state-changing scan/use command. Define printed/scanned/used/expired/recalled/voided behavior, duplicate use and offline limits. NC subject selection and viewer reads never consume labels; blocked labels remain selectable for an incident |
| C04 | B/J | Prevent reprinting from restoring an invalid or used label to usable stock. Enforce reason and audit semantics for reprints. Render the selected label format/layout and agreed fields; validate actual printer output and both supported code types |
| C05 | M/J | Guide cycle creation into the created record/load, filter eligible devices/programs, display authoritative transitions and pending state. Enforce agreed controls/evidence requirements server-side. Failed controls, inactive equipment, missing evidence and concurrent changes have explicit acceptance cases |
| C06 | M | Complete scanner/manual fallback, permission/resume recovery, one lookup per intent and blocked-result handling. Distinguish a network error from an unsafe label. Usage history failure must not say “no usage”; use original event time, selected eligible practitioner and patient reference |
| C07 | J | Finish searchable/paginated NC subjects, resolution and required recall handoff, evidence dossier access and patient-reference history scope. Decide whether local cycle notes remain personal drafts or become official audited notes; UI and exports must reflect that choice |

**Exit:** prepare→load→controls/evidence→complete→submit→release/reject→web print→physical scan→patient usage→incident/evidence export works, with server readback proving every link. Recalled/expired/used labels and rejected cycles follow the agreed rules.

Backend/web checks included in C02–C05:

- Repair the web cycle attachment controller's missing extraction method/DTO reference and verify its real multipart upload/response flow.
- Validate that the selected active program belongs to the selected device. Recheck aggregate state under a lock or version condition before load edits, start and release; stale objects must not bypass transitions.
- Connect web physical printing and recorded print events deliberately. The current “print sheet” uses `window.print()` separately from the POST that records printing. Test cancellation/failure/retry and gate print controls by permission.
- Preserve clinical occurrence time and practice-local dates across midnight/replay. Separately record server receipt time; define explicit null and clock-skew behavior.
- Render the recorded print-format version and agree which historical operator/device/site values are snapshots. Regenerating evidence after a rename must follow that policy rather than silently changing its meaning.

### Phase 5 — Complete inventory and purchase workflows

**Depends on:** Phases 2–3 and G01 receipt/scan contracts.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| I01 | J | Implement product/batch code lookup and scanner modes for required stock entry/exit; offer manual search. Constrain source location/batch pairs, available quantity and valid transfer destinations. More than 100 stock rows and unused destinations remain usable |
| I02 | M/J | Validate every PO and receipt line: positive quantities, remaining quantity/discrepancy rules, locale prices, manufacturer lot and expiry policy. Never silently discard malformed lines or invent a physical lot from a timestamp. First, partial and final receipt each produce correct stock and traceability |
| I03 | J | Add required receipt photo evidence with durable upload/progress/retry and a linked readable server record. Preserve receipt form work on interruptions; define what happens when the receipt commits but its evidence upload fails |
| I04 | M/J | Complete required draft order edit/cancel, receipt history and supplier details; refresh correctly on return and after sync. Do not claim supplier delivery/email merely because an order status changed |
| I05 | J | Verify stock issue, adjustment and transfer across expired/recalled/insufficient stock, simultaneous operators and retries. Show pending changes separately from confirmed balance. Preserve historical references when products/suppliers are archived |

**Exit:** an empty clinic can order and receive its first physical delivery, scan an item, move/use it, complete a partial order later and recover from lost connectivity without duplicate stock deltas.

I05 also defines how to archive a site/location containing stock. Existing web test source allows archiving a populated location; agree transfer/block/history behavior and test that no balance becomes operationally inaccessible.

### Phase 6 — Complete prosthetic clinic work

**Depends on:** Phases 1–3. Preserve the already implemented status lifecycle and clinical/payment permission split.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| P01 | J | Resolve eligible practitioner selection/self-assignment, tenant validation, pseudonymous patient selection and archived laboratory handling. Case create/edit uses valid complete lookups and retains an unavailable historical selection without crashing |
| P02 | M/B | Preserve the exact combined filter snapshot across every page, refresh, back navigation and request race. Make active/today/unpaid KPI drilldowns match their counts. Waiting placement aging uses the agreed date/timezone and complete results, not only the loaded page |
| P03 | M/J | Validate French decimal input, nonnegative amounts and unknown-vs-paid state. Never convert malformed money to a null PATCH. Preserve authorized fields only; warn before placement with outstanding payment without adding an unauthorized hard block. Do not invent an automatic balance calculation without a total-price contract |
| P04 | M/J | Open/download attachments, support the agreed camera/gallery/document inputs, handle denied permissions and expired URLs, and make long case PDFs paginate. Independent history/attachment failures must not erase the usable case view |
| P05 | M | Finish durable drafts: dates/selectors as well as text, orderly awaited save/submit/clear, migration, stale ID validation, restore/discard and account isolation. Refresh lists/dashboard after create/edit/status/payment. Typed-only form work survives app termination within the defined save contract |
| P06 | J/C | Validate impression→sent→received→scheduled→placed and cancellation/restart, actor/time/reason history, waiting/reminder behavior, combined filters and role restrictions. Observe representative case creation under two minutes |

**Exit:** clinical staff and payment administrators can complete their work independently without data erasure, disappearing filters, inaccessible attachments or stale waiting lists.

P06 includes concurrency-safe status changes and the intended database protection for append-only prosthetic history. Current history has RLS and a cascading case foreign key, but lacks the immutable trigger used by other evidence tables. There is no claim here that an arbitrary history-edit API is exposed.

### Phase 7 — Make monitoring, records and everyday UX trustworthy

**Depends on:** completed domain contracts and Phase 1 error handling.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| A01 | J | Use correct complete aggregate counts and permission-aware dashboard sections. Distinguish unavailable/partial/stale data from zero; normalize statuses consistently. Pull refresh actually fetches fresh data |
| A02 | M/J | Resolve alerts with per-ID state, visible errors and code-specific conflict handling. Unknown severity remains visible. Add subject navigation and the agreed core notification channel with actual delivery proof; remove or accurately label any inert preference |
| A03 | M/J | Fix evidence/audit first-search loading/failure, reset, filter races, pagination errors, date bounds and meaningful details including actor/reason/subject. Implement required filtered evidence export through the existing contract and verify it matches the search |
| A04 | B/J | Preserve all export attachments with unique archive paths and manifest/checksum consistency. Read historical records after product/supplier/user changes. Handle export job failure, readiness, expired links and file-opening failure; archives with repeated `photo.jpg` filenames retain every original |
| A05 | M | Shared list/search refresh semantics, loaded-empty pagination, cancellation/generation guards, form validation and selection behavior. Handle empty/archived names, picker date bounds, small screens, keyboard and large text. Register Inter correctly before deliberately reviewing updated goldens |
| A06 | J/C | Validate the agreed connector or clearly labeled mock; document setup, supported data, errors and limits. Finish accurate About/privacy/help/build-version text and support/request IDs. Unused analytics scaffolding is optional; sensitive telemetry is not added merely to fill it |

**Exit:** the clinic can tell “nothing needs attention” from “data could not be loaded,” investigate a record, obtain a complete archive and recover from ordinary UI/network errors.

Backend/web checks included in A02–A04:

- Run digest/notification reads under the real restricted PostgreSQL role and tenant context. Disabled members must not remain eligible recipients solely because a role assignment still exists.
- Make displayed alert settings effective and close stale alerts when a batch is consumed or a threshold is disabled. Agree any missing-control-test alert requirement in G01.
- Dispatch export jobs after transaction commit, recover failed/stuck jobs, and fail explicitly on missing media or failed storage writes. Define the portable archive scope and consistency during concurrent changes.
- Audit displays must show an explicit cleared value as cleared; the current web value diff can present the previous value as the new one when the new value is null.

### Phase 8 — Prove the complete system

**Depends on:** corresponding feature phases; test development proceeds alongside them.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| V01 | J | Run the six-role/two-tenant matrix and direct API authorization tests. Include ownership, foreign practitioner, disabled membership, read-only scans, archived historical entities and mixed payment/clinical patches |
| V02 | J | Implement and run the missing mobile journeys: scan/use, stock movement, receipt, conflict, offline/restart, alert resolution, prosthetic lifecycle and waiting placement. Each uses isolated fixtures and server readback, and fails clearly if required infrastructure is absent |
| V03 | J | Deterministic fault injection: response lost after commit, two concurrent sends, kill between persistence/send/ack, old 401 after new login, permission change, request ordering, expiry and storage migration. Verify both UI state and persisted business effects |
| V04 | J | Regression coverage for backend prosthetic/laboratory routes, label transitions/print output, export collisions, restricted database role/jobs and migration/deployment configuration. Do not let a missing contract snapshot silently skip a required CI check |
| V05 | J | CI gates for analysis, relevant unit/widget/contract tests, meaningful changed-code coverage, web checks and reproducible builds. Keep test count and coverage claims scoped to actual files; unused-screen tests do not satisfy routed journey acceptance |

**Exit:** required jobs run and pass with stored logs/artifacts. No empty journey file or opt-in skip is counted as a completed test. All P0/P1 findings have a regression and a verified resolution.

Before relying on targeted PHP tests, G04/V05 must move fixture helpers out of peer test files into explicit shared fixtures. Repair immutability assertions that issue a second failing SQL statement inside an already-aborted transaction; assert the intended database rejection using separate transactions/savepoints. Add stable unique cursor ordering and a more-than-one-page equal-date/name fixture to verify each result appears once.

### Phase 9 — Release artifacts and operational readiness

**Depends on:** Phase 8; build, hosting and signing preparation starts at G02.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| D01 | M/C | Owned bundle/application IDs, production signing, explicit environment/HTTPS guards, genuine package version, working Android release and iOS archive. Populate release pipelines/store metadata and fix permission configuration. Install the exact candidate through the intended distribution channel |
| D02 | J | Validate reachable signed media URLs on physical Android/iOS and web; avoid emulator host substitutions in production. Test camera denied/permanently denied/resume, image/PDF uploads, download/open, TLS failure, app lifecycle and the actual clinic printer/scanner |
| D03 | J | Test fresh install and upgrade with pending queue/drafts, supported OS versions, narrow and tablet layouts, large text and representative network conditions. Measure common screen times against the under-two-second requirement using a documented device/data/network profile |
| D04 | B/J | Fix fresh deployment credentials/migration-role setup, CI database/Redis prerequisites and Docker context exclusions. Verify queue/idempotency storage durability under restart/memory pressure. Exercise scheduled jobs, export workers, monitoring, backup restore and rollback in a non-production environment |
| D05 | J/C | Complete owner access, signing-key custody, data retention/device-loss procedure, alert/support ownership, incident steps and recoverable deployment documentation. Make exported/local-file cleanup and truthful confidentiality claims part of acceptance |

**Exit:** identifiable signed artifacts can be installed, upgraded, monitored and supported. Recovery has been exercised, rather than inferred from a backup script's existence.

Verify deployed values rather than treating source defaults as production facts: mail delivery, backup destination/monitor, restore verification, queue retry/timeout/after-commit settings, tenant context in long-lived workers and upload cleanup. If mobile MFA is required, the current bearer login needs an agreed flow; web Fortify configuration alone does not supply it.

D04/D05 also replace stale setup commands referencing the absent backend `steriqore.sh`, and rehearse rollback with realistic alert history: reverting the open-only uniqueness migration can conflict with accumulated resolved rows.

### Phase 10 — Clinic acceptance and handoff

**Depends on:** all release gates above.

| Task | Owner | Deliverable and acceptance |
|---|---|---|
| H01 | J/C | Clinic staff perform the agreed demo with realistic test records on the candidate build: setup, receipt, stock use, cycle release, print/scan/usage, prosthetic return/placement, alert handling and evidence export |
| H02 | J/C | Triage every acceptance issue. Zero unresolved critical/high defects, zero blocked required journeys, and no unresolved record loss/duplication/tenant attribution. Lower-severity accepted limitations have an owner, workaround and explicit clinic approval |
| H03 | J/C | Written acceptance names build/version, backend deployment, devices, printer, tested roles, evidence and known limits. Deliver French user instructions, setup/runbook/backup-restore/release/support documents and account access |
| H04 | J/C | Roll out under a named support owner, inspect sync/failed jobs and feedback, and retain a practiced rollback/recovery path. A failed gate returns to its owning phase |

**Exit:** the clinic has accepted the exact product it will use and someone can operate and support it.

## 6. Offline behavior to implement and test

This is the proposed safe delivery policy. G01 records any clinic-approved adjustment; current outbox enums do not themselves establish that an action is safe offline.

| Action | Offline behavior | Reconnection rule |
|---|---|---|
| Read an already fetched record | Owner-scoped snapshot with stale timestamp; no claim of current availability/release | Refresh and reconcile before decisions requiring current state |
| New lookup/scanning without verified cached data | Explain that online verification is needed; retain typed/scanned input | Resolve against authoritative server state |
| Clinical usage already being entered | Preserve draft; queue only under the agreed validated context, with original event time and visible pending status | Same immutable operation; duplicate/conflict handling plus server readback |
| Stock movement/receipt | Preserve work; queue only where contract supports it. Local stock remains last confirmed; never promise availability from a pending write | Validate authoritative balance/state; surface conflicts for resolution |
| Cycle transitions | Preserve last confirmed state and explicit pending intent where approved; order dependent actions | Confirm predecessor/current state before later actions |
| Cycle release, recall or other safety decision | Default to verified online evidence and explicit acknowledgement; preserve form inputs offline | Refetch evidence and submit deliberately under the authorized role |
| Prosthetic clinical/payment/status changes | Preserve a scoped draft; require online confirmation unless separately designed for safe replay | Revalidate IDs/current version and show conflicts |
| Attachment upload | Retain an authorized local draft/reference under a defined cleanup policy | Upload progress/retry and link to confirmed record; never imply upload completed |
| Permissions/session invalid | Pause sends; retain owned pending work securely | Resume only for matching authorized identity after revalidation |
| Old uncertain write beyond server replay retention | Show “outcome needs checking”; no fresh-key automatic resend | Reconcile against server operation/business record before replacement |

## 7. First five implementation PRs

Keep each change reviewable and preserve the existing user work. These are initial slices, not the full implementation estimate.

1. **Session generation and isolation (S01–S02):** late logout/401 regression, atomic replacement and nonblocking bootstrap. Fence worker activity while identity changes.
2. **Scoped persistence migration (S03–S04):** ownership/version metadata, legacy quarantine, encryption/key recovery, cache collision fix and account-switch regressions. Never reset the queue to make a test pass.
3. **One durable operation per intent (O01/O05):** immutable key/body/time before first send across usage, stock, receipt and cycle paths; commit-then-disconnect regressions.
4. **Serialized recoverable worker (O02–O03/O06):** startup recovery, auth pause, resource ordering, retry schedule and truthful queue UI, tested at every interruption boundary.
5. **Contract-backed clinical corrections (C01–C03):** atomic cycle item editing, readable release evidence and separate passive label lookup. Coordinate corresponding backend changes and prove role/traceability behavior.

Backend tenant-practitioner validation, export collision, idempotency concurrency, label/reprint and deployment fixes can proceed in parallel from Phase 0. They are release dependencies even if the mobile PRs land first.

## 8. Completion ledger and definition of done

For each task, record:

```text
Task ID:
Status: OPEN | IN_PROGRESS | BLOCKED | VERIFIED
Source commit(s):
Behavior changed:
Checks and exact result:
Device/backend/artifact used, if applicable:
Evidence location:
Remaining dependency or accepted limitation:
Reviewer/clinic acceptance, where required:
```

**Current ledger (updated 1 October 2026).** Evidence: `flutter analyze --fatal-infos` clean; `flutter test` 505 passed, 0 failed; Python tooling tests 9/9. No physical-device or live-backend run is claimed.

| Task | Status | Evidence / remaining |
|---|---|---|
| G01 | BLOCKED on clinic | Register and tickets exist (`phase0/CONTRACT_MATRIX.md` D01-D11, `BACKEND_DEPENDENCIES.md` BD-01..19); one-page [`CLINIC_DECISION_SHEET.md`](phase0/CLINIC_DECISION_SHEET.md) ready to send. No decision is approved yet |
| G02 | IN_PROGRESS | Toolchain pinned and `verify_release_config.py` passes (`phase0/BUILD_BASELINE.md`). Mac/iOS archive, store accounts, keystore custody, hosting: not started (need owner) |
| G03 | IN_PROGRESS | `testing/clinic_fixture` harness and its 9 tests exist; not yet run against a live disposable stack |
| G04 | VERIFIED | Green baseline above; flaky sync-engine test made deterministic; stray failing tests fixed |
| S01 | VERIFIED (unit) | Session generation, atomic envelope, late-write, logout and late 200/401 fencing tests in `session_and_storage_safety_test.dart` |
| S02 | IN_PROGRESS | Boot no longer waits for queue replay; corrupt storage becomes a recoverable state. Invalid-credentials vs offline restore separation not independently verified |
| S03 | VERIFIED (unit) | Encrypted owner-scoped boxes, legacy quarantine, key-loss lock, interrupted-migration idempotency, legacy outbox upgrade (`migration_and_diagnostics_safety_test.dart`). Queue screen now explains quarantined/locked data |
| S04 | IN_PROGRESS | Owner-scoped, type-checked cache and device key collision fixed (tested); BLoC state reset by session generation in `app.dart` has no dedicated test |
| S05 | IN_PROGRESS | HTTP diagnostics allow-listed and tested against token/URL/id leakage; Sentry scrub tested; "normalize errors once" not verified |
| S06 | IN_PROGRESS | Connectivity re-verified before flush, lifecycle resume check, subscriptions closed; failed-revocation messaging not verified |
| O01-O03 | IN_PROGRESS (built early) | Durable operation, serialized worker, unknown-outcome state exist with tests; not yet assessed against the Phase 2 acceptance list |
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
