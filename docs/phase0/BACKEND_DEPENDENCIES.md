# Phase 0: local backend dependency register

**G01/G02 record, 1 October 2026. All records below are OPEN. No external tickets were created and no backend source was changed.**

These records make backend work needed by the [contract matrix](CONTRACT_MATRIX.md) concrete. They use the canonical task IDs in the [master plan](../CLINIC_READY_MASTER_PLAN.md). `B` is the backend/web owner, `J` joint backend/mobile responsibility, and `C` the clinic/product decision owner. Personal owner names are pending assignment.

Evidence paths are relative to sibling repository `steriqore`, unless prefixed `mobile:`. Source behavior is confirmed against the reviewed working tree; exploit, race, storage and deployment outcomes still require the specified isolated acceptance tests. A declared route does not establish live availability. Source fingerprints are in [contract_snapshot.json](contract_snapshot.json) and the [full inventory](../SOURCE_REVIEW_INVENTORY.csv).

No endpoint name is reserved by a proposal in this register. New methods/paths, DTOs and errors must be agreed and added to the matrix before mobile implementation. Clinic release rules and notification channel remain pending; no medical or regulatory rule is inferred here.

## Access and required contracts

### BD-01 — Account recovery contract

> **Status 2026-10-02: DONE.** `POST /v1/auth/forgot-password` (non-enumerating 202, idempotent, rate-limited) sends the standard reset e-mail; the reset happens on the web reset page; the app shows exactly what to do next. 3 Pest tests + 6 widget tests.

- **Owner/task:** J, **R05**; prerequisite for J02. Required journey blocker.
- **Confirmed:** mobile calls a forgot-password API absent from `routes/api.php:47`; Fortify enables web recovery in `config/fortify.php:155`. Mobile source: `lib/features/auth/data/datasources/auth_remote_datasource.dart:37`.
- **Proposed scope:** choose a complete supported web handoff or API recovery flow, including tenant/account handling, actual reset link and return to mobile login. Do not keep a success-looking form pointed at an absent route.
- **Acceptance:** known/unknown email has agreed non-enumerating behavior; valid, expired and reused links are exercised; password changes permit a fresh login and have documented session invalidation behavior. Actual outgoing mail and external link reachability are verified in staging.

### BD-02 — Complete locations, batches, practitioner and scanned-code lookups

> **Status 2026-10-02: DONE except scanned-code lookup (Phase 5/I01).** `GET /v1/locations`, `/v1/batches`, `/v1/practitioners` exist, are paginated and tested; mobile consumes them. Empty-clinic first delivery proven live (`scripts/verify_empty_clinic_journey.py`).

- **Owner/task:** J, **R03, I01, P01**; prerequisites for J04/J07/J20/J22/J24. Required journey blocker.
- **Confirmed:** API declares sites and stock levels, but no location/batch list or product/batch-code resolver (`routes/api.php:59`, `:113`). `/members` requires invitation-create permission (`app/Http/Controllers/Api/V1/Identity/MemberController.php:31`). Mobile derives both pickers from the first stock page (`mobile:lib/features/stock/data/datasources/stock_remote_datasource.dart:20`, `:41`).
- **Proposed scope:** authorized tenant-scoped lookup contracts that include unused locations, complete batches/products with stable pagination, normalized supported codes and minimal eligible-practitioner fields. Preserve web ownership of site/room/location provisioning. Clinical eligibility rule remains decision D05.
- **Acceptance:** empty clinic can receive first delivery without direct database edits; an unused destination appears; more than100 stock rows and same-name entries remain selectable; bad/foreign/expired codes have explicit outcomes; practitioner can load only the permitted minimal picker without invitations permission.

### BD-03 — Non-destructive cycle item editing

- **Owner/task:** J, **C01**; J10. Record-loss blocker.
- **Confirmed:** routes expose list/create/delete, no update (`routes/api.php:170`). Current mobile simulates edits by delete/create; master-plan F04 records loss of `batch_id` and deletion-before-create failure.
- **Proposed scope:** atomic update preserving item/batch identity and allowed-cycle-state validation, or an explicitly approved restricted edit flow. Do not treat delete/create as an update transaction.
- **Acceptance:** server validation failure, lost response and concurrent start leave the original item intact; successful edit retains ID/batch and adds the required audit evidence. Retry produces one change.

