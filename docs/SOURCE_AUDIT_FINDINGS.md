# SteryMed source audit findings

**Reviewed 1 October 2026.** This is the detailed evidence behind [the clinic release master plan](CLINIC_READY_MASTER_PLAN.md). See [review scope](SOURCE_REVIEW_SCOPE.md) and [per-file fingerprints](SOURCE_REVIEW_INVENTORY.csv).

Findings are from the reviewed working trees, not a live production penetration test or clinical certification. A source defect, a runtime-dependent risk and a clinic policy decision are different evidence types; the backend entries label them explicitly. The master plan assigns delivery priority and acceptance gates across these reports.

Source path convention: mobile paths resolve from `C:/Users/mery/sterymed_mobile`; backend `app/`, `routes/`, `resources/`, `database/`, `config/` and backend tooling paths resolve from `C:/Users/mery/steriqore`. In the web frontend section, `pages/` and `types/` are relative to `resources/js/`. Line references apply to the inventoried snapshot.

## Reading guide

- [Mobile foundations and release configuration](#mobile-foundations-and-release-configuration)
- [Every mobile feature](#every-mobile-feature)
- [Backend domain, API and authorization](#backend-domain-api-and-authorization)
- [Web workflows needed by the clinic](#web-workflows-needed-by-the-clinic)
- [Backend schema, tests and operations](#backend-schema-tests-and-operations)
- [Mobile test evidence and limits](#mobile-test-evidence-and-limits)

## Findings mapped to implementation tasks

Each task ID below is defined in the master plan. These mappings are additional detail to its F01–F18 release-blocker table; they do not create a second competing backlog.

| Source findings | Owning tasks |
|---|---|
| Mobile session/identity/storage/privacy | S01–S06 |
| Mobile unknown-outcome writes, replay, status and drafts | O01–O06, S03, P05 |
| Mobile route/action/lookup/catalog/device/supplier issues | R01–R05, S04, A05 |
| Mobile cycles, labels, patients, compliance and scanner | C01–C07 |
| Mobile inventory/purchases | I01–I05 |
| Mobile prosthetic workflows | P01–P06 |
| Mobile dashboard/alerts/audit/reporting/shared UX | A01–A06 |
| Backend B01 foreign practitioner | R02, P01, V01 |
| Backend B02 idempotency | O01–O04, V03, D04 |
| Backend B03/B04 lookup and reprint | C03–C04, V01–V04 |
| Backend B05 archived historical relations | R04, I05, A04, V04 |
| Backend B06 program/device mismatch | C05, V04 |
| Backend B07 transition concurrency | O04, C05, P06, V03–V04 |
| Backend B08/B09 identity/delegation/settings policy | G01, R01–R02, V01 |
| Backend B10 cursor ordering risk | P02, A05, V04–V05 |
| Backend B11/B12 export completeness and dispatch | A04, V04, D04 |
| Backend B13/B14 digests and alerts | A02, V04, D04 |
| Backend B15/B16 print format and web upload | C02, C04, V04, D02 |
| Backend B17 clinical prerequisites | G01, C05, H01 |
| Backend B18 occurrence time/date semantics | O05, C06, P06, V03 |
| Backend B19 missing API/handoff surface | G01, R03, R05, I03–I04 |
| Backend B20 deployed configuration | G02, D01–D05 |
| Web findings 1–3 printing | C04, D02 |
| Web finding 4 audit null display | A03 |
| Web finding 5 hidden form errors | R04, I02, A05 |
| Web finding 6 export recovery/paging | A04 |
| Web finding 7 expiry window mismatch | A02, I05 |
| Web finding 8 invisible roomless locations | R03–R04, I05 |
| Supporting-source CI, fixtures and false-positive tests | G03–G04, V04–V05 |
| Supporting-source schema/history/identity | R02, C04, P06, A04 |
| Supporting-source provisioning/secrets/Redis/rollback | G02, O04, D04–D05 |
| Mobile T01–T02 journey/contract coverage | G01, G03–G04, V01–V02, V05 |
| Mobile T03/T07 replay/session/privacy coverage | S01–S05, O01–O06, V03 |
| Mobile T04 false-empty history | C02, C06 |
| Mobile T05 authorization coverage | R01–R02, V01 |
| Mobile T06 incorrect mocked wire fixtures | G04, I02, V02, V05 |
| Mobile T08 pagination coverage | P02, A05, V04 |
| Mobile T09/T10 output/device coverage | C04, P04, A04–A05, D02–D03 |

## Additional primary-review notes

- `lib/shared/widgets/inputs/app_date_picker.dart:27` uses today as the initial date even when a caller supplies a past upper bound. Clamp the initial value into valid bounds; test the audit filter's To-before-today/From-empty case under A05.
- `scripts/run_tests_win.sh` is a pre-existing user file. Its grouped test results are not aggregated into a final failing exit status; preserve its intent but make it reliably fail CI/automation under G04. It was read, not run or changed.
- Historical `scripts/phase1*.sh` perform broad source replacements and commits. They are not the execution mechanism for this new plan. `verify_idempotency.py` mutates a live cycle and proves only sequential replay; use isolated fixtures and stronger assertions for O04/V03.
- Mobile `pubspec.lock` resolves 168 packages and declares Dart >=3.12 / Flutter >=3.44, while the app manifest advertises lower minimums. Pin and document the actually supported build toolchain in G02; package versions were inventoried, not assessed for current advisories in this static review.
- Asset/font files were inventoried rather than visually inspected. New visual acceptance is part of D03. The existing `Inter` theme family is not registered as an app font family in pubspec; address that before comparing new typography goldens.



## Mobile foundations and release configuration

Source read directly; existing PRODUCT_COMPLETION_PLAN.md not read. No app/backend implementation changed.

### Confirmed foundation findings

- Session and queue ownership: OutboxItem has no environment, tenant, actor, schema or session generation; OutboxStore/KeyValueStore each open a global Hive box without cipher. AppCache is globally keyed. AuthRepository only clears token and SessionStore. New user can see previous cached/draft data; queue uses current AuthInterceptor token. Preserve/quarantine unsent work under original owner; do not blindly delete/reassign legacy items.
- Durable write correctness: SyncEngine stores syncing before HTTP then pending only is selected; crash leaves syncing indefinitely and counts exclude it. No single-flight guard despite _isFlushing; retryOne and flush race. No due time, per-resource ordering, auth pause, cancellation, startup recovery, reconciliation or cache invalidation after replay. 409 comment incorrectly assumes every conflict is idempotency mismatch. Queue UI retries immutable invalid data; no inspect/correct/resolve flow. Retry all actually selects pending only. Counts/pill may show synchronized while syncing.
- Boot: bootstrap awaits SyncStatusCubit.start before runApp; start awaits full pending queue replay before subscribing connectivity. Auth validation happens later from SplashScreen. Corrupt Hive row/session JSON can throw before first frame. Need fast recoverable startup and deferred auth-gated worker.
- AuthRepository.restoreSession clears token+session on ANY error; offline/500 cannot restore known identity. Distinguish invalid auth from service unavailable and malformed response; define permitted offline reads/drafts.
- AuthBloc logout uses timeout5s but underlying repository remote call finally clears storage later; Settings navigates login immediately. New login can be cleared by late logout. Stale401 also expires whichever current session exists. Auth events run concurrently; build session generation/fence and capture old token for revoke.
- LogoutEverywhere swallows revoke failures but UI promises all sessions revoked; report local logout separately from confirmed server-wide revocation.
- ErrorMapper assumes details Map; error normalization discards cancellation/TLS distinction, ErrorMessage returns generic network for wrapped ApiException, raw unknown errors returned to users. Auth login/register do not convert Dio errors consistently. Preserve safe message/field errors/request id/code.
- LoggingInterceptor sends response.data.toString (Dart map syntax), while PiiScrubber expects JSON quoted keys. Debug login token/PII redaction fails; request URI includes search text. Sentry scrub only message/exception and shallow string breadcrumb values. Structured allowlisted diagnostics needed; do not claim measured production leak.
- ConnectivityService loses upstream subscription and closes downstream only; lifetime cleanup can add to closed controller. AppLifecycleObserver is defined but unused. Wire resume trigger and own/cancel subscriptions during foundation work.
- SessionStore.set only changes fallback role when non-null; legacy stale fallback role can survive replacement. Validate required token/user/tenant fields, persist atomic/versioned session envelope, handle corrupt storage.
- API defaults HTTP emulator in Env; exact ENV=production only triggers HTTPS check. Enforce explicit environment/baseURI on release; Android default cleartext restrictions can make misbuilt release offline rather than safe production.
- MediaUrl hardcodes native emulator address; never derives LAN/staging host and rewrites signed object URLs. Require reachable presigned server URLs; test physical devices and expired URL refresh.
- BuildInfo.initialize has no call site anywhere lib; app always fallback version0.2.0+1. Initialize before displayed metadata and test actual artifact.
- AppLocalizations delegate omitted and generated strings unused; French UI hardcoded. Keep French release, consolidate user-facing/validation messages as touched; avoid arbitrary translation expansion.
- Theme fontFamily Inter but pubspec only lists .ttf as assets, no fonts declaration. PDF asset loading separate. Current app renders fallback; declare actual weights and update reviewed goldens after decision.
- Fixed-height primary/secondary buttons with nonflex Text, fixed40px filter chips, six bottomnav labels, nonflex MetadataRow/CopyableText values need narrow/large-font coverage. Existing design system is reusable; no redesign required.
- CursorPaginatedList shows spinner when hasMore even if not loading; no bottom error/retry, no refresh for empty list, no fetch when first page shorter than viewport. Shared repair plus feature list race/refresh policies.
- TeamRepository.practitioners filters role but not active status. Backend lookup permission needs confirmation for practitioners. List datasource returns [] for404 or malformed non-list, misreports contract failure as empty team. Team refresh uses cached list. Empty name initials substring can throw in TeamMemberData, ProfileMenu, StringX.
- Exact six mobile role names are owner,admin,stock_manager,releaser,practitioner,viewer; no reception/staff role. SessionStore.isOwner combines admin+owner; route/actions mostly permission based. Use canonical server grants/policy exceptions rather than new roles.
- All sync routes accessible to any authenticated session; scope queue display and replay ownership even for viewers.
- Notification switch only OS permission checks/requests; no push delivery/client registration in pubspec or lib. Core brief includes notifications; prosthetic notifications later. Decide explicit pilot delivery scope; permission alone is not delivery.
- About claims encrypted data but Hive payloads unencrypted. Product copy must match verified implementation.

### Release source findings

- Android applicationId/namespace com.example.sterymed_mobile, debug signing in release. Gradle/Flutter version pins present. Production signing/owned identifiers needed; keystore migration/install upgrade acceptance mandatory.
- Android debug cleartext allowlist exists; release manifest lacks debug config. Check actual merged artifact before release; do not describe unrestricted release cleartext as confirmed.
- iOS bundle com.example.sterymedMobile; Info.plist duplicates camera/photo keys, displayName has trailing space/case typo. iOS15 deployment. Xcode project SPM local reference; no Podfile/CocoaPods includes in xcconfig, CI comments historical linker failure. Actual build must be re-established on Mac; don't assume single-file fix.
- CI analyze/test/debug APK/iOS simulator source exists; release ymls and all Fastlane/config/store metadata are empty. Tests workflow emits coverage artifact without threshold, no live integration or physical acceptance.
- Local previous460-pass baseline belongs previous run, not fresh runtime proof. This turn is source review and documentation only.

### Product docs read

Read entire DOCX document/header/footer XML and all16 PDF pages as extracted text. Two files currently exist in pjdocs. Deleted New Text Document(2).txt not restored/read. PDFs scope ambiguous attachments postMVP page11 versus explicit mobile deliverable/acceptance pages7/14/16: keep already-implemented uploads and complete usability, automation later. Original MVP stock entry/exit by scan and receipt photo are required; web printing boundary explicit. Preserve pseudonymous existing ADR decision pending owner clarification instead of adding real patient names. No deadline estimate inferred from original10week indicative plan.


## Every mobile feature

Scope: every Dart file in 17 feature modules; auth, identity, shell, settings and sync excluded by root assignment. Exact denominator is 255 files (initial message said 275 by arithmetic mistake). No PRODUCT_COMPLETION_PLAN.md, project_dump or old master plan read during this review. Manifest records SHA256/lines for emitted complete files. Source was emitted without blank lines/indentation only. Truncated batches are reread completely before counting completion.

### Findings and investigation notes

#### Alerts (7 files complete)
- alert_list_bloc.dart:86 treats **every HTTP 409** as already resolved. Server idempotency-key conflict or other business conflict is therefore silently hidden; use verified error code/reload instead. Resolve is optimistic without per-ID tracking; overlapping resolution rollback can resurrect a successfully resolved alert (:78-88). alert_list_screen.dart:65 uses BlocBuilder only and renders errors only when no alerts (:71), so resolve/load-more failures with remaining rows are invisible. Unknown severity maps to enum unknown but all three rendered groups omit unknown entries (state :23-30; screen :94-126), so server schema drift can hide alerts entirely.
- Pagination exists, action gated alerts.manage. Empty list has no refresh action. No subject deep link from alert row.

#### Catalog (11 files complete)
- Product edit loads _categoryId/_locationId from existing record (product_form_sheet.dart:70-71), initially renders dropdowns whose only item is null while async options load (:187-206). Non-null initial selections have no matching DropdownMenuItem, including when lookup fails/archived option absent; potential DropdownButtonFormField assertion. Fix retain selected option and defer selection-bearing widget until options ready, handle unavailable choices explicitly; regression categorized/located product edit.
- product_data.dart:69-71 omits null barcode/category/location on PATCH. UI permits selecting None/clearing barcode but update cannot send explicit null to clear stored values; separate create/update payload semantics.
- Product threshold invalid input silently becomes zero (form:116; threshold input:179-183 lacks validator).
- Product list datasource requests limit100 and discards cursor (product_remote_datasource.dart:19-27); list/search race has no stale request suppression. Product load/refresh uses cached unfiltered list (bloc:36), so refresh/search/edit can show data inconsistent with query. Delete errors only state.error (:62), screen shows them only status=failure (:69), so failed delete can be invisible.
- CRUD and product category lookup exist; category creation and product media UI absent (verify agreed web/mobile scope).

#### Sites (7 files complete)
- Read-only list deliberately directs provisioning to web. Datasource accepts multiple envelopes and silently returns empty on unrecognized shape (:23-47), limit100 without pagination. No site/space selection or creation flow here; preserve intended web ownership.

#### Compliance (9 files complete)
- nc_create_sheet.dart:61-64 takes only the first 20-cycle page for subject picker; no search/pagination, so older cycles cannot be selected. :67 hides loading errors as no cycles. :95 resolves a label via the **scan** repository. Backend verified: ResolveLabelScanAction changes Printed to Used and rejects expired/recalled/voided labels. Incident creation therefore has an unintended write and excludes important blocked subjects. All lookup errors become 'introuvable' (:97-104). Use a passive lookup endpoint/ID resolution with subject authorization.
- non_conformity_remote_datasource.dart:18-26 requests first50 only; no cursor. Filter uses status, verify exact server query. List/create/resolve with required resolution exist; label/cycle only subject UI, no recall initiation action present.

#### Dashboard (7 files complete)
- dashboard_remote_datasource.dart:102-107 swallows ALL Dio failures, then :111-124 returns empty. Full outage/403 becomes apparently healthy zero alerts/cycles, cached as success. Use typed partial availability/error rather than invented zero. Counts derived from first50 cycles/alerts (:12-18,31-65), no total/cursor; actual active count can be underreported.
- Raw backend cycle status forwarded :88 while dashboard_screen.dart:513 accepts only in_progress; running renders Created (:522-523). Normalize through same CycleData mapper as cycle screens.
- DashboardCubit:17 refresh uses cache (no forceRefresh); audit request/card not permission gated although quick-access menu is. RecentProceduresCard has no call site; its datasource maps arbitrary audit subject_id as patient reference (:91-97), so do not wire without correcting meaning.

#### DLU (5 files complete)
- CRUD, reason, historical impact warning, labels.manage gates implemented. Generic exceptions rendered via e.toString in form:89. Async sheet returns call setState _refresh without mounted check (:80,:146).

#### History (8 files complete)
- Cursor pagination and action/actor/subject/date filters exist. Actor picker limited to actors ever seen in loaded pages (audit_list_state.dart:42-47), obsolete comment says members endpoint missing. Audit tile omits event.reason and subjectId although model has them; no detail/open path.
- audit_list_bloc.dart:100-116 can append old filtered page into newly filtered state; load/refresh/filter lack request generation/cancellation. Load-more errors stored but screen supplies error only on failure status (:157), hiding failed pagination.
- audit_filter_sheet.dart:134-147 passes selected date bounds to AppDatePicker. Shared default initialDate=now can lie outside upper bound when To=past and From=null; ask root shared-widget audit to validate.

#### Labels (13 files complete), scanner (4), patients (12)
- label_usage_repository.dart:53 remote generates key while fallback :69 generates a new one; source-confirmed response-loss duplication risk. used_at omitted unless caller explicitly passes (:47); actual form never does. Queue has no local duplicate usage guard.
- label_detail_screen.dart:130-134 marks **used** as green 'Etiquette valide'; :90 only status checks enabling record, does not disable for existing usage/historyLoading. label_detail_bloc.dart:36-39 swallows history error -> display 'Aucune utilisation' (:287). Distinguish scanned-awaiting-record vs already recorded/pending; unknown history must not imply absent history.
- scanner routes to detail by code (:107), which repeats GET (:label_detail_bloc25), and blocked screen also repeats GET. LabelBlockedScreen:65 spins forever on successful lookup/deep link; re-fetch transient failures shown as clinically blocked. Preserve original classified result and provide explicit recovery.
- Label repository never caches; patient search always remote. Only already open form/draft can queue offline; no offline start-to-finish scanner/patient workflow is implemented.
- label_usage_form_screen.dart:55-65 debounce writes are fire-and-forget, :70 cancels latest unsaved edits; clear-after-submit races pending write. Draft load cast outside try (store:56) crashes on non-string storage corruption.
- patient_search_bloc.dart:38-42 and patient_list_bloc:34-35 lack latest-query checks. Picker keeps previous results selectable while new query loading (:98-123), blank initially until typing; no initial query/retry/create option. Patient list supports anonymous create/delete but no patient dossier/history route, despite dashboard description 'Fiches patients et historiques'. Created record ignored, so staff must infer new reference from refreshed list.
- Scanner is camera-only label resolution; no manual fallback, stock scan mode, on-device lifecycle/permission recovery handler. Need actual permission/device acceptance, not assuming default plugin behavior broken.

#### Devices (16 files complete)
- Device CRUD, program CRUD and append-only maintenance exist with devices.manage gates. Device edit loads sites BEFORE show (:device_form_sheet72-81); failed optional sites read suppresses detail read and renders blank editable fields without error (:95-98), risking overwrite.
- Empty model/manufacturer/notes become null in form:112-117 but datasource only includes nonnull (:57-61), so cannot clear existing values.
- Device detail/list separate model from cycle picker. Investigate both caching 'devices' under different List types (device_detail_repository:13-17).
- Device list only refreshes on detail pop(true) (:110); editing refreshes detail but normal Back returns null, leaving stale list. Program/maintenance sections have error text but no retry and no didUpdateWidget refresh when data changes.
- Some date/status strings are raw, long DeviceField values unbounded; require narrow-screen/large-text acceptance. No claim append-only maintenance edit/delete is missing.

#### Suppliers (10 files complete)
- Create/edit/delete and attach product exist. Supplier detail locates supplier in first100 list rather than GET id (supplier_detail_screen:44-58), so deep links outside page or stale cached list show not found. Product join also first100 -> 'Produit inconnu'; attach picker incomplete.
- Supplier price input already replaces comma (:287) unlike purchase/prosthetic; malformed price/pack size still silently omitted. No field errors except product choice. Supplier list pull refresh is cached (_onLoad list without forceRefresh). No supplier search/pagination UI.

#### Reporting (12 files complete)
- Evidence first search errors/loading hidden: screen:162 returns introduction while hasSearched false; bloc:51 only sets true on success. Invalid cycle number silently becomes no filter (:61). Reset clears UI only (:69-76), leaving old result/filter state.
- Evidence load-more appends current results after await without filter generation check (bloc:75); load-more failures invisible (screen:176). Evidence rows not navigable and omit label status/ID details. Export request/download/open implemented; first50 export list only, no background poll. OpenFilex result ignored (data_export_screen:77); only same-row download disabled, concurrent download state overwritten. No claim exports missing.

#### Purchases (14 files complete)
- Create/list/detail/order/partial receipts implemented, canReceive correctly handles partially_received. Cancel repository/model exist but no cancel UI; no edit order/receipt history action. Verify required scope.
- First-stock receipt dead end: goods_receipt_screen:65 uses StockRepository.listOptions; stock_remote_datasource:43 derives location options solely from first100 stock rows (:25). Empty stock -> no location -> submit rejected (:94), warning advises receiving stock to create a location (:180-183), a circular instruction. Backend source should identify existing location endpoint; fix client to use it, do not assert backend missing from stale comment.
- Receipt does not validate per-line inputs: invalid/negative qty silently dropped (:103,123); blank physical lot silently invented using timestamp (:109-111); expiry optional and discrepancy unchecked (:113-120). Need explicit physical lot policy, positive/remaining qty validation and discrepancy rules matching contract. Errors loading order/options are collapsed into 'Commande introuvable' with no retry (:86,166).
- PO qty invalid defaults1 (:268), invalid lines dropped rather than flagged (:105-106). French 12,50 silently omits unit_price (:118,122). Validate every line, locale decimals, nonnegative prices and bounded quantities before submit.
- Pull refresh sends LoadPurchaseOrders (:101-103), so cache served despite RefreshPurchaseOrders existing. Load-more errors hidden (:92), request races same as other paginated lists. Mark ordered confirmation claims actual supplier delivery (:52) though endpoint merely status; verify backend side effects.
- All receipt/movement/usage online-fallback repositories generate NEW offline idempotency keys after network uncertainty; coordinate root outbox fixes.

#### Stock (26 files complete)
- Levels, batches, issue/adjust/transfer implemented. Batch/location metadata is truncated and derived from first100 levels; cannot select unused empty destination location or first receipt location; each movement's independent batch/location dropdowns permit unrelated pairs. Must consume real complete catalogs and constrain source pair/available quantity.
- Stock counts and batch view over first100 rows only (remote:25), paging ignored. Stock expiry should receive date-only/timezone acceptance coverage; no confirmed date-only expiry defect asserted.
- RefreshStockLevels (:58) never sets forceRefresh true; blank query returns cached levels. Search race can overwrite newer query; failure hidden if existing levels screen:64-65. Queued stock operations return explicit queued notice but stock display has no pending reservation/status.
- StockOptionsLoader forces network even though cache available (:44), so a fresh offline movement form cannot open cached options. Existing outbox support must have clear offline scope.
- Standalone issue/adjust/transfer blocs and StockActionCubit are candidates for dead code: screens call repository directly; confirm callsites before cleanup.

#### Prosthetic (25 files complete)
- Dashboard, six filter dimensions, cursor lists, waiting list with aging buckets, create/edit/status/history, cancelled restart, laboratories create/edit/archive, camera attachment upload/delete, PDF summary and independent payment permissions all implemented.
- Filtered list pagination loses filters: repository:47-48 forwards cursor only, bloc:72 does not supply filters. Search has no stale request suppression; load-more appends after filter change and errors hidden. Need same filter snapshot across pages and generation/cancel guard.
- KPI navigation misleading: active opens all statuses (home:103), today opens all scheduled dates (:132), due payments opens all cases (:139). Correct query dimensions before wiring exact count drilldowns. Waiting aging buckets are loaded-page counts (:44-61), and empty local filter may block loading subsequent matching pages (root shared CursorPaginatedList audit to verify).
- Detail chips never open URL (prosthetic_attachment_chip:16-25); camera-only selection (:147) cannot attach existing PDF/gallery files. Upload exists but view/download is missing. ImagePicker call outside try: permission/platform failures escape (:147 vs151). PDF uses single pw.Page+Column (:31,35), long notes may overflow; require multipage output + print-error handling.
- French comma or malformed monetary input sends explicit null to PATCH with no form validator (payment_section:76,80). Can erase amount and display 'Paiement à jour' if balance unknown (model:187-189; payment:190). Locale-safe decimal validation and unknown vs paid semantics needed.
- Restore archived lab to create dropdown causes absent-selected-option assertion (create:73,106,265); edit existing archived lab likewise (edit:81,104,201). Failed lab load edit masks error yet retains selected ID; preserve old choice with archived label or provide clear recovery.
- Create assigns practitioner_id=session.userId unconditionally (:143,154), no practitioner selection; role-sensitive clinic workflow acceptance must confirm users who can create should self-assign. Free-text practitioner filter advertises name but sends practitioner_id (list:296-300,363). Existing membership endpoint permission restriction is documented in edit sheet, don't assume backend absent.
- Create draft saves Form.onChanged, but date picker change only setState (:255), not explicit save; isEmpty ignores workType/impression/date, so those-only changes discarded. Draft writes fire-and-forget; restored IDs not revalidated; no discard affordance. Stock/purchase forms lack durable drafts. Parent covers global account isolation.
- Full detail Future.wait means history/attachment failure prevents clinical/payment view; list/home not refreshed on return after create/edit/status. Unbounded info card values risk small-screen overflow (:28). Laboratory screen lacks its own permission gate, parent should verify route guard.

#### Cycles (69 files complete)
- Create/list/detail/start/complete/submit/release-reject, controls, instruments, camera upload/delete, label generation/count, timeline and visibly local-only notes implemented. Backend draft/running status normalization already correct.
- Item edit deletes original before adding replacement (cycle_detail_screen:522-525), so any network/server add failure permanently loses it. Replacement omits existing batch_id, severing batch traceability even on success. ItemEditorDialog:96-97 claims batch can be linked later via Stock/scan, but neither module offers that action. Only unused CycleItemsScreen or unused bloc accepts batch_id. Resolve edit semantics with backend; provide real batch picker/link at supported lifecycle stage without destructive simulation.
- Release decision can be made before evidence load finishes, and after evidence load fails: detail bloc:49 emits success immediately; auxiliary errors recorded at63/69/75 but screen only reads error when entire status failure:130. This falsely presents 'Aucun instrument/contrôle/pièce' and retains stale evidence. Maintain per-section loading/error and refresh assurance before release workflow; server remains authoritative.
- Attachment access: CycleDetailAttachmentTile:18-50 is placeholder+delete only, no filename/open; dedicated CycleAttachmentGrid:125 gives100px cropped image and :148 PDF icon without full viewer/open. Detail navigates to attachments only through add action gated cycles.manage (:300-303), so a release-only reader cannot reach even thumbnails. Add role-correct read action, zoom/PDF open and expired presigned URL refresh.
- Release card unreachable: CycleDetailState.release never assigned anywhere; bloc only loads cycle/items/controlTests/attachments. Screen:327 tests always-null release, losing decision reason/actor in ordinary reopened detail. Use backend response fields or existing read endpoint after contract verification.
- Cycle search/status filtering only loaded20-page data (cycle_list_state:26-37), hint misleadingly promises lot while code excludes lots/ID. Shared CursorPaginatedList:items.isEmpty returns EmptyView ignoring hasMore, so zero matches on first page cannot page to older matching cycles; prosthetic waiting aging filter has same failure. Use server filtering or drain filtered-empty pages with deliberate load-more/retry.
- Device cache collision CONFIRMED across full source: cycle DeviceRepository caches List<DeviceData> under devices (:12,26,31); DeviceDetailRepository caches List<DeviceDetail> under same key (:13-17); AppCache.get unchecked as T. Opening either feature after the other within TTL can TypeError. CycleCreate forces refresh, but detail/name enrichment and device list hit shared slot. Split typed cache keys/unify model and invalidation.
- Cycle create offers all devices/programs without filtering inactive (create:82,111), retains deleted selected device across reload (:79), auto-selects first. Match active eligibility with server contract and explicit selection. Button says 'Initialiser & Charger les Sachets' but discards created ID and pops list (:148-159); navigate created record/items for seamless loading.
- Label generation DLU read happens before try and busy flag (cycle_labels_section:40 vs100-101), so error escapes and repeated taps open concurrent dialogs; initial count error has no retry (:155-156). Show validated DLU/load state and recovery. Printing remains web/admin scope; web-print -> mobile-scan acceptance required.
- Cycle notes warning clearly says device-only (:161-163); not a hidden claim of sync. However local notes have no actor/time, lifecycle or permission gate, no storage-error catch, and only cache-key cycleId; parent handles account isolation. Decide clinical official notes vs explicitly personal local draft per original scope.
- Transition/release fallback uses new idempotency key; queued transition immediately refetches remote-only detail (screen:89,repository.show:68), producing offline error and allowing repeat after retry. Preserve last confirmed view + visible pending transition, dedupe and ordered replay.

#### Reachability / unused code verification
- rg across lib confirms CycleItemsScreen, CycleControlTestsScreen, CycleReleaseScreen have no router/caller. Dedicated attachments IS routed (app_router:214). Their alternative state/status handling must not be cited as current routed behavior; either consolidate/remove or intentionally integrate after workflow decisions.
- CycleCreateBloc/CycleReleaseBloc/CycleItemsBloc/CycleControlTestsBloc/CycleAttachmentsBloc and StockIssueBloc/StockAdjustBloc/StockTransferBloc/StockActionCubit are only constructed in DI registrations, with no getIt/read usage found. CycleTile, RecentProceduresCard, TransitionConfirmDialog similarly have no runtime caller. Tests of unused paths do not prove current screens.
- evidenceExport constant exists (api_endpoints:89) with no caller. Search and full archive export exist; filtered evidence export action absent.

#### Full-source coverage
- 255/255 Dart files in lib/features excluding auth/identity/shell/settings/sync fully emitted and read. Manifest records exact SHA256/line/byte counts at build/readiness-review/clinical_features_manifest.json. Comments retained; whitespace-only lines omitted. Truncated batches were reread in narrower batches. No unread scoped files; no production edits; no live mutation/test execution by this reviewer. Existing plans/project_dump were not used in this fresh pass.
- Final manifest integrity check: 255 files, 879,483 bytes, 26,459 lines; no unread files, no hash mismatches, no extra paths. Stored in clinical_manifest_verification.json.


## Backend domain, API and authorization

All first-party app/routes/config/bootstrap files excluding bootstrap/cache; read-only static review, no backend tests/services/mutations/secrets.

### Coverage

444 files / 24,648 lines read completely in 33 batches. Manifest records each path, size, SHA256 and read completion. No old completion plan or dump was used.

### Findings

#### B01 — P1 — Prosthetic practitioner can belong to another practice

**Classification:** confirmed_source. Not executed against a running backend.

Only global users existence is validated. A supplied foreign user UUID can be saved as practitioner and the response reads their name. Patient/laboratory tenant validation does not cover this global identity relation.

**Fix:** Validate tenant membership explicitly; agree eligibility for active membership, globally disabled identity and practitioner role. Preserve historic identities independently of new assignment eligibility.

**Verify:** Two-practice API test: foreign user rejected for create/update; valid current practitioner accepted; disabled/invited identities follow the agreed policy. Assert response contains no foreign name.

Evidence: `app/Http/Requests/Api/V1/Prosthetic/CreateProstheticCaseRequest.php:31`, `app/Http/Requests/Api/V1/Prosthetic/UpdateProstheticCaseRequest.php:35`, `app/Domain/Prosthetic/Actions/CreateProstheticCaseAction.php:25`, `app/Domain/Prosthetic/Actions/UpdateProstheticCaseAction.php:34`, `app/Domain/Prosthetic/Data/ProstheticCaseData.php:46`

#### B02 — P1 — Idempotency middleware cannot guarantee one committed command

**Classification:** confirmed_source. Not executed against a running backend.

Cache get/execute/put is not atomic, so simultaneous identical commands can both execute. Cache key is user-or-guest plus key, without tenant. Raw method/path/body bytes are hashed. TTL is24hours. Multipart bypasses lookup/storage entirely; prosthetic attachments have no middleware. PATCH/DELETE generally have no replay middleware. Cached response records status/body but not headers and has no success-status filter.

**Fix:** Agree durable backend command receipt scoped to tenant/actor/operation, atomically coupled to domain commit. Define retention and expired/unknown-outcome reconciliation. Add upload content identity and duplicate protection. Mobile must persist stable key, exact payload/event time and principal before sending; never auto-replay indefinitely past server dedup retention.

**Verify:** Concurrent duplicate POST, lost response after commit, crash between commit and receipt, same key different body/tenant, multipart retry, cache outage,24hour expiry and session change tests. Compare resulting domain rows and audit events, not only status.

Evidence: `app/Http/Middleware/Api/EnsureIdempotency.php:31`, `app/Http/Middleware/Api/EnsureIdempotency.php:49`, `app/Http/Middleware/Api/EnsureIdempotency.php:54`, `app/Http/Middleware/Api/EnsureIdempotency.php:60`, `app/Http/Middleware/Api/EnsureIdempotency.php:74`, `app/Http/Middleware/Api/EnsureIdempotency.php:85`, `routes/api.php:298`

#### B03 — P1 — Label lookup GET changes clinical status and blocks NC lookup

**Classification:** confirmed_source. Not executed against a running backend.

All six roles including viewer have labels.view. The GET used for lookup changes Printed to Used and audits label.used. Recalled/voided/expired results are410 with no normal label DTO. Mobile clinical reviewer confirms NC creation resolves code through this endpoint, consuming valid labels and obstructing reporting blocked labels.

**Fix:** Separate side-effect-free identity/evidence lookup from authorized explicit usage recording. Make usage state/audit and patient/procedure link one intentional command. Preserve readable recall/expiry metadata for reporting and reconciliation.

**Verify:** Viewer lookup and NC subject selection leave status unchanged. Expired/recalled labels remain reportable and blocked for usage. Explicit authorized usage records exactly one event and linkage.

Evidence: `routes/api.php:224`, `app/Http/Controllers/Api/V1/Labeling/LabelScanController.php:17`, `app/Policies/LabelPolicy.php:12`, `app/Domain/Identity/Actions/SeedTenantRolesAction.php:96`, `app/Domain/Labeling/Actions/ResolveLabelScanAction.php:43`, `app/Domain/Labeling/Actions/ResolveLabelScanAction.php:62`

#### B04 — P1 — Reprint reason and status depend on current status instead of print history

**Classification:** confirmed_source. Not executed against a running backend.

After Printed becomes Used or Expired, printing is permitted without a reason; it increments print_counter but records label.printed and resets status to Printed. Checks before locking also permit a stale request to race a recall.

**Fix:** Define printable states and preserve usage/expiry/recall state. Determine first print from counter/history and validate under the row lock. Coordinate print record with actual physical print failure handling.

**Verify:** First print; repeated print; print after used/expired/recall; concurrent recall/print; reason required on every additional print; print failure/retry does not manufacture duplicate trusted labels.

Evidence: `app/Http/Requests/Api/V1/Labeling/PrintLabelRequest.php:28`, `app/Domain/Labeling/Actions/PrintLabelAction.php:31`, `app/Domain/Labeling/Actions/PrintLabelAction.php:37`, `app/Domain/Labeling/Actions/PrintLabelAction.php:55`

#### B05 — P1 — Archiving master data breaks historical DTOs and evidence

**Classification:** confirmed_source. Not executed against a running backend.

Allowed soft deletes have no dependency guard. Historical relations lack withTrashed while DTOs dereference them: archived patient breaks prosthetic list/detail; deleted supplier/product breaks order or stock DTO; deleted device breaks label/PDF evidence. LabelUsage.patient already uses withTrashed, demonstrating intended preservation elsewhere.

**Fix:** Preserve historical relations/snapshots and disallow invalid new references to archived data. Choose archive semantics per entity and return structured conflicts if archive must be blocked.

**Verify:** Create full order/stock/cycle/label/usage/prosthetic histories, archive each referenced entity, then reopen lists/details/scans/PDFs. Historical identities remain and active pickers omit archived records.

Evidence: `app/Domain/Catalog/Actions/DeleteProductAction.php:24`, `app/Domain/Purchasing/Actions/DeleteSupplierAction.php:22`, `app/Domain/Equipment/Actions/DeleteDeviceAction.php:23`, `app/Domain/Traceability/Actions/ArchivePatientAction.php:23`, `app/Domain/Prosthetic/Models/ProstheticCase.php:107`, `app/Domain/Prosthetic/Data/ProstheticCaseData.php:44`, `app/Domain/Purchasing/Models/PurchaseOrder.php:44`, `app/Domain/Purchasing/Data/PurchaseOrderData.php:31`, `app/Domain/Inventory/Models/Batch.php:46`, `app/Domain/Inventory/Data/StockLevelData.php:39`, `app/Domain/Sterilization/Models/Cycle.php:63`, `app/Domain/Labeling/Actions/RenderLabelPdfAction.php:22`

#### B06 — P1 — Cycle can use a program from another device in the same tenant

**Classification:** confirmed_source. Not executed against a running backend.

device_program_id is validated only by tenant; action does not check program.device_id or is_active. The selected device and program can disagree in traceability.

**Fix:** Validate active program ownership by the selected device in the command transaction; decide whether null program is permitted for the clinic workflow.

**Verify:** Create cycle for deviceA with deviceB program and inactive/archived program; reject each with documented error; correct active program succeeds.

Evidence: `app/Http/Requests/Api/V1/Sterilization/CreateCycleRequest.php:28`, `app/Domain/Sterilization/Actions/CreateCycleAction.php:38`

#### B07 — P1 — Critical state transitions use stale objects without concurrency checks

**Classification:** confirmed_source. Not executed against a running backend.

State is checked before acquiring a useful lock or never locked; AddCycleItem ignores the refreshed locked model. Two clients may append a load item after start, overwrite prosthetic status and produce inconsistent from_status history, or receive an SQL error on concurrent release.

**Fix:** Lock and reload aggregate state before checking transitions, or enforce compare-and-swap version predicates. Return stable conflict responses and preserve unique DB invariants.

**Verify:** Two concurrent connections test start/add/remove, release/reject, prosthetic transition/cancel, usage/recall. Assert legal final state, continuous history and one evidence event.

Evidence: `app/Domain/Sterilization/Actions/StartCycleAction.php:21`, `app/Domain/Sterilization/Actions/AddCycleItemAction.php:31`, `app/Domain/Sterilization/Actions/AddCycleItemAction.php:36`, `app/Domain/Sterilization/Actions/ReleaseCycleAction.php:32`, `app/Domain/Prosthetic/Actions/ChangeProstheticCaseStatusAction.php:23`, `app/Domain/Prosthetic/Actions/ChangeProstheticCaseStatusAction.php:40`

#### B08 — P1 — Account deletion and disable flow can remove only clinic owner access

**Classification:** confirmed_source. Not executed against a running backend.

Web profile destroy hard-deletes User; model has no SoftDeletes. Member disable checks permission/tenant but not self or last active owner. Depending on existing FK references, account deletion succeeds or errors; clinic can lose its only owner through disable. Existing generic profile test expects physical deletion.

**Fix:** Implement agreed soft-disable/anonymization and ownership-transfer policy while retaining attributable evidence. Guard last-owner/self lockout atomically and provide recovery/reactivation path.

**Verify:** Only-owner disable/delete, concurrent owner disables, user with releases/usages, user in multiple tenants. Evidence references remain readable and practice keeps recoverable ownership.

Evidence: `app/Http/Controllers/Settings/ProfileController.php:47`, `app/Models/User.php:39`, `app/Policies/TenantUserPolicy.php:15`, `app/Domain/Identity/Actions/DisableTenantMembershipAction.php:25`, `routes/settings.php:16`

#### B09 — P2 — Role delegation and DLU ownership differ across surfaces

**Classification:** confirmed_source_policy_decision. Not executed against a running backend.

Admin has invitations.create and may invite owner because every TenantRole is accepted. Web evidence settings is owner-only but API DLU mutations allow labels.manage (owner/admin/stock_manager). Web comment explicitly preserves this difference.

**Fix:** Agree delegation ceiling and DLU permission policy, then enforce consistently server-side and mirror in mobile. Do not silently assume every owner-only setting is restricted across API.

**Verify:** All six-role action matrix, admin invite owner, stock_manager API DLU versus web access, custom role grants and user with multiple memberships.

Evidence: `app/Http/Requests/Api/V1/Identity/CreateInvitationRequest.php:23`, `app/Policies/InvitationPolicy.php:11`, `app/Domain/Identity/Actions/CreateInvitationAction.php:41`, `app/Policies/DluRulePolicy.php:17`, `app/Http/Controllers/Web/Tenancy/PracticeSettingsController.php:41`

#### B10 — P1 — Cursor lists omit unique tie-break ordering

**Classification:** confirmed_query_risk. Query source confirmed. Installed Laravel cursor SQL and runtime reproduction remain verification work.

Queries explicitly sort by nonunique names/timestamps/date with cursor pagination. Waiting-placement dates commonly tie. Page boundary can skip rows sharing the last sort value; nullable expiry-date sorting in web batches adds another cursor edge case.

**Fix:** Append a stable unique ID to every cursor ordering and support reverse order consistently; define nullable sort behavior and validate/clamp API limits.

**Verify:** Seed more than one page of identical names/timestamps/returned dates; traverse forward/backward and assert each ID appears exactly once, including concurrent inserts and null values.

Evidence: `app/Domain/Prosthetic/Actions/ListProstheticCasesAction.php:45`, `app/Domain/Prosthetic/Actions/ListProstheticCasesAction.php:58`, `app/Http/Controllers/Api/V1/Prosthetic/ProstheticWaitingPlacementController.php:26`, `app/Http/Controllers/Api/V1/Catalog/ProductController.php:39`, `app/Http/Controllers/Api/V1/SitesController.php:29`

#### B11 — P1 — Data export can lose files or report success after failed storage write

**Classification:** confirmed_source. Not executed against a running backend.

Two attachments sharing file_name overwrite the same files/name path while file_count increments. Missing media are skipped silently. backups.put return is ignored with throw=false, allowing Completed after an unsuccessful write. Table-by-table reads are not a consistent snapshot and only tables containing tenant_id are exported.

**Fix:** Preserve media IDs/paths, verify every object with a manifest/checksum, fail explicitly on missing/write failure, stream large data, and define consistent portable export scope including required identity metadata while excluding credentials.

**Verify:** Two different photo.jpg inputs, missing media, storage failure, concurrent DB change, large dataset and restore/portability exercise validate counts, hashes, linkage and final download.

Evidence: `app/Domain/Reporting/Jobs/GenerateDataExportJob.php:96`, `app/Domain/Reporting/Jobs/GenerateDataExportJob.php:101`, `app/Domain/Reporting/Jobs/GenerateDataExportJob.php:152`, `app/Domain/Reporting/Jobs/GenerateDataExportJob.php:155`, `config/filesystems.php:105`

#### B12 — P1 — Export job can run before its request transaction commits

**Classification:** confirmed_source_race. Depends on actual queue connection/worker timing; runtime config not inspected.

Redis after_commit=false and dispatch is inside request transaction. Job reads request through separate pgsql_admin connection; if it starts early, row is absent and exception occurs before status-failure handler. Horizon default tries1 can leave persisted request Pending, blocking future export requests.

**Fix:** Dispatch after commit, make worker claims/transitions idempotent, configure retries/backoff/timeout and failed-job state recovery. Apply after-commit policy to invitation/notification queues too.

**Verify:** Hold transaction open while worker receives job, rollback dispatch, worker crash/timeouts, duplicate deliveries; ensure recoverable terminal state and no phantom invitation mail.

Evidence: `app/Domain/Reporting/Actions/RequestDataExportAction.php:50`, `app/Domain/Reporting/Actions/RequestDataExportAction.php:73`, `config/queue.php:74`, `config/horizon.php:187`, `app/Domain/Reporting/Jobs/GenerateDataExportJob.php:63`

#### B13 — P1 — Digest command omits PostgreSQL tenant context and retains disabled recipients

**Classification:** confirmed_source_runtime_dependency. Not executed against a running backend.

makeCurrent alone does not set transaction-local app.tenant_id; alert_settings/digest_subscriptions/role tables enforce RLS (database reviewer confirmed migrations). Command can fail under restricted app DB role. Recipient helper reads assigned role but never active tenant membership or global disabled_at; disabling preserves role assignments.

**Fix:** Use TenantContext for scheduled reads/writes, preserve context in finally and scope eligible recipients. Verify queued mailable model restoration also obtains required RLS context; tenant-aware queues only make tenant current with empty switch tasks.

**Verify:** Run scheduled command and queued mail under actual restricted DB role with two tenants and disabled former owners/clinicians; no cross-tenant data and no mail to disabled access.

Evidence: `app/Console/Commands/SendDigests.php:36`, `app/Console/Commands/SendDigests.php:39`, `app/Domain/Identity/Actions/ResolveTenantUsersWithRoleAction.php:25`, `app/Domain/Identity/Actions/ResolveTenantUsersWithRoleAction.php:31`, `app/Domain/Identity/Actions/DisableTenantMembershipAction.php:25`, `config/multitenancy.php:40`

#### B14 — P2 — Alert settings and stale alert resolution are incomplete

**Classification:** confirmed_source. Not executed against a running backend.

Detection ignores configured default low-stock threshold/control frequency/tolerance/escalation. It only visits batches with positive stock, so alerts on fully consumed batches never clear; setting threshold0 excludes a product from resolution. Missing-test alerts remain explicitly deferred.

**Fix:** Implement agreed semantics for visible settings; resolve no-longer-eligible subjects; label unsupported alert rules clearly until delivered. Latest migration already changes uniqueness to open-only, so repeated resolution uniqueness is not a current-up-schema bug.

**Verify:** Fully consume expired/near-expiry batch, disable threshold, restock, change settings and test schedule frequency. Confirm actionable open alerts and no misleading settings.

Evidence: `app/Domain/Inventory/Actions/DetectAlertsAction.php:39`, `app/Domain/Inventory/Actions/DetectAlertsAction.php:48`, `app/Domain/Inventory/Actions/DetectAlertsAction.php:62`, `app/Http/Requests/Api/V1/Inventory/UpdateAlertSettingsRequest.php:25`, `app/Http/Controllers/Web/Inventory/AlertController.php:18`

#### B15 — P1 — Actual label PDF ignores saved label format configuration

**Classification:** confirmed_source. Not executed against a running backend.

Print records store format version, but PDF generator passes no version/configuration and always produces A4 with both QR and DataMatrix. Separate PDF view reviewer confirms hardcoded template. Saved format/sample need not match actual printed output.

**Fix:** Render actual label from the selected recorded format and tested physical dimensions; decide immutable reprint snapshot/current format semantics. Keep PDF and print event consistent.

**Verify:** Every supported code/layout/visibility setting reflected in PDF; scan physical outputs on target printer; reprint after format update shows agreed version.

Evidence: `app/Domain/Labeling/Actions/RenderLabelPdfAction.php:17`, `app/Domain/Labeling/Actions/RenderLabelPdfAction.php:27`, `app/Domain/Labeling/Actions/PrintLabelAction.php:43`, `app/Domain/Labeling/Actions/PrintLabelAction.php:52`

#### B16 — P2 — Web cycle attachment upload calls missing method and DTO class

**Classification:** confirmed_source. Not executed against a running backend.

Reachable web store calls nonexistent AttachCycleFileAction::extractUploadedFile. CycleAttachmentData is not imported and resolves to nonexistent controller namespace; method returns DTO rather than expected web redirect. API upload uses separate controller.

**Fix:** Restore a valid upload extraction, imported DTO or intended Inertia redirect and verify Octane multipart behavior. Keep web fallback operational if it is part of clinic rollout.

**Verify:** Real web upload under FrankenPHP plus validation failure and subsequent list/download; static analysis of controller catches undefined method/class.

Evidence: `app/Http/Controllers/Web/Sterilization/CycleAttachmentController.php:18`, `app/Http/Controllers/Web/Sterilization/CycleAttachmentController.php:22`, `app/Http/Controllers/Web/Sterilization/CycleAttachmentController.php:27`, `app/Domain/Sterilization/Actions/AttachCycleFileAction.php:19`, `routes/web.php:60`

#### B17 — P1 — Clinical release prerequisites require an explicit clinic decision

**Classification:** confirmed_source_business_decision. Not executed against a running backend.

Current source permits compliant release without control-test success/presence and has no missing-test alert. Active-device check only occurs at draft creation, not start; attachments can be added/removed after release. These are observed semantics, not a claim about required clinical regulation.

**Fix:** Clinic/releaser accepts explicit required tests, override reasons, maintenance/device start rules, post-release evidence correction rules and timezone/date boundaries; implement agreed guards together across backend/mobile.

**Verify:** Signed scenario acceptance for absent/failed tests, device changed to maintenance after draft, post-release attachment changes, recall and local-day boundaries.

Evidence: `app/Domain/Sterilization/Actions/CreateCycleAction.php:26`, `app/Domain/Sterilization/Actions/StartCycleAction.php:21`, `app/Domain/Sterilization/Actions/SubmitCycleForReleaseAction.php:13`, `app/Domain/Sterilization/Actions/ReleaseCycleAction.php:32`, `app/Domain/Sterilization/Actions/AttachCycleFileAction.php:19`

#### B18 — P2 — Usage timestamp defaults to replay time and explicit null bypasses fallback

**Classification:** confirmed_source. Not executed against a running backend.

Omitted used_at becomes server now, so queued clinical usage changes occurrence time unless mobile captures it. Nullable used_at is accepted but PHP array union preserves explicit null instead of fallback. Placement date is server current UTC date; tenant timezone is not applied by TenantContext.

**Fix:** Capture occurrence time/timezone before persisting command; define server accepted bounds and explicit-null behavior. Separate occurred/recorded time and define clinical dates consistently with practice timezone.

**Verify:** Offline overnight replay, explicit null/omission, daylight-saving/local-midnight and device clock skew; verify evidence occurrence vs submission timestamp.

Evidence: `app/Http/Requests/Api/V1/Traceability/RecordLabelUsageRequest.php:29`, `app/Domain/Traceability/Actions/RecordLabelUsageAction.php:47`, `app/Domain/Traceability/Actions/RecordLabelUsageAction.php:49`, `app/Domain/Prosthetic/Actions/ChangeProstheticCaseStatusAction.php:37`, `config/app.php:70`

#### B19 — P2 — Clinic recovery and provisioning API gaps must be scoped deliberately

**Classification:** confirmed_source. Not executed against a running backend.

API has no forgot-password endpoint, site/room/location CRUD or location picker list, batches list, invitation index/reactivation or receipt attachment/list route. Web has management capabilities and Fortify reset but invitation email /accept-invitation target has no web route. Reinviting expired invitation blocked by pending check unless revoked; existing disabled member cannot be reinvited.

**Fix:** Agree mobile-only versus assisted web onboarding. Supply required mobile read/management/recovery endpoints, or intentional supported handoffs. Provide invitation list/resend/reactivation and real acceptance link/deep-link path.

**Verify:** Fresh empty clinic setup through receipt/stock/cycle, expired invite, disabled member recovery, forgotten password and email acceptance from installed/uninstalled app.

Evidence: `routes/api.php:47`, `routes/api.php:59`, `routes/api.php:66`, `routes/api.php:109`, `routes/web.php:138`, `routes/web.php:169`, `config/fortify.php:155`

#### B20 — P2 — Operational configuration still requires deployed evidence

**Classification:** source_defaults_runtime_unverified. Not executed against a running backend.

Backup destination is backups but monitor points local and notification address is placeholder. verify_backup=false. Email default log, Horizon tries1/timeout60, Redis retry_after90, uploads cleanup disabled in Octane. Queue tenant awareness does not set RLS by itself. Bearer middleware does not recheck active membership/global disable per request; normal member-disable action revokes its tokens. API login uses password without Fortify two-factor challenge.

**Fix:** Validate restricted-role workers, queues, mail, monitoring destinations, restore drill, PDF dependencies, reachable private signed URLs, persistent worker cleanup, auth revocation and intended mobile MFA requirements on deployed configuration. Do not infer deployed values from defaults.

**Verify:** Production-like smoke with scheduler/Horizon/MinIO-or-S3/mail/PDF; backup restore and failure alert; same worker alternating tenants; token disable/password reset/MFA scenarios.

Evidence: `config/backup.php:220`, `config/backup.php:255`, `config/backup.php:339`, `config/mail.php:17`, `config/horizon.php:181`, `config/queue.php:71`, `config/octane.php:86`, `config/multitenancy.php:40`, `app/Http/Middleware/Api/SetCurrentTenant.php:32`

### Role grants

| Role | Count | Grants |
|---|---:|---|
| owner | 36 | sites.view, products.view, suppliers.view, purchasing.view, inventory.view, alerts.view, devices.view, cycles.view, labels.view, patients.view, usages.view, non_conformities.view, prosthetic_cases.view, invitations.create, invitations.revoke, memberships.disable, sites.manage, audit.view, exports.manage, data_exports.manage, practice_settings.manage, prosthetic_payments.manage, products.manage, suppliers.manage, purchasing.manage, inventory.manage, alerts.manage, devices.manage, cycles.manage, labels.manage, cycles.release, non_conformities.manage, patients.manage, usages.manage, prosthetic_cases.manage, evidence_settings.manage |
| admin | 35 | sites.view, products.view, suppliers.view, purchasing.view, inventory.view, alerts.view, devices.view, cycles.view, labels.view, patients.view, usages.view, non_conformities.view, prosthetic_cases.view, invitations.create, invitations.revoke, memberships.disable, sites.manage, audit.view, exports.manage, data_exports.manage, practice_settings.manage, prosthetic_payments.manage, products.manage, suppliers.manage, purchasing.manage, inventory.manage, alerts.manage, devices.manage, cycles.manage, labels.manage, cycles.release, non_conformities.manage, patients.manage, usages.manage, prosthetic_cases.manage |
| stock_manager | 21 | sites.view, products.view, suppliers.view, purchasing.view, inventory.view, alerts.view, devices.view, cycles.view, labels.view, patients.view, usages.view, non_conformities.view, prosthetic_cases.view, products.manage, suppliers.manage, purchasing.manage, inventory.manage, alerts.manage, devices.manage, cycles.manage, labels.manage |
| releaser | 15 | sites.view, products.view, suppliers.view, purchasing.view, inventory.view, alerts.view, devices.view, cycles.view, labels.view, patients.view, usages.view, non_conformities.view, prosthetic_cases.view, cycles.release, non_conformities.manage |
| practitioner | 16 | sites.view, products.view, suppliers.view, purchasing.view, inventory.view, alerts.view, devices.view, cycles.view, labels.view, patients.view, usages.view, non_conformities.view, prosthetic_cases.view, patients.manage, usages.manage, prosthetic_cases.manage |
| viewer | 13 | sites.view, products.view, suppliers.view, purchasing.view, inventory.view, alerts.view, devices.view, cycles.view, labels.view, patients.view, usages.view, non_conformities.view, prosthetic_cases.view |

No global owner bypass in application providers/policies.
Current working-tree seeder is not proof deployed tenant roles have been reseeded.
Prosthetic PATCH rejects full request if unauthorized payment/clinical keys are supplied, despite contradictory comment.
Cancelled -> impression_completed is allowed by actual enum; Placed has no outgoing transition.
Stock/release/usage/audit evidence invariants have DB support per separate database reviewer; prosthetic history has no append-only trigger.

### Suggested order

1. Agree API surface, clinical decisions, six-role matrix and timestamp semantics.
2. Correct tenant validation, durable replay/command receipts, state concurrency, lookup/usage separation and retained histories.
3. Complete fresh-clinic provisioning, inventory/sterilization/usage/prosthetic flows and physical printing.
4. Correct worker/export/digest/alert behavior and verify backend contract against Flutter fixtures.
5. Demonstrate device and deployed-system evidence, recovery, restore, privacy and clinic acceptance before launch.


## Web workflows needed by the clinic

Complete read-only review of all 163 authored files under `C:/Users/mery/steriqore/resources/js`, including UI primitives, hooks, layouts, dialogs, pages and types. Generated `actions`, `routes` and `wayfinder` directories are explicitly excluded. Complete content read with original line numbers, blank lines omitted and indentation trimmed only. Initial truncated navigation-menu batch was reread in full. Manifest verification reports 163 files, 960,443 bytes, 24,532 lines, zero unread paths and zero hash mismatches. No production changes or runtime claims. Backend AGENTS.md and required `.cursor/skills/inertia-react-development/SKILL.md` read. Existing plans/dumps were not used.

### Important confirmed issues affecting clinic journeys

1. **Physical print and recorded print are separate disconnected actions.** `pages/sterilization/cycles/labels.tsx:284` Print sheet calls only `window.print()`. Individual Print at :219-224 only posts the record; it never opens a PDF or browser print flow. Download PDF at :208 is independent. `pages/sterilization/labels/show.tsx:250,261-266` repeats this separation. Server Web LabelController:122-132 confirms POST returns back with a success toast; pdf :135-139 only renders. A user can produce a physical sheet with labels still Created and no print log, or record a print without producing a physical label. ResolveLabelScanAction returns Created unchanged; RecordLabelUsageAction:39 requires Used. This is part of mandatory web-label to mobile-scan acceptance, not justification to add mobile printing. Fix as a coherent print intent/preview/download/record workflow with explicit print outcome, valid state/permission checks, retry/deduplication and real printer acceptance.

2. **Print/reprint actions ignore role and unusable state in both label pages.** Cycle LabelCard accepts only label/item (:163), and detail props omit canPrint (:182-215). Both choose Print/Reprint solely from `print_counter` (cycle :216; detail :258), including recalled/expired/used labels and view-only roles. Backend authorization still applies, so this is confirmed UI denial/dead-end and unsafe action affordance rather than an authorization bypass. Gate by permission and printable domain state; align with backend print invariant fixes found by core reviewer.

3. **Real output does not honor the promise made by label settings.** `pages/tenancy/practice-settings/label-format-section.tsx:91-98,223-227` promises selected sheet layout, code emphasis, optional fields, and unchanged appearance for old labels. The sample endpoint receives all fields (:57-65), but actual cycle sheet is a generic `columns-1 ... md:columns-2` page (:329) with hardcoded QR size20/DataMatrix h10w20 (:171-178). Actual RenderLabelPdfAction:14-28 passes current relations, both codes and fixed A4 without format version. LabelController.pdf has no print/version parameter. Preserve/version rendering evidence and make actual sheet/PDF match the approved sample/printer. This is a cross-platform integration requirement.

4. **Audit details hide explicit null changes.** `pages/compliance/audit-log/index.tsx:115` displays `formatValue(newVal ?? oldVal)` in After. When a name/field changes from a value to null, After shows the old value despite the change being highlighted. Use key presence/new_values existence to distinguish absent data from explicit null; test cleared fields, deleted fields and create events. Source-local deterministic defect.

5. **Receipt validation errors are collected but mostly invisible.** `pages/purchasing/purchase-orders/show.tsx:182-183` saves all server errors, yet only `errors.location_id` is rendered (:243-247). Errors for nested lot/expiry/qty/discrepancy lines have no UI. The create PO screen similarly renders supplier error only (:129-133), omitting `lines.*` errors. Surface every field and a form summary with retained drafts. Same pattern in AddProgramForm (devices/show:407-484, no error rendering) and supplier-product linking (suppliers/show:184-293). Keep the mobile-first plan targeted, but shared clinic acceptance should cover web provisioning forms used to bootstrap the app.

6. **Export download fails silently.** `pages/reporting/data-exports/index.tsx:124-125` returns on non-OK response, and network/JSON errors lack catch at :111-132. Successful URL opens after await (:129), which needs popup-blocker handling on real browsers. The page accepts CursorPaginated exports (:189) but renders no previous/next controls (entire file), so older export requests cannot be reached. Add useful error/retry/download link plus pagination.

7. **Batch near-expiry badge ignores configured alert window.** `pages/inventory/batches/index.tsx:40-44,59` hardcodes 30 days and claims it mirrors a constant; practice alert settings expose editable `near_expiry_days` (`alerts-section.tsx:89,155-172`). Need backend-derived expiry classification or supplied threshold so a configured 60-day warning does not disagree with the batch list. Date-only expiry and timezone behavior needs runtime boundary acceptance; no unsupported exact off-by-one claim.

8. **Storage locations without a room disappear from site management.** StorageLocation type permits room_id null (`types/tenancy.ts:32`), but `pages/tenancy/sites/show.tsx:893-896` skips them and renders only grouped rooms (:1001-1111). Existing API-created site-level locations can be counted and used in stock while invisible for edit/archive on this page. Render unassigned/site-level group or explicitly migrate/enforce room requirement consistently.

### Existing capabilities to preserve; do not re-specify as missing

- Permission-filtered navigation, tenancy/site switching, sidebar, flash toasts and normal auth/reset/verification/MFA/passkey/profile flows exist. Alternative header/card/split layouts are defined but app default uses sidebar/simple layouts; placeholder search/header external docs there should not be reported as active main navigation defects. Root welcome is still starter Laravel page (`routes/web.php:40`, welcome.tsx:43-48); modest release polish if web is exposed, not a clinical app rebuild.
- Paginated cycles, labels, controls, products, suppliers, batches, stock, stock movements, patients, evidence, NC and audit lists exist. Search/filter composition and HTTP error/retry needs browser tests; source alone does not establish Inertia server/network callback behavior.
- Web cycles include current release decision with actor/time/reason (cycles/show:576-607), linked original attachment access (:779-786), control entry, load composition and recall dialog. AddItemForm sends description only (:253), so batch association is absent on web as on routed mobile; backend supports batch IDs. Preserve traceability requirements rather than claiming stock UI automatically supplies the link.
- Web purchasing supports creation, mark ordered, cancel draft/ordered, partial receipts and receipt history. Storage location choices come as separate controller props, allowing first stock on web (purchase-orders/show:124-132,189-204,367-424); mobile must consume actual location catalogs. Supplier/product/catalog and device/program/maintenance provisioning exists.
- Web sites/rooms/locations create/edit/archive exist with impact copy; practice identity/logo, DLU rules, label format/sample and alert/digest preferences exist. No need to add all admin provisioning to mobile unless original scope requires it.
- Web label usage, print history, patient procedure history, evidence dossier link, filtered CSV/XLSX exports, full archive request/poll/download exist. Mobile missing link/view actions can use these existing contracts rather than invent parallel domains.
- Team invitation, disabling access and revocation exist. No authored prosthetic web page found in this complete JS inventory; prosthetic mobile feature and API exist, so do not infer a mobile missing feature from web absence.

### Review artifacts and limits

- `backend_frontend_manifest.json`: every file read with SHA256/bytes/lines.
- `clinical_manifest_verification.json`: final denominator/read/unread/hash comparison for both reviewer scopes.
- No runtime browser, printer, patient workflow or network mutation was performed by this reviewer. Parent/core/release agents own repository tests and environment evidence. Completion requires role-based real-device plus web printer scenarios after fixes; static reading is not a zero-defect guarantee.


## Backend schema, tests and operations

Reviewed 2026-10-01. Reviewer: release_test_audit. Backend root: `C:/Users/mery/steriqore`.

### Scope and evidence limits

The exact per-path manifest is `backend-outside-app-manifest.json`. All 234 assigned, retained files were read completely: 59 database files, 79 PHP test files, 34 browser-test files, 8 non-JavaScript resource files, 7 backend documents, 6 source stubs, 4 public files, 3 relevant local skills, and 34 other configuration/instruction/tooling files. The retained files total 938,932 bytes. Closing SHA-256 hashes identify this reviewed source snapshot; they do not establish a runtime result.

The manifest also records 444 authored server files assigned to core_safety_audit, 163 authored `resources/js` files assigned to clinical_workflows_audit, 63 explicitly excluded entries, and 3 excluded directory roots. The initial 445 server inventory included `bootstrap/cache/.gitignore`; that generated-cache placeholder is now excluded. No assigned retained file remains unread. Generated Wayfinder code, build/cache/log output, dependencies, secret files, binary assets, generated lock/spec snapshots, vendor translations, old plans/source dumps and irrelevant uninvoked editor skills are explicitly excluded. Forbidden mobile PRODUCT_COMPLETION_PLAN and old backend master plans were not read.

This was a read-only backend review. No backend tests, services, mail, jobs, migrations, database queries or deployment actions were run. Test counts below describe source coverage, not passing results. Documents describing earlier successful checks are historical claims, not fresh verification.

### Release blockers and required fixes

#### 1. Reproduce backend CI against its actual database and runtime role

**Source:** `.github/workflows/tests.yml:13`, `:35`, `:38`; `composer.json:65`; `phpunit.xml:39`.

The PHP CI job runs `composer setup`, which runs migrations, then `composer ci:check`. That job provisions no PostgreSQL service or required databases/roles. The separate E2E Docker job does not supply services to it. Tests require PostgreSQL at port 5455, database `steriqore_test`, administrative role `steriqore`. The default setup configuration instead uses the restricted application role.

**Fix:** give this job explicit disposable PostgreSQL/Redis setup, privileged migrations, restricted application credentials and reproducible asset dependencies. Run static analysis, PHP tests, frontend type/lint checks and real acceptance tests, publishing fresh artifacts. Do not use the deployment document's acceptance of existing PHPStan errors as the release criterion.

**Important gap:** most PHP tests run through the database owner/admin role, bypassing RLS. `tests/Feature/Tenancy/TenantIsolationTest.php:66` selectively changes role, and `tests/Feature/Compliance/SecurityEventTest.php:144` checks a restricted-role case. They do not prove restricted-role behavior for every domain or scheduled/queued job. Add restricted-role checks for digests, exports, prosthetics and background jobs, and real long-running-worker cross-tenant isolation tests.

#### 2. Fix staging database credential provisioning

**Source:** `.env.staging.example:25`, `docker-compose.staging.yml:60`, `:63`, `docker/postgres/init/01-create-app-role.sql:13`.

Staging expects `DB_PASSWORD=CHANGE_ME` to be supplied for `steriqore_app`, but its shared initialization SQL creates that role with the fixed development password `steriqore_app_secret`. Compose provides the admin password to PostgreSQL, not a mechanism that updates this restricted role to the configured application password.

**Fix:** provision the application role with the configured secret, including a safe existing-volume upgrade path. Verify the actual runtime connection is non-superuser/NOBYPASSRLS and that migration credentials are separate. This is a repository provisioning defect; this audit did not establish which credentials the user's deployed backend currently uses.

#### 3. Close Docker context exclusions before building a release image

**Source:** `.dockerignore:10`, `Dockerfile:21`, `Dockerfile:108`, `.gitignore:18`.

The Dockerfile copies the source context in full. `.dockerignore` excludes `.env`, `.env.local`, `.env.*.local` and `.env.coolify`, but not the present `.env.staging` or derived capture/pilot environment files and source dumps. Git ignoring a file does not keep it out of a local Docker build context. Secret contents were not opened.

**Fix:** exclude all real environment/secret/capture/dump artifacts, with deliberate exceptions only for safe example files. Inspect the resulting image/context for sensitive paths. Determine whether prior distributed images contained sensitive files before deciding whether credentials need rotation. This audit found an inclusion path, not proof that secrets were published.

#### 4. Preserve queued work and replay state under memory pressure

**Source:** `docker-compose.yml:92`, `:166`; `docker-compose.staging.yml:76`; `.env.staging.example:35`.

Redis uses a 256 MB `allkeys-lru` policy while serving queues, sessions and cache. This can evict queue or idempotency keys along with ordinary cache entries. Append-only persistence does not prevent policy-driven eviction.

**Fix:** separate evictable cache from durable queue/replay state, or establish appropriate no-eviction/storage/capacity behavior. Exercise an ambiguous-response retry and memory-pressure scenario. Existing sequential idempotency tests do not cover key eviction, expiry or concurrent duplicate requests.

#### 5. Make actual label output obey the recorded format settings

**Source:** `resources/views/pdf/label.blade.php:37`; `resources/views/pdf/label-format-sample.blade.php:36`, `:55`. Server reviewer confirms `app/Domain/Labeling/Actions/RenderLabelPdfAction.php:14` passes no print/format version and forces A4.

The real label view fixes QR/DataMatrix and displayed fields; the format settings used by the sample are not used by actual printing. The sample's CSS targets `svg.primary`/`svg.secondary` while its classes are on wrapper divs, so those size rules do not match.

**Fix:** render the correct saved format version for each print and reprint, including physical dimensions, code selection and chosen fields. Validate actual PDF dimensions and code readability, then print/scan on the clinic's chosen hardware. Settings saved successfully or a print toast does not establish usable output.

The evidence dossier also renders current user/device names (`resources/views/pdf/evidence-dossier.blade.php:30`, `:32`, `:58`, `:78`). The label uses current site/operator names (`label.blade.php:43`, `:58`). Decide which historical identity fields must be stable and render preserved snapshots where required; a later rename currently changes regenerated documents.

#### 6. Resolve schema and membership findings together with server fixes

Confirmed protections already present:

- Immutable audit events: `database/migrations/2026_07_25_150000_create_audit_events_table.php:43`.
- Immutable stock movement ledger and tenant/idempotency uniqueness: `2026_07_27_100001_create_stock_movements_table.php:44`, `:58`.
- One immutable release per cycle: `2026_07_30_000001_create_cycle_releases_table.php:22`, `:33`.
- One label per cycle item: `2026_07_31_000002_create_labels_table.php:25`.
- Immutable print records with unique print sequence: `2026_07_31_000003_create_label_prints_table.php:28`, `:31`.
- One immutable usage per label, with restrictive identity FKs: `2026_08_02_000001_create_label_usages_table.php:23`, `:35`.

The latest alerts migration correctly uses open-only uniqueness: `2026_09_26_000004_fix_alerts_unique_constraint_to_open_state_only.php:29`. The earlier recurring-resolved conflict is already corrected in the current schema. Its `down()` restores full historical uniqueness and can fail after multiple resolved rows accumulate; rollback instructions must account for that data shape.

Remaining schema implications:

- Prosthetic status history is described as append-only but has no immutable trigger, and its case FK cascades deletion (`2026_09_26_000003_create_prosthetic_case_status_history_table.php:18`). Add the intended database protection and realistic transition/deletion tests. This audit found no exposed arbitrary-history-edit endpoint.
- `tenant_user`, invitations and personal tokens intentionally lack RLS; identity/bootstrap scoping must be correct in application code. Most child FKs are ID-only, so tenant-consistent relationships also require correct application checks.
- `alert_settings`, `digest_subscriptions`, `roles`, `model_has_roles` and `model_has_permissions` force RLS (`2026_08_07_000004_create_alert_settings_and_digest_subscriptions_tables.php:33`, `:53`; `2026_07_25_112137_add_row_level_security_to_permission_tables.php:18`). The server reviewer found digest code setting only the Spatie current tenant without the database tenant context, plus recipient role queries that do not filter disabled memberships. Fix context and active membership filtering together, with restricted-role tests and disabled-recipient regression coverage.
- Generic profile tests explicitly assert full user deletion (`tests/Feature/Settings/ProfileUpdateTest.php:53`). Server review confirms the controller performs it. Replace that behavior with the agreed identity-retention/disable rules and test the last owner and users referenced by clinical evidence. Existing simple-user deletion coverage does not prove safe handling of referenced identities.

### Automated evidence: useful coverage and remaining gaps

#### PHP tests: 79 source files

The suite contains meaningful API/web checks for permissions, tenant object access, ledger deltas/rebuild, release transitions, label usage, recalls/quarantine, soft-deleted history, reprint reasons and sequential replay. These are valuable starting points.

Specific gaps to repair before trusting the suite as a release gate:

1. No `prosthetic` or `laboratory` references were found anywhere under `tests/` or `e2e/`. Cover the new domain's transitions, deposits/payments, attachments, membership permissions and tenant isolation.
2. Shared global fixture functions live inside other feature-test files: `tests/Feature/Api/V1/CycleTest.php:14`, `:33`, `:42`; `ControlTestTest.php:5`; `CycleReleaseTest.php:13`; `LabelTest.php:18`, `:30`; `LabelScanTest.php:10`; `EvidenceSearchTest.php:12`. Move them into explicit shared fixtures loaded by Pest so targeted files can run independently.
3. The release immutability test executes failed UPDATE then DELETE in one transaction (`tests/Feature/Api/V1/CycleReleaseTest.php:125`). PostgreSQL may reject the second statement because the transaction is already aborted. Use independent savepoints/transactions and assert the specific intended rejection. `tests/Feature/Compliance/AuditEventTest.php:139` has the stronger pattern.
4. `tests/Feature/Api/V1/DataExportRequestTest.php:202` explicitly avoids the successful export-job path because its separate connection cannot see the test's uncommitted fixtures. Cover a committed job with real queue/storage/archive inspection. PDF/storage/Excel fakes elsewhere test orchestration, not the actual generated files.
5. `tests/Feature/Web/SiteTest.php:146` permits archiving a location holding five units; it does not assert a safe usable disposition of remaining stock. Decide and test transfer/archive behavior.
6. TestCase clears cached authentication guards on each request (`tests/TestCase.php:61`). This makes tests predictable but does not establish real Octane worker isolation. Exercise successive users/tenants through a real long-running server.
7. Existing idempotency cases are sequential (`tests/Feature/Api/V1/PurchaseOrderTest.php:144`, `AuthTest.php:104`). Add concurrency, response-loss, retry-after-auth-refresh and durable replay checks for clinic-critical writes.

#### Browser tests: 34 source files

`e2e/acceptance/journey.spec.ts` is a substantial real-backend journey: new practice registration, invitations, inventory receipt, device/cycle/control setup, release/reject, DLU, labels, usage, evidence PDF content parsing, disabled member identity retention, cross-tenant denial/security-event evidence, sequential receipt replay and recall.

Boundaries of that evidence:

- It performs the main journey with owner, admin and practitioner. Dedicated daily workflows for stock_manager, releaser and viewer remain necessary. API setup/shortcuts are intentional in several steps; it is not a six-role all-UI proof.
- Actual printing is a click and toast (`journey.spec.ts:441`), and usage scanning is an API request (`:460`). Physical printing, camera scanning and mobile behavior remain untested here.
- Its dossier section actually parses a generated PDF (`:583`); retain and extend this useful check.
- The volume test waits for the first matching evidence row (`e2e/acceptance/volume.spec.ts:88`), not every result/page. Its title overstates complete result verification. Add expected counts, paging and mobile representative network/device measurements.
- Data export E2E may reuse an existing ready request if creation is disabled (`e2e/data-exports.spec.ts:25`, `:41`), inspects the manifest UI, and mints a URL (`:58`). It never downloads and checks a fresh ZIP or proves all media/tenant boundaries. Give each run its own request and inspect the actual archive.
- Several regular specs depend on shared demo stock existing (`e2e/alerts.spec.ts:21`, `stock.spec.ts:21`, `quarantine.spec.ts:33`). Some tests have overstated names: `cycle-detail.spec.ts:73` uses a random missing UUID as a cross-tenant case; `cycles.spec.ts:65` checks the owner's visible link rather than a forbidden role's hidden navigation. Keep the strong true cross-tenant acceptance case and improve the narrower claims.

### Deployment and operating prerequisites

- Validate private signed media and export URLs from a physical clinic device. Development URLs use `localhost` and internal `minio`; those are not automatically reachable from a phone. Staging examples also use an internal object-store endpoint. Verify deployed public addressing before changing a working live configuration.
- Restore a recent backup into an isolated environment using restricted-role application access, then compare tenant counts, ledger totals, labels/usages and media. The repository contains fake-storage backup tests and documents an earlier drill; no fresh drill was performed in this review.
- Exercise a fresh export through the real worker. The server reviewer identified an ignored object-storage put result, duplicate file-name overwrites and dispatch before transaction commit; all must be tested by inspecting the downloaded archive, not status alone.
- Rehearse worker restarts, pending queues, scheduled alerts/digests, disabled-user recipients, attachment access/expiry and application restart during a mobile write.
- Rebuild onboarding commands: README refers to `./steriqore.sh` (`README.md:29`, `:38`, `:50`), but that file is absent from this physical source inventory.
- Decide clinic-approved DLU, control-test/release rules, stock-count scope and allowed recall resolution behavior. Do not invent regulatory durations. `docs/open-questions.md:118` explicitly requires DLU configuration; `:145` records unimplemented periodic control-test frequency handling; `:24` defers inventory counts. Treat these as product decisions requiring present-day confirmation, rather than automatic proof the current clinic's workflow is complete.

### Documentation reconciliation

Relevant docs were read after source inspection and were not used as evidence of passing current behavior:

- `docs/erd.md:3` says no migrations exist, while the source has 56 migrations. Its identity-table RLS statements disagree with current migrations and `docs/open-questions.md:41`.
- `docs/coverage-matrix.md` route/permission/page totals are historical and omit the newer prosthetics surface. Its no-authorization-defects conclusion does not replace source review or fresh tests.
- `docs/deployment.md:42` describes a staging skeleton and `:154` accepts existing PHPStan errors; neither establishes the user's current deployed setup nor an appropriate release gate.
- `docs/operations.md:52` describes an earlier backup drill; `:108` says all mutations require idempotency. Current API route behavior must be reconciled with that claim.
- `docs/performance.md:25` publishes older timings. This review did not reproduce them, and complete mobile paging is a separate requirement.
- `docs/BACKEND_BUGS.md` ends after 26 lines in an incomplete first issue; it is not a complete current defect register.

### Suggested order and exit criteria

1. **Establish reproducible evidence:** fix CI/test fixtures, run the complete restricted-role backend and mobile checks, remove misleading test assertions and publish current artifacts. Exit: a fresh reproducible baseline with every remaining failure triaged.
2. **Protect identities, tenancy and clinical state:** fix backend permission/context/identity findings plus mobile tenant/session/offline issues from the other reviews. Exit: six-role permissions and cross-tenant/disabled-member/worker tests pass, with safe repeat/retry behavior.
3. **Complete each clinic workflow end to end:** purchasing/receipts, equipment/cycles/control/release, labels/physical scan/usage, recall/quarantine, evidence and prosthetics. Exit: real device users can finish each authorized daily task and recover from expected failures without duplicate or lost records.
4. **Make outputs and background operations reliable:** actual print format versions, stable evidence identity, real exports, digests, media, backup restore, durable queues and deployment secrets/credentials. Exit: artifacts are inspected, physical labels scanned and recovery rehearsed.
5. **Pilot and release:** use the clinic's agreed protocol and devices with all six roles; verify training/support/privacy/operations, rehearse upgrade/rollback and perform a supervised pilot. Exit: clinic acceptance plus measured release gates. No source review can substantiate a promise of zero future issues.


## Mobile test evidence and limits

Read all 111 assigned files (10,250 lines). Final hashes match the bytes read. See `mobile-tests-source-manifest.json` for each file and read batch.

Read-only test source review. No suite or live backend tests executed by this reviewer in this fresh pass. Parent-reported prior green baseline is separate dated evidence.

The suite has useful regression coverage. It is not complete clinic-readiness evidence. Test names and historical comments were checked against bodies.

### Confirmed limits and next verification

#### T01 P1: Clinic journeys are mostly empty or manually gated

Only auth_journey and cycle_lifecycle_journey contain live journey test bodies. Eight other named journeys and app_test are empty; seed/reset/test_data helpers are empty. Both nonempty journeys skip unless RUN_LIVE_INTEGRATION_TESTS is explicitly enabled and require prepared local fixtures.

Source presence and an ordinary green test run do not prove either live journey ran. The cycle journey checks the released status after refresh, but does not cover recall/reprint/usage, rejected release, concurrent actors, or two independent roles.

**Next verification:** Build disposable deterministic tenant fixtures for six roles, run against an isolated backend, and assert persisted outcomes for cycle-to-label-to-patient usage, receipt/issue/transfer, prosthetic clinical/payment, expired/recall NC, identity recovery and offline recovery. Record device, build, backend revision and test data. Do not point mutation tests at clinic data.

**Evidence:** `integration_test/journeys/auth_journey_test.dart:33`; `integration_test/journeys/auth_journey_test.dart:58`; `integration_test/journeys/cycle_lifecycle_journey_test.dart:70`; `integration_test/journeys/cycle_lifecycle_journey_test.dart:171`; `integration_test/support/live_backend_guard.dart:17`

#### T02 P1: The API contract check validates a selected historical path list only

The manually enumerated static and dynamic helper maps are matched against a path-only snapshot. forgotPassword is absent from those maps. The known missing sites/{id} path is asserted false, so its absence leaves the suite green.

No HTTP method, auth, permissions, request validation, cursor/query semantics or response DTO is checked. The snapshot describes a prior fetch, not the current running backend.

**Next verification:** Generate the supported mobile contract from the selected backend revision; check every used method/path, representative valid/invalid request bodies, response fixtures and actual permissions. Fail on unapproved unsupported mobile routes. Keep deliberate web handoffs explicit.

**Evidence:** `test/unit/contract/api_endpoints_test.dart:9`; `test/unit/contract/api_endpoints_test.dart:61`; `test/unit/contract/api_endpoints_test.dart:71`; `test/unit/contract/api_endpoints_test.dart:110`; `test/unit/contract/api_endpoints_test.dart:171`; `test/fixtures/contract/openapi_paths_snapshot.json`

#### T03 P1: Durable replay safety has no restart or unknown-result proof

Interceptor tests check header addition and preserving a caller key. Repository tests mock datasource/outbox and explicitly expect an online success never to touch outbox. Store tests open a real Hive box but only close at teardown, never reopen persisted commands. Engine tests cover flushing flag, successful removal, 409 and 422.

The suite cannot detect a first request committed on the server followed by timeout and replay with a new key, app death during processing, lost commands on account switch, changed payload bytes, lost occurrence time or duplicate execution beyond the backend 24-hour cache.

**Next verification:** After defining durable command and backend receipt contracts, inject failures before send, after server commit and before local acknowledgement; kill/restart/reopen storage; verify exactly one domain effect and original actor/tenant/bytes/key/time. Exercise auth expiry and revocation, transient backoff, expired dedup retention, conflict review, dependency ordering and concurrent flush. Use an actual backend for atomicity assertions.

**Evidence:** `test/unit/core/idempotency_interceptor_test.dart:81`; `test/unit/core/idempotency_interceptor_test.dart:102`; `test/unit/repositories/cycle_repository_test.dart:87`; `test/unit/repositories/label_usage_repository_test.dart:65`; `test/unit/repositories/purchase_repository_test.dart:69`; `test/unit/storage/outbox_store_test.dart:20`; `test/unit/storage/outbox_store_test.dart:25`; `test/unit/storage/sync_engine_test.dart:31`; `test/unit/storage/sync_engine_test.dart:54`; `test/unit/storage/sync_engine_test.dart:72`; `test/unit/storage/sync_engine_test.dart:107`

#### T04 P1: Current tests bless an unavailable usage history as empty success

The failure test explicitly expects a swallowed usage-history exception and an empty history while the label remains a successful result.

A staff member cannot infer no prior usage from a failed history fetch. This is a behavioral regression expectation that should change together with the product state model.

**Next verification:** Separate label metadata availability from history availability. Assert an explicit unavailable/retry state while preserving any already known history; test a prior-used label whose history request fails.

**Evidence:** `test/bloc/label_detail_bloc_test.dart:74`; `test/bloc/label_detail_bloc_test.dart:79`; `test/bloc/label_detail_bloc_test.dart:91`; `test/bloc/label_detail_bloc_test.dart:92`

#### T05 P1: Role tests cover UI samples but no server-authorized action matrix

Copied grants match the current server seeder for all six roles. Useful assertions cover practitioner payment restrictions, stock-manager release restrictions and viewer controls on cycle/prosthetic detail. Bottom-tab expectation uses RoleGuard itself, and viewer Scanner visibility is explicitly accepted.

Mocked repositories cannot detect the confirmed backend GET scan mutation granted through labels.view, direct API calls, stale permission after membership revocation, cross-tenant resources or admin inviting owner. Tab expectations alone are partly coupled to implementation.

**Next verification:** Use an independent capability table and backend allow/deny tests for all six roles. Combine deep-link/UI checks with direct endpoint assertions and prove read-only requests produce no audit/domain writes. Include clinical-only PATCH, payment-only PATCH, mixed forbidden payload, membership disable/last-owner decisions and invitation role delegation.

**Evidence:** `test/widget/rbac_role_matrix_test.dart:55`; `test/widget/rbac_role_matrix_test.dart:176`; `test/widget/rbac_role_matrix_test.dart:190`; `test/widget/rbac_role_matrix_test.dart:204`; `test/widget/rbac_role_matrix_test.dart:253`; `test/widget/rbac_role_matrix_test.dart:338`; `test/widget/rbac_role_matrix_test.dart:429`; `test/widget/rbac_role_matrix_test.dart:443`

#### T06 P1: Mocked fixtures can pass with invalid backend request shapes

The purchase repository fixture uses line_id and qty_received; current server validation requires purchase_order_line_id, batch_number and qty. The receipt widget payload assertion checks line ID and qty but not its claimed batch number. A prosthetic test named real update endpoint only invokes and verifies a mock repository.

These findings concern validation coverage and wording; they do not by themselves prove the actual screen sends the invalid repository-test fixture.

**Next verification:** Use server-valid payload/DTO fixtures, assert the complete emitted HTTP request at the datasource boundary, and exercise validation against the isolated backend. Rename mock-only test descriptions to state the actual scope.

**Evidence:** `test/unit/repositories/purchase_repository_test.dart:35`; `test/widget/goods_receipt_flow_test.dart:133`; `test/widget/goods_receipt_flow_test.dart:166`; `test/widget/goods_receipt_flow_test.dart:167`; `test/widget/prosthetic_case_detail_test.dart:60`; `test/widget/prosthetic_case_detail_test.dart:107`; `test/widget/prosthetic_case_detail_test.dart:129`; `C:/Users/mery/steriqore/app/Http/Requests/Api/V1/Purchasing/ReceiveGoodsRequest.php:32`; `C:/Users/mery/steriqore/app/Http/Requests/Api/V1/Purchasing/ReceiveGoodsRequest.php:38`; `C:/Users/mery/steriqore/app/Http/Requests/Api/V1/Purchasing/ReceiveGoodsRequest.php:40`

#### T07 P1: Session, draft and privacy tests do not demonstrate isolation across accounts

Draft tests verify mocked key-value serialization, corruption handling and label-separated keys. Auth and expiry tests isolate mocked dependencies. Crash tests scrub message/exception strings and flat breadcrumb values.

No source test proves encrypted real storage, tenant/user namespace, legacy migration, logout with pending work, old responses during a new login, membership disable during replay, or nested telemetry sanitization. Storage corruption fallback coverage exists but does not cover full app recovery.

**Next verification:** Use two tenants and two users on the same app installation, persist drafts/cache/outbox, restart and switch accounts; assert no data/replay crosses the boundary. Verify current-session expiry handling, conservative legacy migration and actual telemetry payload sanitation with nested metadata and URLs.

**Evidence:** `test/unit/storage/label_usage_draft_store_test.dart:56`; `test/unit/storage/label_usage_draft_store_test.dart:96`; `test/unit/features/prosthetic/prosthetic_case_draft_store_test.dart:50`; `test/unit/features/prosthetic/prosthetic_case_draft_store_test.dart:94`; `test/unit/core/crash_reporter_scrub_test.dart:29`; `test/unit/core/crash_reporter_scrub_test.dart:83`; `test/unit/core/error_interceptor_test.dart`; `test/bloc/auth_bloc_test.dart`

#### T08 P2: Pagination tests do not prove complete clinic totals or stable server cursors

Tests prove mocked next-cursor propagation and appended items. Aging KPI tests use three items on one loaded page, with an explicit comment that counts reflect the loaded page. List tests pass filters to mocked repositories.

These tests do not establish complete clinic counts/search or prevent skipped/duplicated records when backend sort keys tie. They do not measure behavior at clinic-sized datasets.

**Next verification:** Create more than two pages including identical sort timestamps/dates and boundary aging values; compare concatenated unique IDs and server totals to the fixture truth, then filter/search and refresh. Validate global-count labels separately from loaded-page summaries.

**Evidence:** `test/widget/prosthetic_waiting_placement_screen_test.dart:37`; `test/widget/prosthetic_waiting_placement_screen_test.dart:112`; `test/widget/prosthetic_waiting_placement_screen_test.dart:143`; `test/widget/waiting_placement_screen_test.dart:103`; `test/bloc/prosthetic_list_bloc_test.dart`

#### T09 P2: Print/export tests validate headers and file writes, not usable evidence

PDF assertions check nonempty output and a %PDF- header. Export download stubs write four ZIP signature bytes and assert that file.

This does not prove page readability, full content, text encoding, printable barcode size, clinical timestamps, archive integrity, distinct attachments, signed-download permissions or evidence consistency after settings changes.

**Next verification:** Parse and inspect generated multi-page documents, extract representative text and visually inspect long content on the intended print format. Open actual export archives, verify checksums and distinct same-named attachments, and check frozen label-version output. Include physical printer/scanner acceptance where the clinic workflow requires it.

**Evidence:** `test/unit/features/prosthetic/prosthetic_case_pdf_test.dart:16`; `test/unit/features/prosthetic/prosthetic_case_pdf_test.dart:19`; `test/unit/features/prosthetic/prosthetic_case_pdf_test.dart:39`; `test/unit/features/reporting/export_download_service_test.dart:55`; `test/unit/features/reporting/export_download_service_test.dart:57`; `test/unit/features/reporting/export_download_service_test.dart:71`

#### T10 P2: Visual, permission and leak tests are useful local tripwires with narrow scope

Default goldens use an 800x1400 canvas at DPR1 with fallback fonts and explicitly disclaim phone framing. Leak checking uses source regex for disposal calls. Notification tests mock a platform channel. The back-button regression exercises a real small GoRouter graph but invokes PopScope callback directly.

No full physical-device evidence follows from these unit/widget tests: small-screen layout, large text, keyboard overlap, camera and permanently denied permissions, OS resume/back behavior, real printing/download sharing, notification delivery, and memory stability remain separate acceptance work.

**Next verification:** Retain fast tests; run a targeted device matrix with actual app fonts, narrow supported screens, large text, offline/resume/rotation where supported, camera permission transitions and hardware back. Validate the chosen notification feature end-to-end; OS permission alone is not delivery.

**Evidence:** `test/golden/golden_helpers.dart:4`; `test/golden/golden_helpers.dart:17`; `test/golden/golden_helpers.dart:18`; `test/golden/shared_widget_gallery_golden_test.dart:35`; `test/unit/core/leak_check_test.dart:102`; `test/widget/settings_screen_test.dart:47`; `test/widget/shell_screen_back_button_test.dart:91`

### Empty assigned files

- `integration_test/app_test.dart`
- `integration_test/journeys/alert_resolve_journey_test.dart`
- `integration_test/journeys/conflict_409_journey_test.dart`
- `integration_test/journeys/goods_receipt_journey_test.dart`
- `integration_test/journeys/offline_sync_journey_test.dart`
- `integration_test/journeys/prosthetic_case_journey_test.dart`
- `integration_test/journeys/scanner_usage_journey_test.dart`
- `integration_test/journeys/stock_issue_journey_test.dart`
- `integration_test/journeys/waiting_placement_journey_test.dart`
- `integration_test/support/backend_reset.dart`
- `integration_test/support/backend_seed.dart`
- `integration_test/support/test_data.dart`
- `test/fixtures/laboratory_fixture.dart`
- `test/fixtures/payment_fixture.dart`
- `test/fixtures/tenant_fixture.dart`
- `test/fixtures/waiting_placement_fixture.dart`
- `test/helpers/test_di.dart`

### Coverage boundaries

- Golden PNGs and generated failure PNGs are binary artifacts, excluded from this source pass.
- test/COVERAGE.md is documentation assigned to the parent reviewer.
- 111 assigned files are all Dart source under test/ and integration_test/, plus the JSON path snapshot.
- Backend/runtime and physical-device acceptance remains separate from this source audit.
