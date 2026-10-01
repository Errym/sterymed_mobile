# Backend Bugs — Blocking SteryMed Mobile

**Filed by:** Mobile engineer
**Date:** 2026-09-18
**Backend version:** `steriqore` @ commit `6af6b9c` (verified live 2026-09-22 against local docker instance, port 8010)
**Staging URL:** `https://staging.example.com`

Every bug below has a `curl` reproduction and a suggested fix.

---

## BUG-001 — ✅ FIXED (backend base64 path): original multipart upload returns 500, real fix confirmed working end-to-end
**Severity:** was 🔴 Blocking
**Endpoint:** `POST /api/v1/cycles/{cycle}/attachments`
**Called by:** `CycleAttachmentsScreen`

```bash
curl -X POST "https://staging.example.com/api/v1/cycles/{cycle_id}/attachments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Idempotency-Key: test-$(date +%s)" \
  -F "file=@test.png"
```
**Expected:** 200 with `{id, url, file_name, mime_type, size, created_at}`.
**Actual:** 500 Internal Server Error.

**Root cause identified:** FrankenPHP + Octane worker mode doesn't
populate PHP's `$_FILES` reliably on real multipart uploads — the temp
file the upload references is gone by the time Symfony's `UploadedFile`
tries to read it.

**Backend-side fix found already written in the host `steriqore` repo**
(uncommitted, found 2026-09-25 while working on something else —
`DecodeBase64UploadAction.php`, `AttachCycleFileBase64Request.php`,
`CycleAttachmentController::storeBase64()` all exist and are complete):
a base64-JSON upload variant that sidesteps `$_FILES` entirely by
sending the file as a base64 string in the JSON body instead of
multipart form data. The controller method existed but had **no route**
— added `POST /v1/cycles/{cycle}/attachments-base64` →
`cycles.attachments.store-base64` (mirroring the real attachment
route's `idempotent` middleware).

**✅ Verified live, 2026-09-25:** uploaded a real 1x1 PNG (base64) to a
real cycle via `POST /cycles/{cycle}/attachments-base64` — got back a
real `{id, file_name, mime_type, size, created_at}`, confirming the
upload itself (the actual point of this bug — storing the file at all)
genuinely works. The `url` field in that response is a separate,
still-open problem — it's a `minio:9000` presigned link, unreachable
outside the Docker network (BUG-010, found via this exact test; that
entry has the full detail, including a first fix attempt that turned
out not to work).

**Still not done:** no mobile-side caller exists for this endpoint yet
(`grep` across `lib/` for `attachments-base64` / base64 upload: no
matches) — `CycleAttachmentsScreen` still only calls the original
broken multipart endpoint. Switching mobile to call the working base64
endpoint is real, scoped follow-up work, not done in this pass.

---

## BUG-002 — Missing `GET /api/v1/locations`
**Severity:** 🔴 Blocking
**Called by:** `GoodsReceiptScreen`, `StockAdjustScreen`, `StockTransferScreen`
**Current workaround:** derived from `/stock-levels` (zero-stock locations missing).
**Expected:** `[{id, name, site_id}]`

---

## BUG-003 — Missing `GET /api/v1/batches`
**Severity:** 🔴 Blocking
**Called by:** Same as BUG-002.
**Expected:** `[{id, batch_number, product_id, product_name, expiry_date}]`

---

## BUG-004 — Missing `POST /api/v1/sites` and `POST /api/v1/locations`
**Severity:** 🟡 Non-blocking
**Impact:** Mobile cannot create a site. Feature is hidden.

---

## BUG-005 — ✅ NOT A BUG: reclassified 2026-09-25 (Day 45 coherence sweep)
**Original claim:** Missing `PATCH /api/v1/patients/{id}`, worked around
with a delete+recreate (data loss) in `PatientRepository.update()`.

**What was actually wrong:** the workaround assumed patients have
editable fields (name, phone, email) that a `PATCH` would update. They
don't. `Patient` (`app/Domain/Traceability/Models/Patient.php`) is
`fillable = ['tenant_id', 'reference']` — nothing else — and
`CreatePatientAction`'s own docblock is explicit: *"there is nothing
else to capture... reference is generated here, never client-supplied,
so it can never accidentally carry real patient data typed into a
free-text field."* This is a deliberate privacy-by-design decision, not
an unfinished endpoint. There is nothing to `PATCH` because there is
nothing to edit — the reference is immutable and server-generated.

**What was mobile-side wrong, and is now fixed:** the app had a "New/Edit
Patient" form asking staff to type a real first name, last name, phone,
and email, believing it was being saved to the patient record. It
wasn't — the backend never reads those fields — but mobile then cached
that real PII **unencrypted on the device** (`PatientLocalCache`, Hive)
specifically to make the name "survive," directly working around the
backend's deliberate choice never to store it. See the full writeup
under BUG-008 below; both are the same underlying issue.

---

## BUG-006 — ~~Missing~~ RESOLVED: `PATCH /api/v1/products/{id}` exists
**Status:** ✅ Closed 2026-09-22 — verified present in the live OpenAPI spec (`http://localhost:8010/docs/api.json`) served by `steriqore` @ `6af6b9c`.
**Called by:** `ProductFormSheet`
**Note:** Mobile's `ProductRepository.update()` already calls this endpoint correctly (a real PATCH, not delete+recreate). This bug entry was stale against current backend state; no mobile change needed.

---

## BUG-007 — Missing `PATCH /api/v1/cycles/{id}`
**Severity:** 🟡 Non-blocking
**Called by:** `CycleDetailScreen` (notes cached locally only).

---

## BUG-008 — ✅ NOT A BUG: reclassified 2026-09-25 (Day 45 coherence sweep) — patients are anonymous by design, mobile treated it as a gap and worked around it with an unencrypted local PII cache
**Original claim:** `GET /api/v1/patients` returns only `{id,
reference}`; patients created elsewhere show without a name — filed as
if the backend were incomplete.

**What's actually true:** `{id, reference}` is the *entire* domain. The
`Patient` model has no name/phone/email/birth-date columns at all — see
BUG-005 above for the exact source citation. A dental practice's real
patient identity is deliberately never captured here; only an anonymous,
auto-generated pseudonym (e.g. `PAT-000042`) links a sterilization or
label-usage record back to "some patient" for recall purposes, without
this app ever holding who that is.

**The real bug, found while investigating this:** the mobile app never
noticed the design was deliberate, and built substantial infrastructure
to work around it:
- `patient_form_sheet.dart` solicited a real first name, last name,
  phone, and email on every "New/Edit Patient" action — sent to the
  server, where `CreatePatientAction` (verified: no request-validation
  class exists for this action at all) silently discards all of it.
- `PatientLocalCache` (Hive, unencrypted) then saved that same typed PII
  **on the device**, keyed by patient id, with a comment claiming
  "[fields] are stored server-side but not returned" — false; they were
  never stored server-side in the first place.
- `PatientRepository.search()` merged this local cache back into live
  API results, so search results shown to staff included real
  name/phone/email pulled from the shadow store.
- `LabelUsageDraft` (label-usage form autosave) also cached
  `patientFirstName`/`patientLastName` locally for the same wrong
  reason.

Net effect: every patient a staff member "registered" or edited on a
given phone had their real identity sitting in unencrypted local
storage on that device — outside the backend's access controls, audit
trail, and retention policy, which is exactly what the backend's design
was meant to prevent.

**Fixed (user explicitly confirmed removing the cache over encrypting
it or leaving it, given it existed specifically to defeat a deliberate
privacy control):**
- Deleted `PatientLocalCache` entirely and `patient_create_request.dart`
  (nothing left to send on create — `CreatePatientAction` takes no
  input).
- Rewrote `PatientData` to `{id, reference}`, matching the real domain.
- Rewrote `PatientRepository`: `create()` takes no arguments, `update()`
  removed outright (nothing to edit), `search()` no longer merges a
  local cache.
- Replaced the "New/Edit Patient" form with a plain confirmation dialog
  ("a new anonymous record will be created") — there's nothing to type.
- `patient_tile.dart`, `patient_search_screen.dart`,
  `patient_picker_sheet.dart` now show/search by reference only.
- Fixed `search()`'s query param too, while in this file: mobile sent a
  plain `search` param the backend never read (only
  `AllowedFilter::partial('reference')`, i.e. `filter[reference]`) —
  same class of bug as BUG-014.
- `LabelUsageDraft` now stores `patientReference` (safe — an anonymous
  pseudonym) instead of first/last name.
- Enriched `LabelUsageData` (backend) with `patient_reference` (via the
  existing `patient()` relation — safe, not PII) and `practitioner_name`
  (via the existing `practitioner()` relation — practitioners are real
  staff with real, legitimately-tracked identities, unlike patients) so
  the label-usage history screen shows something real instead of a
  permanently-blank `patient_name`/`practitioner_name` that never
  existed on the DTO.
- Also fixed `label_usage_remote_datasource.dart`'s `fetchHistory()`:
  it called `(response.data as List)` against
  `GET /labels/{id}/usage`, which actually returns a single object (a
  label is used at most once) or `404` — every real call would have
  thrown a `TypeError`, silently swallowed by a bare `catch` in
  `label_detail_bloc.dart`, so usage history has been rendering empty
  for every label regardless of real data.

`flutter analyze` — No issues found, full project. Two test files
needed updating for the new shapes
(`test/unit/repositories/label_usage_repository_test.dart`,
`test/unit/storage/label_usage_draft_store_test.dart`).

**✅ Verified live, 2026-09-25**, once the backend environment was
recovered (see git history): `POST /v1/patients` with no body → real
`{id, reference}`; `GET /v1/patients?filter[reference]=PAT` correctly
matches. Full label-usage round trip — created a cycle, item, DLU rule,
generated and printed a label, scanned it (`created → printed → used`),
recorded a usage against the new patient — confirmed the response is
exactly `{..., patient_reference: "PAT-000003", practitioner_name:
"Admin Two", ...}`, and `GET /labels/{id}/usage` (what `fetchHistory()`
now correctly parses as a single object instead of a list) returns the
same shape. Every claim in this entry is now closed the same way as
BUG-011/012/013.

---

## BUG-009 — Missing purchase-order receipt attachment endpoint
**Severity:** 🟡 Non-blocking
**Called by:** `GoodsReceiptScreen` (not yet — feature was never built
against this because the endpoint doesn't exist)
**Found:** 2026-09-24, `php artisan route:list --path=purchase-orders`
against the live `steriqore-app` container — 13 routes total, none
matching `receipts/.../attachments` or similar.
**Impact:** Master plan (Phase 8, Day 42) calls for "Photo evidence
reuses Phase 6 attachment foundation" on goods receipt — impossible
until this route exists, same class of block as BUG-001.

---

## BUG-010 — Presigned URLs (exports *and* cycle attachments) point at the internal Docker hostname, unreachable from any real client
**Severity:** 🔴 Blocking
**Called by:** `ExportRepository.downloadUrl()` → `POST /v1/data-export-requests/{id}/download`
**Found:** 2026-09-24, live curl against `steriqore-app` + `steriqore-postgres`/minio stack.
Created an export (`POST /v1/data-export-requests`), waited for it to reach
`status: completed`, then called the download action. The response is:
```
{"download_url":"http://minio:9000/steriqore-backups/data-exports/.../....zip?X-Amz-...","url_expires_at":"..."}
```
`GenerateDataExportDownloadUrlAction::execute()` calls
`Storage::disk('backups')->temporaryUrl(...)`, and the `backups` disk config
has no `url` override — `config('filesystems.disks.backups.url')` is `null`,
so the presigned URL is built from `endpoint` (`http://minio:9000`), the
Docker-internal service hostname. This is unreachable from: a real device on
the LAN, `adb reverse` (only port 8010 is forwarded), a browser on the host
outside the Docker network, and — unless MinIO is fronted by a public
URL/CDN in staging/prod — a real deployment too.
**Impact:** the mobile Export screen's "copy download link" action produces
a link the user's phone can never open. The `list`/`create`/`show` endpoints
and the mobile UI built against them (`data_export_request_screen.dart`,
rewritten 2026-09-24 to use the real `ExportRepository`) are otherwise
correct and verified live — this is purely a backend storage-disk config gap
(`filesystems.php` `backups` disk needs a `url` key pointed at a
publicly-reachable MinIO endpoint, e.g. `http://localhost:9023` in dev, same
value already correctly set on the sibling `s3` disk).

**2026-09-25 — found the exact same symptom on a second, real,
actively-used disk while verifying BUG-001's base64 attachment fix end
to end:** uploaded a real test file via
`POST /cycles/{cycle}/attachments-base64`, got back a working response,
but its `url` was again `http://minio:9000/steriqore-media/...` — the
`media` disk (cycle/label attachments) has the exact same problem as
`backups`.

**First fix attempt was wrong — corrected here rather than left
standing.** Assumed (from the `s3` disk having a `url` config key set)
that adding the same `url` override to `backups`/`media` would fix it.
Added `AWS_URL_MEDIA`/`AWS_URL_BACKUPS` env vars, wired them into
`filesystems.php`, rebuilt the image, redeployed — and the presigned
URL **still** came back as `minio:9000`. Checked why directly:
```
>>> Storage::disk('s3')->temporaryUrl('test.txt', now()->addMinutes(5))
http://minio:9000/steriqore/test.txt?X-Amz-...          # NOT localhost:9023, despite s3's url config
>>> Storage::disk('s3')->url('test.txt')
http://localhost:9023/steriqore/test.txt                # url config DOES work here
```
The `url` config key only affects `Storage::url()` (public, unsigned
links) — it has **no effect at all** on `temporaryUrl()` (presigned
links), which is what every real caller here uses, since every one of
these buckets is private. The `s3` disk was never actually "working
correctly" for presigned URLs either — the earlier BUG-010 diagnosis
compared the wrong method (`url()`) against the one that's actually
used (`temporaryUrl()`) and drew the wrong conclusion. Leaving the
`AWS_URL_MEDIA`/`AWS_URL_BACKUPS` config in place since it's still
correct for anything that does use `Storage::url()`, but it does not
close this bug.

**Real fix, not yet done:** Laravel's S3 adapter signs
`temporaryUrl()` against whatever `endpoint` the S3 client was built
with — there's no built-in "sign against A, serve from B" config knob.
The two real options are (a) a custom disk driver / adapter subclass
that generates the presigned URL normally and then rewrites the host in
the resulting string, or (b) giving MinIO a single hostname that
resolves correctly both inside the Docker network and from wherever
the client actually is (LAN device, real deployment) — which needs
infrastructure work (DNS/hosts entries or a reverse proxy), not a
Laravel config change. Neither attempted here; flagging clearly rather
than claiming a fix that doesn't hold up.

---

## BUG-011 — ✅ FIXED: No endpoint to list team members; "Équipe & Droits" screen is 100% non-functional
**Severity:** 🔴 Blocking
**Called by:** `TeamRemoteDatasource.list()` → `GET /v1/members`
**Found:** 2026-09-24, live curl against `steriqore-app` + full route audit.
```
$ curl .../api/v1/members?per_page=100 -H "Authorization: Bearer $TOKEN"
{"error":{"code":"NOT_FOUND","message":"The route api/v1/members could not be found.", ...}}

$ php artisan route:list --path=api/v1 | grep -i member
DELETE  api/v1/members/{tenantUser}   api.v1.members.destroy

$ php artisan route:list | grep -iE "tenant_user|TenantUser|membership"
DELETE  api/v1/members/{tenantUser}   api.v1.members.destroy
DELETE  team/members/{tenantUser}     team.members.disable
```
There is no `GET` route for team members anywhere in the entire route
table — mobile API or web. Only `DELETE` (revoke) and
`POST /v1/invitations` (invite) exist. `TeamMemberData` even carries
`created_at`/`last_session_at` fields, implying a real index endpoint was
planned, but it was never built.
**Impact:** `TeamListBloc.LoadTeam()` always hits this 404,
`ErrorMapper.fromDio` maps it to a failure, and `team_list_screen.dart`
(the app's entire "Équipe & Droits" nav destination) shows `ErrorView`
every single time, for every user, with no workaround — this is not a
degraded feature, it is completely dead. Inviting a new member
(`POST /v1/invitations`) still works, but there is no way to see the
resulting roster, its roles, or revoke anyone from the app afterward
(the revoke button needs a `tenantUser` id it can currently only get from
this broken list). Needs `GET /v1/members` (or equivalent) added to the
backend before this screen can work at all.

**Update, 2026-09-24 (Day 45 web/mobile coherence sweep):** confirmed
via the actual web UI (`/team`, logged in as owner) that this list
genuinely exists and works correctly there — full member table (name,
email, role, status, joined date) plus a separate invitations table.
`Web\Identity\TeamController@index`'s own docblock confirms it directly:
*"this is the first list view for either TenantUser or Invitation
anywhere (the API only ever had store/destroy, no index)"* — i.e. this
was a known, deliberate mobile-API gap, not an oversight only just now
discovered. The exact query to mirror for a `GET /v1/members` action
already exists and is proven correct:
```php
TenantUser::where('tenant_id', $tenant->id)
    ->with('user')
    ->orderBy('joined_at')
    ->get()
    ->map(fn (TenantUser $m) => TeamMemberData::fromModel($m, $m->user->getRoleNames()->first()));
```
`TeamMemberData` (`app/Domain/Identity/Data/TeamMemberData.php`) already
has the exact shape needed — `id, user_id, name, email, role, status,
joined_at, disabled_at`.

**Fixed, same session:** added `GET /v1/members` to
`app/Http/Controllers/Api/V1/Identity/MemberController.php` (new `index`
method, identical query/DTO to `TeamController@index` above, gated on
`authorize('create', Invitation::class)` — same permission as the web
controller, since there's no separate "view team" grant) and registered
the route in `routes/api.php`. Hot-patched into the running container
and verified live:
- `GET /v1/members` as owner → `200`, full member array with real
  `status`/`joined_at`/`disabled_at` fields.
- Same call as `practitioner` (no `invitations.create`) → `403`,
  correctly scoped.

**Mobile-side fixes required by this** (the Dart model was written
against assumed fields that never matched any real DTO):
- `team_member_data.dart` expected a boolean `active` field (never
  present) and `location_label`/`created_at`/`last_session_at` (never
  present either — presumably speculative, from the same fabrication
  pattern as the now-deleted `team_detail_screen.dart`). Rewritten to
  the real fields (`status` string, `joined_at`, `disabled_at`), with
  `active` kept as a derived getter (`status == 'active'`) so existing
  callers didn't need to change.
- `team_remote_datasource.dart`'s `list()` expected a paginated envelope
  (`{"data": [...], "meta": ...}`) but this endpoint returns a bare JSON
  array (Spatie `DataCollection`, not cursor-paginated) — fixed to parse
  the response directly as a list.
- `role_guard.dart`: added `Routes.team: 'invitations.create'` — this
  route was previously "always allowed" because the backend had no
  index endpoint to gate at all; now that one exists and is
  permission-scoped, the mobile router needs to match or a
  non-owner/admin role would hit a 403 instead of the tile simply not
  appearing (the dashboard's `_GovernanceMenu`, fixed earlier this
  session to filter via `RoleGuard`, picks this up automatically).
- `team_list_screen.dart`: `member.role` is now nullable (a membership
  can genuinely have no role assigned — the exact broken state
  BUG-012 caused for every failed invite before that fix), handled with
  a fallback label; also removed a decorative `chevron_right` icon that
  implied the row was tappable into a detail view when no such route
  has existed since `team_detail_screen.dart` was deleted (it was
  already non-functional before this fix, just newly noticed).

`flutter analyze` — No issues found, both on the touched files and the
full project.

---

## BUG-012 — ✅ FIXED: every invitation-accept crashed with a 500, leaving every invited user with zero role/permissions
**Severity:** 🔴 Critical — this was the actual root cause of "the practitioner role doesn't work"
**Endpoint:** `POST /api/v1/invitations/accept`
**Found + fixed:** 2026-09-24, live diagnosis against `steriqore-app`.

**Symptom that led here:** `staff2@steriqore.local` (the pilot's only
non-owner test account) logs in with `"role":null,"permissions":[]` and
gets `403` on every real endpoint (`/v1/cycles`, etc). That user was
created by hand via `tinker` (per the project's own onboarding notes) —
never through the real invite flow. Suspecting the manual insert was a
workaround for something broken, tested the real flow directly:
```
$ curl -X POST .../v1/invitations -d '{"email":"alice-test@...","role":"practitioner"}'
{"id":"...","role":"practitioner",...}            # invite created fine

$ curl -X POST .../v1/invitations/accept -d '{"token":"...","name":"Alice Test","password":"..."}'
{"error":{"code":"INTERNAL_ERROR","message":"SQLSTATE[22P02]: ...
  invalid input syntax for type uuid: \"\" ..."}}
```
Every single invitation accept — the only real product mechanism for
adding a team member with a role — crashed with a 500.

**Root cause (from `storage/logs/laravel.log`'s full stack trace):**
`AcceptInvitationAction::execute()` correctly does the write (create
user, create `tenant_user` row, `syncRoles()`) inside
`TenantContext::run($tenant, ...)`, which binds spatie/permission's team
id and the Postgres session GUC `app.tenant_id` used by
`model_has_roles`'s RLS policy (`tenant_id = current_setting('app.tenant_id', true)::uuid`).
But `AcceptInvitationController::__invoke()` then calls
`UserData::fromModel($result['user'])` **outside** that block, to build
the JSON response — by then `TenantContext::run()`'s `finally` has
already reset the team id and the transaction has closed, so the GUC is
back to empty. `UserData::fromModel()` calls `$user->getRoleNames()`,
which queries `model_has_roles`/`roles` — RLS tries to cast the now-empty
GUC to `uuid` and Postgres throws `22P02`. `UserData::fromModel()`'s own
docblock literally warns about exactly this ("callers outside a request
already scoped by the `tenant` middleware ... must wrap this call in
`TenantContext::run()`") — `LoginController` follows it correctly,
`AcceptInvitationController` didn't.

**Impact:** the write half silently succeeds (user + `tenant_user` row +
role assignment all commit) but the request still 500s, so from the
invitee's perspective invitation acceptance always fails outright. No
one could ever successfully onboard a second user through the real
product flow — every non-owner account in this dev environment had to
be hand-inserted via `tinker`, which is how `staff2` ended up with no
role at all.

**Fix applied** (`app/Http/Controllers/Api/V1/Identity/AcceptInvitationController.php`,
same repo as this backend, host path
`C:\Users\mery\steriqore\...`): wrap the `UserData::fromModel()` call in
`TenantContext::run($result['tenant'], fn () => ...)`, identical to the
pattern `LoginController` already uses for the same reason. Hot-patched
into the running `steriqore-app` container (`docker cp` +
`php artisan octane:reload` — this app runs under Octane/FrankenPHP,
which keeps the app booted in memory, so a plain file edit does nothing
until the workers reload) and verified live: a fresh invite→accept now
returns `200` with a real token and `"role":"practitioner"` plus a real
permission list; that new user then correctly gets `200` on
`/v1/cycles` and `403` on `/v1/audit-events` (permission-scoped exactly
as expected, not over- or under-permissive). Also repaired the existing
`staff2@steriqore.local` account by assigning it the `practitioner` role
directly (same effect the fixed flow would have produced), and disabled
(not deleted — `audit_events` is append-only, blocks any hard delete
that would null out `actor_id`, which is correct compliance behavior)
three throwaway accounts created while diagnosing this
(`alice-test`/`bob-test`/`carol-test@steriqore.local`).

**Not yet done:** the host-repo fix needs a real deploy (image rebuild)
to persist past this container's lifetime — the hot-patch only lives in
the currently-running container. **Also not covered:** role-aware
mobile navigation (the mobile app currently shows all nav destinations
to every role regardless of permissions, per the master plan's known
Phase-2 gap) — this bug fix makes the *backend* correctly enforce and
return roles/permissions; hiding nav items the current role can't use is
separate mobile-side work, not yet done.

---

## BUG-013 — ✅ FIXED: `GET /stock-levels` returned only 4 bare fields; the whole Stock screen was silently rendering blank/zero data
**Severity:** 🔴 Critical — core Phase 8 Day 41 feature
**Endpoint:** `GET /api/v1/stock-levels`
**Found + fixed:** 2026-09-25, Day 45 coherence sweep.

`app/Domain/Inventory/Data/StockLevelData.php` only ever declared
`id, batch_id, location_id, quantity` — confirmed by reading the source
directly (Spatie Data serializes exactly its declared constructor
properties, nothing more). The mobile `stock_level_data.dart` model
expects `product_name, product_reference, product_unit, min_threshold,
location_name, batch_number, expiry_date`, none of which the real DTO
ever returned, plus it read `qty` where the real field is `quantity`.
Every one of those missing fields falls back to an empty
string/`0`/`null` in the Dart model's null-safe parsing, so this never
crashed — it silently rendered blank product names, "0" quantities,
`isLow`/`isExpired`/`isNearExpiry` always false, on every single row,
with no error to notice. This had gone undetected including through an
earlier "Gate 8 partial audit" this session, which verified the stock
*write* actions (issue/adjust/transfer) but never actually inspected the
*list* screen's real rendered data.

**Fixed:** enriched `StockLevelData` to include the full set above,
sourced via `$level->batch->product` / `$level->location` (both
relations already existed — `StockLevel belongsTo Batch`,
`Batch belongsTo Product`, `StockLevel belongsTo StorageLocation`), and
added `->with(['batch.product', 'location'])` eager-loading to
`StockLevelController@index` to avoid N+1s. Also added the `search`
query param support the mobile client had been sending all along but
the backend silently ignored (matches product name/reference via
`whereHas` + `ilike`).

**Verified live, full round trip:** created a real supplier → purchase
order → ordered it → received goods (real `ReceiveGoodsAction`, not a
shortcut) to generate a genuine batch + stock level, since `demo2` had
zero stock data to inspect beforehand. Confirmed the enriched response:
```json
{"id":"...","batch_id":"...","batch_number":"SWEEP-001","expiry_date":"2027-06-30",
 "product_id":"...","product_name":"produit 1","product_reference":"1244hh",
 "product_unit":"5","min_threshold":5,"location_id":"...",
 "location_name":"Armoire Sterile A","quantity":10}
```
and confirmed `search=produit` matches, `search=nonexistentxyz` returns
empty. Updated `stock_level_data.dart` to read the correct field names
(`product_reference`→`reference`, `product_unit`→`unit`,
`quantity`→`qty`). `flutter analyze` — No issues found.

---

## BUG-014 — ✅ FIXED (mobile-side): every list screen sent `per_page`, but every real endpoint only ever reads `limit`
**Severity:** 🟡 Non-blocking today, would silently truncate lists in production
**Found + fixed:** 2026-09-25, Day 45 coherence sweep.

Every API controller with pagination reads
`$request->integer('limit', 20)` — confirmed by grepping all of
`app/Http/Controllers/Api/V1/` (13 occurrences of `->integer('limit'`,
zero of `per_page`). 15 mobile datasource files were sending
`per_page` instead, which every controller silently ignores (unknown
query params aren't rejected), so every one of these lists has been
silently capped at the backend's default page size regardless of what
the client asked for:
`audit_remote_datasource.dart`, `supplier_remote_datasource.dart`,
`purchase_remote_datasource.dart`, `cycle_remote_datasource.dart`,
`alert_remote_datasource.dart`, `stock_remote_datasource.dart`,
`device_program_remote_datasource.dart`, `patient_remote_datasource.dart`,
`device_detail_datasource.dart`, `device_remote_datasource.dart`,
`site_remote_datasource.dart`, `product_remote_datasource.dart`,
`non_conformity_remote_datasource.dart`, `export_remote_datasource.dart`,
`dashboard_remote_datasource.dart`.

**Proven live** (not just from source): `GET /audit-events?per_page=30`
returned 20 results (the silent default); `GET
/audit-events?limit=30` returned exactly 30, against the same live
data (128 real audit events in `demo2`). This tenant's other lists are
all currently well under 20 rows, so this hasn't visibly manifested
elsewhere yet — but it would as soon as any list grows past the
default page size in real use, and cursor-paginated screens using
"load more" would just need more round-trips than intended rather than
silently lose data.

**Fixed:** renamed `per_page` → `limit` in every affected file, pure
key rename, no logic change. `flutter analyze` — No issues found, full
project.

---

## BUG-015 — ✅ FIXED: `non_conformity_data.dart` invented an entire domain shape that never existed on the backend
**Severity:** 🔴 Critical — near-total field mismatch
**Found + fixed:** 2026-09-25, Day 45 coherence sweep continued.

The real `NonConformity` domain (`app/Domain/Compliance/Data/
NonConformityData.php`) is: `id, subject_type, subject_id, description,
raised_by_user_id, raised_at, resolved_by_user_id, resolved_at,
resolution` — raised against a Cycle or a Label, free-text description,
resolved or not. Mobile's `non_conformity_data.dart` expected `reference,
kind ('recall'/'quarantine'/'correction'), status ('open'/...), title,
cycle_number, batch_number, sachets_affected, opened_by, opened_at` —
almost none of which exist; there is no "kind" classification, no
title, no per-item reference, no sachet count anywhere in the real
domain. Worse, `isOpen` was derived from a `status` field that always
defaulted to the literal string `'open'` when absent (which was always,
since the field never existed) — meaning a **resolved** non-conformity
would still display as "En cours" on mobile, permanently, regardless of
its real state.

The create flow (`nc_create_sheet.dart` /
`non_conformity_remote_datasource.dart`'s `create()`) was already
correct — it sends exactly `subject_type/subject_id/description`,
matching `RaiseNonConformityRequest`. The mismatch was confined to
parsing the response and rendering the list.

**Fixed:** rewrote `non_conformity_data.dart` to the real 9 fields (plus
two enrichments — see below), `isOpen` now derived from `resolvedAt ==
null`. Rewrote `_NcCard` in `non_conformities_screen.dart`: subject-type
badge (Cycle/Étiquette, from the real `subject_type`) instead of the
fabricated kind badge, description instead of the fabricated title, a
real raised-by/raised-at line, resolution line now includes who
resolved it.

Also enriched the backend DTO with `raised_by_name`/`resolved_by_name`
(mirrors `AlertData`'s existing `resolved_by_name` pattern exactly —
`NonConformity` already had `raisedBy()`/`resolvedBy()` `belongsTo`
relations, just never eager-loaded or exposed) so the mobile UI can show
who raised/resolved an item, not just an opaque user id.

**Verified live, full round trip:** raised a non-conformity against a
real cycle, confirmed `raised_by_name: "Admin Two"` in the response,
resolved it, confirmed `resolved_by_name`/`resolved_at`/`resolution` all
populate correctly.

`flutter analyze` — No issues found, full project.

---

## BUG-016 — ✅ FIXED: Alerts screen never actually filtered by resolved state; Dashboard had three separate raw-field mismatches
**Severity:** 🔴 Critical (alerts) / 🟡 (dashboard preview fields)
**Found + fixed:** 2026-09-25, Day 45 coherence sweep continued.

**Alerts:** `AlertController@index` only supports `filter[state]`
(`open`/`resolved`, an `AllowedFilter::exact`) — mobile was sending a
plain top-level `resolved: false`, silently ignored, so the "active
alerts" screen was actually fetching and displaying **every alert ever
raised, resolved or not**, with no visual distinction (mobile's
`resolved` field also read a nonexistent JSON key and was always
`false`). Also missing from the Dart model: `state`, `subject_type`,
`resolved_by_name` (a real field already returned, just never parsed —
no backend change needed here, unlike BUG-015). `subjectLabel` was pure
invention (no `subject_label` field has ever existed) — removed;
turned out to be redundant anyway, since the real `message` field
already embeds the human-readable subject
(`Stock for "produit 1" is below threshold (2/5).` — this message is in
English, not French like the rest of the app; a backend content/i18n
gap noted but not fixed here, since mobile has no structured fields to
rebuild a French sentence from).

**Verified live:** triggered a real low-stock alert (issued stock below
threshold), confirmed `filter[state]=open` returns it and
`filter[state]=resolved` doesn't; resolved it; confirmed the reverse.

**Dashboard, found while fixing the same alerts query used by
`dashboard_remote_datasource.dart`:**
1. Same `resolved: false` issue — the "Alertes actives" KPI count and
   the "Nécessite votre attention" preview were including resolved
   alerts.
2. `todayCycles` filtered on `c['created_at']`, a field that has never
   existed on `CycleData` at all (only `started_at`/`completed_at`) —
   meaning the "Cycles du jour" section and KPI count were **always
   zero**, on every day, regardless of real activity. Fixed to use
   `started_at`, the closest real proxy for "something happened today."
3. The same section read `c['number']` (real field: `cycle_number`) and
   `c['device_name']` (doesn't exist on the raw `/v1/cycles` response at
   all — only `device_id`) — both always blank. Fixed the field name and
   added a parallel `GET /v1/devices` fetch to build a real id→name map,
   mirroring the enrichment pattern `CycleRepository` already uses for
   the main Cycles screen.

`flutter analyze` — No issues found, full project. One test fixture
(`test/fixtures/alert_fixture.dart`) needed updating for the model's new
required fields; `flutter test test/widget/alert_list_screen_test.dart`
re-run green after.

---

## BUG-017 — ✅ FIXED (mobile-side): Team screen listed 4 roles, one of them fictional, missing 3 of the real 6
**Severity:** 🔴 — a real, backend-confirmed role (`admin`, `releaser`,
`viewer`) had no way to be filtered/labeled correctly in the app that's
supposed to manage them
**Found + fixed:** 2026-09-25.

`app/Domain/Identity/Enums/TenantRole.php` — the real, backend-enforced
set — is exactly six values: `owner, admin, stock_manager, releaser,
practitioner, viewer`. `team_list_screen.dart`'s role filter chips and
badge-tone switch instead had: `owner, practitioner, stock_manager,
reception` — `reception` doesn't exist anywhere in the backend (a
leftover from the fictional "4-role" planning doc flagged and
explicitly discarded earlier this session — see
`[[prosthetic_module_recurs]]`-style memory of doc contamination), and
`admin`/`releaser`/`viewer` were simply missing. The team member badge
also rendered the raw role string uppercased (`STOCK_MANAGER`) instead
of a real label.

`team_invite_sheet.dart`'s role dropdown was missing `owner` — checked
`CreateInvitationRequest`/`CreateInvitationAction`/`InvitationPolicy`
directly: there is no restriction anywhere against inviting a second
owner, only the same `invitations.create` permission gate as any other
role. Added it, with a one-line warning shown only when selected
("full, unrestricted access") since it's a meaningfully more sensitive
choice than the other five, even though the backend doesn't itself gate
it specially.

**Fixed:** added `lib/features/identity/data/models/tenant_role.dart` —
a single `kTenantRoles` list (value + French label) as the one source of
truth, plus `tenantRoleLabel()`/`tenantRoleTone()` helpers. Used it in
`team_list_screen.dart` (filter chips, badge label/tone — deleted the
duplicated, incomplete switch statements), `team_invite_sheet.dart`
(dropdown options), and `settings_screen.dart` (the current user's own
account badge, which previously collapsed all five non-owner/admin
roles into a generic "Personnel" — now shows the real specific role).

`flutter analyze` — No issues found on `lib/features/identity`,
`lib/features/settings`, `lib/features/dashboard`, and the full project.

**Verification status:** ✅ all six roles now live-verified via real
invite→accept round trips (owner/practitioner/stock_manager earlier
during the BUG-012 fix; admin/releaser/viewer completed once the
backend environment was recovered — see git history). Each role's
`permissions` array is distinct and matches what its name implies (e.g.
`viewer` has zero `.manage` permissions anywhere; `releaser` has
`cycles.release` + `non_conformities.manage` but no inventory/purchasing
management). `RoleGuard`/`_GovernanceMenu` needed no further mobile
changes for the three newly-verified roles since they were already
built against real permissions, not role names.

---

## BUG-018 — ✅ FIXED (mobile-side): the Scanner — a bottom-nav tab, the app's core clinical action — was completely non-functional
**Severity:** 🔴 Critical — arguably the most severe finding of the
entire coherence sweep
**Found + fixed:** 2026-09-25, continuing the DTO-diff into Labeling.

`GET /v1/labels/{code}` (the actual scan endpoint,
`LabelScanController::show` → `LabelScanResultData`) returns a **flat**
object: `{label_id, status, cycle_number, device_name, sterilized_at,
use_by_date, sequence_in_cycle, site_name}`. Mobile's
`LabelScanResult.fromJson()` instead expected a **wrapper**:
`{code, status, reason, label: {...nested object...}}` — a shape that
has never existed on this backend. Concretely:
- `json['label']` was always absent → `result.label` was **always
  `null`**.
- `json['code']`/`json['reason']` were always absent → always empty.
- `LabelScanStatus` only recognized `'valid'`/`'expired'`/`'recalled'`
  — the real enum (`App\Domain\Labeling\Enums\LabelStatus`) is
  `created, printed, used, expired, recalled, voided`; every one of the
  *common* real values (`created`/`printed`/`used`) fell through to
  `unknown`.

**Real-world impact, traced end to end:**
- `label_detail_screen.dart`'s info card (`if (result.label != null)`)
  **never rendered** — every scan showed only a status header (usually
  wrong, since `used` mapped to `unknown`) and an empty usage-history
  section.
- The "Enregistrer utilisation" button's guard
  (`result.label == null || result.isBlocked ? null : ...`) was
  **always disabled** — `result.label` being permanently null meant a
  practitioner could **never record a usage from the scan flow**, the
  single most important clinical action this app exists to support.
- `label_usage_form_screen.dart`'s header showed a generic "Étiquette"
  title and the raw label id, never `widget.label?.productName`
  (itself fabricated — no such field exists on labels at all) or
  `widget.label!.code`/`batchNumber` (also fabricated).
- `scanner_screen.dart`'s post-scan routing
  (`if (r.isBlocked) { go(labelsBlocked) } else if (r.label != null) {
  go(labelsDetail) }`) meant `Routes.labelsDetail` was **also never
  reached** (same null-label guard), and `Routes.labelsBlocked` — a
  fully-built, well-designed dedicated screen — was **completely
  unreachable**, because `ResolveLabelScanAction` (verified by reading
  it directly) never returns a successful DTO for a
  recalled/expired/voided label — it always throws a 410
  `ApiException` first. Every blocked scan just showed a small
  transient snackbar with the raw (English) backend error message,
  then silently reset.
- `nc_create_sheet.dart` (raising a non-conformity against a scanned
  label) had the identical `result.label == null` guard, meaning
  **raising a non-conformity against a label has also always failed**,
  showing "Étiquette introuvable pour ce code" even for a label that
  genuinely exists.

**Fixed:** rewrote `label_scan_result.dart` as a single flat model
matching the real DTO exactly (deleted the now-redundant
`label_data.dart`, which was never a real shape either — its own
`code`/`productName`/`batchNumber`/`expiresAt` fields don't exist
anywhere in the label domain). Added `canRecordUsage => status ==
LabelScanStatus.used` as the real gate (matches
`RecordLabelUsageAction`'s actual requirement, backend error code
`LABEL_NOT_SCANNED` otherwise — confirmed live). Propagated the real
error `code` (not just `message`) through `LabelDetailState` and
`ScannerState` (both previously discarded it) so:
- `LabelBlockedScreen` now classifies by the real error code
  (`LABEL_EXPIRED`/`LABEL_RECALLED`/`LABEL_VOIDED`) instead of a status
  field that can never arrive there.
- `scanner_screen.dart` now actually navigates to
  `Routes.labelsBlocked` for those three codes, and to
  `Routes.labelsDetail` on any real success — both previously
  unreachable.
- `nc_create_sheet.dart` now uses `result.labelId` directly and
  surfaces the real lookup failure.

**Also fixed in passing:** `ScannerState.copyWith(error: null, ...)`
never actually cleared the field — same `?? this.field` nullable-clear
bug pattern found elsewhere this session (`AuditListState`'s action
filter, earlier today) — added explicit `clearError`/`clearErrorCode`
flags.

**Verified live:** confirmed the real `GET /v1/labels/{id}` response
shape matches the new model field-for-field using an already-used
label from earlier verification. Set that same label's status to
`Recalled` directly (tinker) and confirmed the endpoint throws exactly
`{"code":"LABEL_RECALLED",...}` with HTTP 410 — precisely what the
fixed routing logic checks for — then restored it to `Used`.

`flutter analyze` — No issues found, full project. Two real test files
needed rewriting, not just recompiling: `test/bloc/scanner_bloc_test.dart`
had a test literally titled "emits \[resolving, resolved\] **with
blocked status** for expired label" — asserting behavior that can never
happen on the real backend (an expired label resolving successfully).
Rewritten to assert the real behavior (an `error` state with
`errorCode: 'LABEL_EXPIRED'`). `test/widget/label_detail_screen_test.dart`
similarly asserted on the fabricated `productName` field; rewritten to
check a real one (`deviceName`).

---

## BUG-019 — ✅ FIXED (mobile-side): `DluRuleData` was missing 4 of 8 real fields
**Severity:** 🟢 Low — the screen is explicitly read-only, no user
action depended on the missing fields
**Found + fixed:** 2026-09-25.

Real `DluRuleData`: `id, packaging_type, storage_condition,
shelf_life_days, last_updated_at, last_updated_by, last_reason,
existing_labels_count`. Mobile read a nonexistent `reason` field
(real name: `last_reason`, never displayed anyway) and never parsed
`last_updated_at`/`last_updated_by`/`existing_labels_count` at all.
Enriched the Dart model and added a revision-history line ("Modifiée
le ... par ...") and an "N étiquette(s) utilisent cette règle" line to
`dlu_rules_screen.dart` — real governance information (who changed a
compliance rule, when, why, and how many labels are already affected)
that existed on the backend the whole time but was never surfaced.

---

## BUG-020 — ✅ FIXED (mobile-side): `StockMovementData` read `kind`/`created_at`, real fields are `type`/`occurred_at`
**Severity:** 🟢 Low — the model's result is only used as a
success-indicator after issue/adjust/transfer; `kind`/`createdAt` are
never read or displayed anywhere in the UI (confirmed: no screen file
references `StockMovementData`, only blocs holding it as a return
type)
**Found + fixed:** 2026-09-25, closing out the coherence sweep.

Fixed the field names for correctness even though there's no current
display impact, consistent with every other model fixed this session.
Verified live: `POST /v1/stock-movements/adjust` →
`{"type":"adjustment",...,"occurred_at":"..."}`.

---

## BUG-021 — ✅ FIXED, live-verified: `POST /v1/tenants` (new practice signup) was 100% broken

**Severity:** 🔴 Critical — this is the very first action a new clinic
takes. Confirmed deterministic, not intermittent: reproduced 3/3 times
against the live `steriqore-app` container.

**Found:** 2026-09-26, verifying production-readiness during the mobile
role/permission audit — not a mobile-side issue, found by curling the
backend directly while checking a separate finding (BUG-022).

**Repro:**
```
curl -X POST http://localhost:8010/api/v1/tenants -H "Content-Type: application/json" -H "Accept: application/json" -H "Idempotency-Key: <uuid>" \
  -d '{"tenant_name":"X","tenant_slug":"x-123","owner_name":"Y","owner_email":"y@z.local","password":"...","password_confirmation":"..."}'
→ {"error":{"code":"INTERNAL_ERROR","message":"SQLSTATE[22P02]: Invalid text representation: 7 ERROR:  invalid input syntax for type uuid: \"\" ..."}}
```

**Root cause, confirmed by direct source comparison:**
`RegisterTenantController::__invoke` (`app/Http/Controllers/Api/V1/Identity/RegisterTenantController.php`)
calls `UserData::fromModel($result['user'])` **outside** any
`TenantContext::run()` wrapper. `UserData::fromModel()` calls
`$user->getRoleNames()`/`getAllPermissions()`, which query
`model_has_roles` scoped by spatie/permission's "team id" — by the time
control returns from `RegisterTenantAction::execute()`, its own internal
`TenantContext::run()` has already exited its `finally` block and reset
the team id to `null`/`''`, so the role-loading query filters on an
empty string instead of a UUID and Postgres rejects it outright.

`LoginController::__invoke` (same directory) does this correctly —
`TenantContext::run($result['tenant'], fn () => UserData::fromModel($result['user']))`
— and doesn't crash. The registration controller just never got the same
treatment.

**Fix applied** (backend repo, `C:\Users\mery\steriqore`,
`RegisterTenantController.php`), mirroring `LoginController`'s existing
correct pattern exactly:
```php
$userData = TenantContext::run(
    $result['tenant'],
    fn () => UserData::fromModel($result['user']),
);
return response()->json([
    'token' => $result['plain_text_token'],
    'token_type' => 'Bearer',
    'user' => $userData,
    'tenant' => TenantData::fromModel($result['tenant']),
], 201);
```
Rebuilt the `steriqore-app` image (`docker compose build app` +
`up -d --no-deps app`) and re-ran the exact repro curl 3/3 — all three
now return `201` with the full correct `permissions` array populated
immediately (`owner`, all permissions present). Also confirmed a fresh
registration's token works immediately against `GET /v1/sites` and
`GET /v1/members` with no cache reset needed — see BUG-022.

**Mobile-side impact:** `register_screen.dart` calls this endpoint
directly — every real signup attempt from the app was failing with a raw
500 until this fix. Now confirmed working end-to-end.

---

## BUG-022 — ✅ CLOSED (not a reproducible bug): one test account's stale spatie/permission cache, not a systemic issue

**Severity:** downgraded from an initial 🔴 High after further testing —
see below. Kept as a log entry because the investigation and the
distinction it landed on are worth keeping, not because there's an open
action item.

**Found:** 2026-09-26, verifying an owner test account
(`admin2@steriqore.local`, tenant `demo2`) that showed full permissions
in its own `/v1/auth/login` and `/v1/me` responses, yet got `HTTP_403` on
`GET /v1/sites`, `GET /v1/audit-events`, and `GET /v1/members` — three
endpoints that account's own permission list clearly includes.
`docker exec steriqore-app php artisan permission:cache-reset`
immediately made all three succeed with the exact same token, no other
change — confirming the *symptom* was a stale spatie/permission cache
entry for that specific tenant/role, not a real authorization gap.

**Corrected conclusion, after the BUG-021 fix let this be tested
properly:** registered a brand-new tenant through the real
`POST /v1/tenants` flow (the exact same code path every real signup
uses) and immediately hit `GET /v1/sites` and `GET /v1/members` with the
fresh token, **no cache reset in between** — both succeeded on the first
try. Spatie's documented "cache is flushed automatically when
permissions or roles are updated" behavior works correctly for the
normal registration/role-assignment path. The `demo2` tenant's stale
cache almost certainly came from this session's own extensive ad-hoc
`php artisan tinker` manipulation of that account earlier today (creating
and disabling test accounts, resetting a password directly, rebuilding
the container mid-session) — plausible ways to mutate a role/permission
row without going through the Eloquent model events Spatie's
auto-flush relies on. That's a hazard of hands-on backend testing, not a
defect in the application's normal request lifecycle.

**Action taken:** ran `permission:cache-reset` once to clear whatever
stale state existed in this dev environment. No code change made — a
code change would have been solving a problem that further testing
showed doesn't reproduce through real usage, which is worse than no fix
at all.

---

## BUG-023 — ✅ NOT A BUG: the prosthetic brief's "First name / Last name"
patient fields do not exist on the backend — by design, not a gap

**Severity:** 🟢 Informational — flagged before any mobile code was
written, so nothing shipped against the wrong assumption this time.

**Found:** 2026-09-26, Task 1.1 (prosthetic case create screen). The
brief `SteryMed_Prosthetic_Workflow_Implementation_Brief_EN-compressed.pdf`,
page 6 ("Create a prosthetic case"), lists under **Patient**: First name,
Last name, Patient ID / link to patient profile.

**Checked against the live backend before writing anything:**
`app/Http/Requests/Api/V1/Prosthetic/CreateProstheticCaseRequest.php`
accepts `patient_id` (a foreign key into `patients`) and nothing else
patient-shaped — no `first_name`, no `last_name`, anywhere in the
request, the `ProstheticCase` model's `$fillable`, or the `Patient`
model it references.

**This is by design, not a gap.** `Patient` is `fillable = ['tenant_id',
'reference']` only — confirmed independently in this same repo's own
history (BUG-005, BUG-008): `CreatePatientAction`'s docblock states
*"there is nothing else to capture... reference is generated here,
never client-supplied, so it can never accidentally carry real patient
data typed into a free-text field."* The mobile model that already
encodes this — `lib/features/patients/data/models/patient_data.dart` —
carries the same statement in its own class doc: *"Patients carry no
PII by design... See docs/BACKEND_BUGS.md#bug-008."*

**Why this got flagged instead of implemented:** BUG-008 is the exact
failure mode a literal reading of page 6 would repeat — a previous
session built a first/last-name "New/Edit Patient" form the backend
silently discarded, then cached that real PII **unencrypted on the
device** to make the name appear to persist, directly working around
this deliberate privacy control. `prosthetic_case_create_screen.dart`
already uses the correct, reference-only patient picker (matching
`CreateProstheticCaseRequest` exactly), and was left unchanged rather
than regressed to add fields with nowhere real to submit them.

**Resolution:** none needed on mobile — the existing implementation is
already correct. If the product intent is for a prosthetic case to
carry a real patient name (a lab box arguably needs one, unlike
sterilization traceability, which stays pseudonymous by design), that
is a backend schema decision — new columns on `ProstheticCase` itself,
separate from the anonymous `Patient` domain — not a mobile-side fix.
Flagging here rather than guessing.

---

## BUG-024 — Missing: no print/export endpoint for a prosthetic case

**Severity:** 🟡 Non-blocking — genuinely missing, not "by design" (unlike
BUG-023 above).

**Found:** 2026-09-26, Task 1.2 (prosthetic case detail screen). The brief
(page 7, "The page must include") lists **Quick Edit and Print / Export
actions** as one bullet. `Quick Edit` is real and backend-supported
(`PATCH /v1/prosthetic-cases/{id}`, wired this task via
`ProstheticCaseEditSheet`). Print/Export is not — confirmed via
`php artisan route:list --path=prosthetic` against the live
`steriqore-app` container: 11 routes total, none matching
`print`/`export`/`pdf`/similar. The brief's own "Suggested API surface"
(page 13) doesn't list one either.

**Impact:** no mobile action was built for this — there is nothing to
call. Building a "Print/Export" button now would be UI with no real
capability behind it, the same category of mistake as BUG-008.

**Needed from backend before mobile can implement this:** an endpoint
(e.g. `GET /v1/prosthetic-cases/{id}/pdf` or similar) that renders the
case — patient reference, practitioner, clinical/lab dates, payment
block, notes — as a document reception can print or hand to a courier
for the lab. Flagging here rather than guessing at a shape.

---

## BUG-025 — `ApiEndpoints.site(id)` points at a route that does not exist

**Severity:** 🟢 Dead code, not a live bug — zero call sites in `lib/`
today (grepped before writing this), so nothing currently 404s. Caught by
the new `test/unit/contract/api_endpoints_test.dart` (Task 3.4), which
compares every `ApiEndpoints` path against a snapshot of the live,
auto-generated API spec.

**Found:** 2026-09-26, Task 3.4 (API contract test). `lib/core/config/api_endpoints.dart`
defines `static String site(String id) => '$_v1/sites/$id';`, but the real
backend only exposes the collection route. Confirmed directly against the
route table, not just the doc-generated spec:

```
$ docker exec steriqore-app php artisan route:list --path=v1/sites
GET|HEAD   api/v1/sites  api.v1.sites.index › Api\V1\SitesController@index
                                                    Showing [1] routes
```

No `show`/`update`/`destroy` route for a single site exists at all — only
`index`. The live `GET /docs/api.json` spec agrees (78 paths total, only
bare `/v1/sites`, no `/v1/sites/{site}`).

**Impact today:** none — nothing in `lib/` calls `ApiEndpoints.site(...)`.
If a future screen ever does, it will get a 404/405 from the real backend
every time.

**Not silently worked around:** left the helper in place rather than
quietly deleting or "fixing" it to guess at an intended shape (single-site
fetch? filtered list?) — that's a backend/product decision. The contract
test asserts this mapping is currently broken as a deliberate tripwire
(`expect(existsLive(ApiEndpoints.site('X')), isFalse, ...)`), so either
adding the real backend route, removing the dead helper, or adding a call
site forces an intentional update to both the test and this entry instead
of the drift going unnoticed.

| ID | Severity | Endpoint |
|----|----------|----------|
| BUG-001 | ✅ Fixed (base64 endpoint), mobile caller not yet built | POST /cycles/{id}/attachments-base64 — verified live end-to-end |
| BUG-002 | 🔴 | GET /locations |
| BUG-003 | 🔴 | GET /batches |
| BUG-004 | 🟡 | POST /sites, /locations |
| BUG-005 | ✅ Not a bug (reclassified) | Patients have no editable fields by design — see BUG-008 |
| BUG-006 | ✅ Closed | PATCH /products/{id} (confirmed present) |
| BUG-007 | 🟡 | PATCH /cycles/{id} |
| BUG-008 | ✅ Fixed, live-verified | Patients are anonymous by design; removed the local PII cache that worked around it |
| BUG-009 | 🟡 | POST /purchase-orders/{id}/receipts/attachments (missing) |
| BUG-010 | 🔴 | Presigned URLs (`backups` + `media` disks) use internal `minio:9000` host — first fix attempt (`url` config) confirmed *not* to work for `temporaryUrl()`, real fix needs adapter/infra work |
| BUG-011 | ✅ Fixed | GET /members (was missing entirely — Team screen 100% broken) |
| BUG-012 | ✅ Fixed | POST /invitations/accept (500 — role never usable) |
| BUG-013 | ✅ Fixed | GET /stock-levels (was missing product/batch/location enrichment) |
| BUG-014 | ✅ Fixed | 15 mobile files sent `per_page`, backend only reads `limit` |
| BUG-015 | ✅ Fixed | GET /non-conformities (mobile model invented a whole fake domain shape) |
| BUG-016 | ✅ Fixed | GET /alerts (never filtered by state) + Dashboard (3 raw-field mismatches) |
| BUG-017 | ✅ Fixed | Team screen had a fake `reception` role, missing `admin`/`releaser`/`viewer` |
| BUG-018 | ✅ Fixed | Scanner completely non-functional — label detail, usage recording, and the blocked-label screen were all unreachable |
| BUG-019 | ✅ Fixed | DluRuleData missing 4 of 8 real fields (revision history, label count) |
| BUG-020 | ✅ Fixed | StockMovementData read `kind`/`created_at`, real fields are `type`/`occurred_at` |
| BUG-021 | ✅ Fixed, live-verified | POST /tenants (new practice signup) — was a deterministic 500, `RegisterTenantController` now wraps `UserData::fromModel` in `TenantContext::run()` |
| BUG-022 | ✅ Closed, not a bug | One test account's stale permission cache — confirmed the normal registration/role-assignment flow doesn't reproduce it |
| BUG-023 | ✅ Not a bug | Prosthetic brief's First/Last name patient fields don't exist — patients are anonymous by design (see BUG-008); mobile left unchanged |
| BUG-024 | 🟡 Missing | GET /prosthetic-cases/{id}/print or similar — no print/export endpoint exists; mobile has nothing to call |
| BUG-025 | 🟢 Dead code, caught by contract test | ApiEndpoints.site(id) → /v1/sites/{id} has no matching backend route; zero call sites today |