### BD-06 — Tenant-safe clinical practitioner assignment

> **Status 2026-10-02: DONE.** One definition of eligibility (`ListEligiblePractitionersAction`, decision D05 default: active owner/admin/practitioner) used by the picker and by `EligiblePractitioner` validation on prosthetic create/update and label usage; a practitioner who later became ineligible may stay on an existing record.

- **Owner/task:** B/J, **R02, P01, C06**; J07/J16/J25. Tenant-attribution blocker.
- **Confirmed:** prosthetic requests only check global users existence (`app/Http/Requests/Api/V1/Prosthetic/CreateProstheticCaseRequest.php:31`, `UpdateProstheticCaseRequest.php:35`). Label usage checks tenant membership but does not encode the pending active/role eligibility rule (`app/Http/Requests/Api/V1/Traceability/RecordLabelUsageRequest.php:27`).
- **Proposed scope:** enforce tenant membership and agreed eligibility on create/update/usage; expose the minimal picker in BD-02. Decide explicit practitioner selection/self-default without substituting an arbitrary current administrator.
- **Acceptance:** foreign-tenant, disabled, invited and archived/ineligible users are rejected consistently; eligible same-tenant practitioner succeeds; denied requests create no case/usage/history. Existing historical practitioner remains readable.

### BD-07 — Ownership, identity disable and DLU authorization

> **Status 2026-10-02: ownership DONE, DLU authority still a clinic decision (D06).** Only an owner can invite or disable an owner; nobody can disable themselves; the last active owner is protected. DLU mutation permission is unchanged pending D06.

- **Owner/task:** B/J with C decisions D06/D07, **R01–R02**; J03/J13. Ownership/evidence prerequisite.
- **Confirmed:** invitation validator accepts owner and admin has invitations.create (`app/Http/Requests/Api/V1/Identity/CreateInvitationRequest.php:23`, `app/Policies/InvitationPolicy.php:11`). Disable lacks self/last-owner guards (`app/Domain/Identity/Actions/DisableTenantMembershipAction.php:25`). Web profile deletion hard-deletes User (`app/Http/Controllers/Settings/ProfileController.php:47`). DLU API uses labels.manage, web settings uses evidence_settings.manage (`app/Policies/DluRulePolicy.php:17`, `app/Http/Controllers/Web/Tenancy/PracticeSettingsController.php:41`).
- **Proposed scope:** implement agreed ownership transfer/delegation/disable rules and retained historical identities; document deliberate DLU delegation or enforce the approved change on both surfaces. No unauthorized role policy has been selected in Phase0.
- **Acceptance:** last active owner cannot be accidentally lost under concurrent disable/delete; session/token revocation is verified; users with evidence history can lose access without erasing/breaking records; all six roles have direct API allow/deny cases for DLU, invitations and ownership.

### BD-18 — Invitation acceptance and expiry recovery

> **Status 2026-10-02: DONE.** The e-mail link was a dead path; it now opens a French acceptance page (name + password, existing accounts prove their password), and the e-mail and the confirmation page give the practice identifier the app asks for. Expired/revoked/used links end on a clear page. Live proof: `scripts/verify_invitation_journey.py`.

- **Owner/task:** J, **R05, R02**; J03. Required handoff blocker.
- **Confirmed:** API acceptance exists (`routes/api.php:51`), but emailed `/accept-invitation` target has no matching route in `routes/web.php`; pending-invitation checks and disabled memberships impede reinvitation. See `app/Domain/Identity/Actions/CreateInvitationAction.php` and invitation mail source in the full inventory.
- **Proposed scope:** complete installed/uninstalled-app acceptance handoff; permit deliberate expired-invite replacement/revocation and agreed disabled-member recovery. Do not create a duplicate global identity to work around membership state.
- **Acceptance:** recipient follows actual email on a fresh device; valid acceptance yields the intended tenant/role; expired/reused/revoked token is recoverable and does not alter membership; admin cannot exceed the approved delegation rule.

## Clinical state, idempotency and evidence

### BD-04 — Passive label lookup and explicit use semantics

- **Owner/task:** B/J with C decision D08, **C03, C06–C07**; J15/J16/J18. Read-only authorization and clinical-state blocker.
- **Confirmed:** GET uses labels.view, granted to all six roles, then changes Printed→Used; recalled/voided/expired cases throw before returning metadata (`app/Http/Controllers/Api/V1/Labeling/LabelScanController.php:17`, `app/Domain/Labeling/Actions/ResolveLabelScanAction.php:43`, `:62`). Mobile NC subject lookup uses the same route.
- **Proposed scope:** separate passive metadata lookup from an explicit authorized state-changing command; keep blocked records identifiable for incident reporting; settle duplicate usage and offline rules. Preserve a deliberate migration/compatibility path for the current GET behavior.
- **Acceptance:** viewer/detail/NC lookup produces no label, usage or audit mutation; expired/recalled label remains selectable for an incident; actual use checks permission/state and creates one clinical record with original practitioner/time. Repeated scan and response loss follow the approved semantics.

### BD-05 — Reprint state and reasons

- **Owner/task:** B/J, **C04**; J14. Clinical-state blocker.
- **Confirmed:** reason required only for current Printed status; Used/Expired can print without reason and action sets Printed (`app/Http/Requests/Api/V1/Labeling/PrintLabelRequest.php:28`, `app/Domain/Labeling/Actions/PrintLabelAction.php:31`, `:37`, `:55`). Pre-lock checks can become stale.
- **Proposed scope:** determine reprint from immutable print history/counter, validate current state under lock, preserve used/expired/recalled restrictions and audit reason. Coordinate recorded event with physical printing and cancellation/failure semantics.
- **Acceptance:** first/repeated/used/expired/recalled/voided printing plus concurrent recall are exercised; no reprint returns invalid material to usable stock; additional prints obey the chosen reason rule and physical output/print records remain explainable.

### BD-08 — Durable, scoped, concurrent command deduplication

> **Status 2026-10-02: DONE in `steriqore`.** Tenant-scoped POSTs are recorded durably in `api_operations` (tenant+user+key, 90-day retention, `idempotency:prune`) in the same transaction as the business change, serialized by a Postgres advisory lock held to commit; 5xx/429/408 are never remembered and a 5xx request's writes are rolled back; uploads are covered; public no-tenant endpoints keep a 24 h cache so tokens are never stored. 14 Pest tests; live: 8 concurrent requests created 1 row (8 before), and a key replays after a worker restart and cache clear. PATCH/DELETE need no key: verified none uses increments, so they are idempotent by construction.

- **Owner/task:** B/J, **O01, O04–O06, V03, D04**; all replayable writes. Duplicate-write blocker.
- **Confirmed:** middleware cache TTL86400; raw method/path/body hash; cache key user/key without tenant; get→execute→put is not atomic; multipart bypasses cache; stored result omits response headers and includes errors (`app/Http/Middleware/Api/EnsureIdempotency.php:31`, `:49`, `:54`, `:60`, `:74`, `:85`). Route coverage excludes PATCH/DELETE and prosthetic uploads. Existing stock-ledger uniqueness is useful but does not guarantee all domain commands.
- **Proposed scope:** define a durable command receipt/claim strategy with tenant/actor/operation scoping, exact body identity, atomic business commit/result association, replayable response, explicit retryable-failure treatment, retention and unknown-outcome reconciliation. Define upload dedup separately. Mobile persists immutable command/key/bytes before first send. Do not blindly resend uncertain commands beyond retention.
- **Acceptance:** two simultaneous identical commands, same key/different payload, same key/different tenant, response dropped after commit, crash before/after acknowledgement, auth refresh and storage restart/memory pressure. Assert one actual stock delta/release/usage/receipt, not just equal response text. Expired uncertain command is reconciled or safely reviewed.
- **Related time contract:** `RecordLabelUsageAction.php:47–49` defaults missing used_at to server now and explicit null bypasses the array-union default. Specify missing/null/clock-skew behavior and keep occurrence versus server receipt time distinct.

### BD-09 — Atomic state transitions, program ownership and agreed release prerequisites

- **Owner/task:** B/J with clinic release approver pending, **C05, P06, V03**; J09–J12/J26. State-integrity blocker; clinical prerequisite decision pending.
- **Confirmed:** program validation is tenant-only (`app/Http/Requests/Api/V1/Sterilization/CreateCycleRequest.php:28`). Start/add-item/release and prosthetic transition check potentially stale models (`StartCycleAction.php:21`, `AddCycleItemAction.php:31`, `ReleaseCycleAction.php:32`, `app/Domain/Prosthetic/Actions/ChangeProstheticCaseStatusAction.php:23`). Submit deliberately has no mandatory-test gate (`SubmitCycleForReleaseAction.php:13`).
- **Proposed scope:** lock/reload or use version conditions before state-sensitive writes; require selected program to belong to selected eligible device. Implement the clinic-approved control/evidence/equipment/override rule after decision D03. Review append-only status history enforcement and allowed evidence corrections.
- **Acceptance:** cross-device/inactive program rejection; concurrent item/start/release/status requests leave one valid outcome and matching history. Failed/missing controls, inactive equipment, outstanding maintenance and evidence change cases match the recorded clinic rule. No inferred blanket medical rule is substituted.

### BD-10 — Historical references survive archiving

- **Owner/task:** B/J, **R04, I05, A04, V04**; J05/J06/J08/J17/J32. Evidence-read blocker.
- **Confirmed:** product/supplier/device/patient archiving is allowed; historical relations omit soft-deleted records while DTOs dereference them (`app/Domain/Prosthetic/Models/ProstheticCase.php:107`, `Data/ProstheticCaseData.php:44`; `app/Domain/Purchasing/Models/PurchaseOrder.php:44`, `Data/PurchaseOrderData.php:31`; `app/Domain/Inventory/Models/Batch.php:46`; `app/Domain/Sterilization/Models/Cycle.php:63`).
- **Proposed scope:** retain historical relations/snapshots and distinguish inactive picker entries from evidence references. Choose entity-specific archive guards and stock disposition. Apply the agreed historical-name policy when regenerating documents.
- **Acceptance:** create a complete order/stock/cycle/label/usage/prosthetic chain, archive each reference, then reopen lists/details/scans/PDF/archive. Historical content remains readable; new operations cannot silently assign invalid archived records.

### BD-11 — Complete and truthful export jobs

- **Owner/task:** B/J, **A04, V04, D04**; J32. Evidence-loss blocker.
- **Confirmed:** files use `files/{file_name}` and collide; missing media skipped; storage put result ignored before Completed (`app/Domain/Reporting/Jobs/GenerateDataExportJob.php:96`, `:101`, `:152`, `:155`, `config/filesystems.php:105`). Request dispatch occurs inside transaction while queue after_commit=false; separate job connection can read before commit (`RequestDataExportAction.php:50`, `:73`, `config/queue.php:74`, job`:63`).
- **Proposed scope:** unique archive paths with stable IDs, checked writes and checksums, explicit missing-media result, defined portable scope and consistency, after-commit dispatch plus recoverable worker state/retries. Do not export authentication material to make archives portable.
- **Acceptance:** fresh real worker produces an opened archive containing both different `photo.jpg` files; manifest count/checksums match bytes; failed write/missing media cannot report complete success; fast worker before transaction commit and worker restart do not leave permanently Pending exports.

### BD-12 — Actual PDF follows frozen label format

- **Owner/task:** B/J, **C04, V04, D02**; J13/J14. Physical workflow blocker.
- **Confirmed:** print records a format version, but `app/Domain/Labeling/Actions/RenderLabelPdfAction.php:17`, `:27` ignores format and forces A4. `resources/views/pdf/label.blade.php:37` hardcodes code/fields. Sample CSS targets svg classes applied to wrapper divs (`label-format-sample.blade.php:36`, `:55`).
- **Proposed scope:** render the selected/frozen version, actual dimensions/layout/code types and chosen fields for first and repeat printing; preserve the agreed historical identity/date policy. Align UI print permissions and print-event recording.
- **Acceptance:** saved settings change actual PDF dimensions/fields; old print version remains reproducible; long descriptions fit; real clinic printer output scans through both supported code workflows. Print cancellation/failure does not falsely establish usable material.

### BD-15 — Reachable, authorized attachments and web upload repair

- **Owner/task:** B/J, **C02, P04, D02**; J11/J29. Evidence access blocker.
- **Confirmed:** web cycle attachment controller references a missing extraction method/unimported DTO (`app/Http/Controllers/Web/Sterilization/CycleAttachmentController.php:18`, `:22`, `:27`; action only exposes execute at `app/Domain/Sterilization/Actions/AttachCycleFileAction.php:19`). Source URL/config behavior and mobile viewing need physical-device verification. Multipart and base64 paths have different runtime behavior; comments are not acceptance proof.
- **Proposed scope:** repair web handler, validate native/browser upload contracts against chosen server runtime, publish reachable authorized media URLs, define expiry/retrieval and deletion behavior. Readers need evidence viewing independently from upload permission. Upload dedup depends on BD-08.
- **Acceptance:** authorized releaser/viewer can open full evidence; unauthorized/foreign tenant cannot; native and browser image/PDF upload then view succeeds; URL expiry is recoverable; source/backend addresses do not require emulator-host rewriting on physical devices.

## Inventory, alerts and operations

### BD-16 — Receipt evidence/history and draft order completeness

- **Owner/task:** J, **I02–I04**; J19–J21. Required journey blocker.
- **Confirmed:** API has purchase-order create/show/order/cancel and receipt creation, but no draft order update or receipt list/detail/attachment route (`routes/api.php:97–112`). Receive validator requires purchase_order_line_id/batch_number/qty (`app/Http/Requests/Api/V1/Purchasing/ReceiveGoodsRequest.php:32`, `:38`, `:40`).
- **Proposed scope:** add agreed draft edit and linked receipt read/evidence contracts, validate every line against remaining quantity and tenant-owned location, and define expiry/discrepancy policy. Receipt and later photo upload must remain independently recoverable.
- **Acceptance:** first/partial/final receipt produces correct stock/lot and a reopened readable receipt with photo; malformed line causes explicit validation instead of silent omission; lost upload response/retry does not duplicate delivery; cancellation preserves history. Confirm with clinic which discrepancy/expiry exceptions are allowed.

### BD-13 — Tenant-safe jobs and active digest recipients

- **Owner/task:** B/J, **A02, V04, D04**; J30/J35. Delivery/isolation prerequisite; runtime outcome unverified.
- **Confirmed:** digest sets current tenant but not database tenant GUC (`app/Console/Commands/SendDigests.php:36`, `:39`, `config/multitenancy.php:40`); role-recipient resolver does not require active membership (`app/Domain/Identity/Actions/ResolveTenantUsersWithRoleAction.php:25`, `:31`). Alert settings/subscriptions and role tables force RLS in migrations `2026_08_07_000004...:33,53` and `2026_07_25_112137...:18`.
- **Proposed scope:** set/reset tenant context and database context for every scheduled/queued unit, restore context across serialization, exclude disabled recipients, and implement only the approved core notification channel (decision D04).
- **Acceptance:** real restricted PostgreSQL role processes two tenants sequentially in a long-lived worker; no cross-tenant read/delivery; disabled users receive nothing; failures reset context; agreed channel has actual delivery/retry evidence.

### BD-14 — Effective settings and current alerts

- **Owner/task:** B/J with C settings decisions, **A02**; J30. Misleading alert-state blocker.
- **Confirmed:** detector reads only part of settings and can leave stale alerts when threshold disabled or expiring stock fully consumed (`app/Domain/Inventory/Actions/DetectAlertsAction.php:39`, `:48`, `:62`; `app/Http/Requests/Api/V1/Inventory/UpdateAlertSettingsRequest.php:25`). Missing-control-test alert behavior is deferred in source.
- **Proposed scope:** implement adopted settings or clearly remove/defer inactive controls; reconcile no-longer-applicable alerts; define required missing-test notification after D03/D04. Existing open-only alert uniqueness migration already fixes repeated resolved-history collisions; do not reintroduce that obsolete bug report.
- **Acceptance:** threshold zero/change, full consumption, repeated resolve/reopen and both tenants yield the intended open alerts. UI settings demonstrably change behavior. Down-migration rehearsal handles existing repeated resolved history.

### BD-17 — Complete lists, stable cursors and meaningful totals

- **Owner/task:** J, **R03–R04, P02, A01, A03**; lookup/search/dashboard journeys. Completeness prerequisite; tie-skip reproduction pending.
- **Confirmed:** several cursor queries order only by nonunique name/time/date (`app/Domain/Prosthetic/Actions/ListProstheticCasesAction.php:45`, `:58`, `app/Http/Controllers/Api/V1/Prosthetic/ProstheticWaitingPlacementController.php:26`, `Catalog/ProductController.php:39`, `SitesController.php:29`). Mobile also truncates several paginated lists and computes clinic totals from loaded pages.
- **Proposed scope:** stable unique ordering and preserved filter/cursor contract; provide authoritative aggregate counts where required rather than disguising a loaded-page count as clinic total. Define null/date/timezone ordering.
- **Acceptance:** more than two pages with duplicate sort values yields all expected IDs once; filter snapshots survive each page and refresh; dashboard/waiting totals and drilldowns match fixture truth across tenant-local midnight.

### BD-19 — Reproducible deployment, durable storage and recovery

- **Owner/task:** B/J, **G02–G04, D04–D05, V04–V05**; J35. Release gate, not evidence that current deployment is broken.
- **Confirmed source prerequisites:** Docker copies context while exclusions omit some real environment/capture files (`.dockerignore:10`, `Dockerfile:21`, `:108`); app-role provisioning uses a fixed credential incompatible with configured staging secret (`docker/postgres/init/01-create-app-role.sql:13`, `docker-compose.staging.yml:60`); Redis is configured allkeys-lru while used for queue/session/cache (`docker-compose.yml:92`, `:166`). Backup destination/monitor and queued timing defaults also need alignment (`config/backup.php:220`, `:255`, `:339`, `config/horizon.php:181`, `config/queue.php:71`). Secret contents were not opened.
- **Proposed scope:** exclude real secrets/dumps before build, separate restricted runtime and migration credentials with existing-volume upgrade procedure, use non-evictable durable queue/idempotency storage, make CI prerequisites real, align backup monitoring and verify restoration. Determine prior image exposure before deciding on credential rotation; no publication is claimed by this audit.
- **Acceptance:** clean isolated deployment and upgrade succeed with non-superuser/NOBYPASSRLS runtime; image contains no prohibited paths; queue/replay survives memory pressure/restart; actual scheduler/export/digest run under proper tenant scope; backup restore checks counts, ledgers, usage and media; rollback has a tested procedure.

## Closure requirements and current non-blockers

- Close a BD record only with the owning task's implementation reference, agreed contract change, focused tests and recorded acceptance result. Backend work remains read-only in this Phase0 documentation change.
- **Already present:** release decision GET, member list, filtered evidence export, cancelled prosthetic restart and open-only alert uniqueness. Their mobile wiring/runtime acceptance may remain incomplete; do not request duplicate APIs or fix an obsolete migration defect.
- **Pending decisions:** release prerequisites/approver, notification channel, practitioner eligibility, ownership delegation, DLU authorization, connector, official notes and historical/date policy remain in the matrix decision ledger. They are not fabricated confirmed backend defects.
- **Mobile-owned fixes remain mobile-owned:** scoped encrypted local data, atomic session lifecycle, first-frame launch, UI money parsing, filter retention and false-empty errors do not require redesigning the backend wholesale.
