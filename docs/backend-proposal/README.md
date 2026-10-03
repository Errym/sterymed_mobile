# Backend proposals from the mobile work — NOT APPLIED

**Status (3 October 2026): none of this is in the backend.** The web/backend
engineer owns that code and asked that it not be touched. These changes were
first made in the working tree, then **fully reverted** (files removed, edits
reversed, migration rolled back, dev container restored, backend tests green at
their original count). What is left is this proposal, for the backend owner to
accept, adapt or refuse.

* `new-files.zip` — the complete new files (push registry, digest job, FCM
  sender, migration, tests), unchanged from when they passed.
* `verify_export_files.py` — live proof for the export fix (needs it applied).
* The small edits to existing files are described below, hunk by hunk.

Only items 3 and 4 correspond to a written requirement being broken by the
existing code (Cahier §8, "aucune suppression silencieuse d'une preuve"; cycle
traceability). Push (2) is required by the Cahier's mobile stack but needs a
backend sender. 1 and 5 are operational suggestions, not requirements.

The text below keeps its original past-tense wording for the record.

# (original description)

Repository: `steriqore` (branch `mvp/steriqore-web`).
Dates: 3 October 2026. Every change below has a test or a live proof; the
evidence is named in each section.

The backend working tree also holds earlier work that is not described here
(prosthetic module, inventory counts, invitations, idempotency, …). This file
lists only what was changed in this work, so it can be reviewed and committed
as separate checkpoints.

## Summary

| # | Change | Why | Files | Proof |
|---|---|---|---|---|
| 1 | Separate login rate limiter | A whole clinic sharing one IP was locked out after 10 sign-ins/minute | `AppServiceProvider`, `routes/api.php`, `RateLimitTest` | 2 tests; 290 API tests |
| 2 | Push notifications | Cahier §7 lists notifications for mobile; nothing existed | 14 new files + 4 edited (section 2) | 13 tests; live chain on the dev stack |
| 3 | Data export keeps every file | Same-named attachments overwrote each other in the archive | `GenerateDataExportJob`, `DataExportRequestTest` | 2 tests; `verify_export_files.py` live |
| 4 | Cycle refuses an inactive program | A switched-off program could still start a cycle | `CreateCycleRequest`, `CycleCreationRulesTest` | 1 test |
| 5 | Public sign-up switch | Anyone could create a practice on a pilot server | `config/registration.php`, `RegisterTenantController`, env templates | 1 test |
| 6 | Contract, env and tooling | OpenAPI regenerated; env templates; ignores | `docs/openapi.yaml`, `.env*.example`, `docker-compose.yml`, `.gitignore` | `OpenApiContractTest` |

Full API suite after all changes: **290 passed** (`tests/Feature/Api`, isolated runner).
The web/UI tests in this runner fail for known reasons unrelated to these
changes (no Vite build; a few RLS tests need grants only the CI database has).

## 1. Login rate limiter

**Problem.** `auth/login`, `tenants`, `auth/forgot-password` and
`invitations/accept` shared one bucket: 10 requests per minute **per IP**. Staff
behind the same reception Wi-Fi or carrier NAT locked each other out at opening
time.

**Change.**
- `AppServiceProvider::configureRateLimiting()` adds the `auth-login` limiter:
  10/min per **account + IP** (password guessing stays blocked) and 120/min per
  IP (flood ceiling).
- `routes/api.php`: `auth/login` moved out of the `public-api` group and now uses
  `throttle:auth-login` + `idempotent`. The other three keep the strict
  `public-api` limit.
- `tests/Feature/Api/V1/RateLimitTest.php`: the existing test renamed to "blocks
  guessing one account"; new test "colleagues behind one public IP can all sign
  in" (20 different accounts pass, one account hammered is refused after 10).

## 2. Push notifications

**Design.**
- A phone's registration belongs to the login token that made it: sign-out,
  "sign out everywhere" or a revoked token deletes the token row and the
  database cascade removes the push registration.
- An observer on `Alert` (created) schedules **one delayed digest job per
  practice**, so the hourly detection never buzzes a phone ten times. Each alert
  is announced once (`alerts.push_sent_at`).
- Recipients: members whose **current** role holds `alerts.view`, on phones whose
  login has not expired, in that practice only.
- The message is generic ("2 nouvelles alertes dont 1 critique"). No patient,
  product or batch is ever put on a lock screen.

**New files**

| File | Role |
|---|---|
| `database/migrations/2026_10_05_000001_create_device_push_tokens_table.php` | `device_push_tokens` (RLS on `tenant_id`, unique `(tenant_id, token)`, FK to `personal_access_tokens` with cascade) and `alerts.push_sent_at` |
| `app/Domain/Identity/Models/DevicePushToken.php` | model |
| `app/Domain/Identity/Actions/RegisterDevicePushTokenAction.php` | idempotent register; removes another user's row for the same device; revoke |
| `app/Http/Controllers/Api/V1/Identity/PushTokenController.php` | `store`, `destroy` |
| `app/Http/Requests/Api/V1/Identity/RegisterPushTokenRequest.php` | `token` (20-4096), `platform` (android\|ios), `app_version` |
| `app/Domain/Identity/Push/{PushSender,PushMessage,PushResult}.php` | sender contract |
| `app/Domain/Identity/Push/{NullPushSender,LogPushSender,FcmPushSender}.php` | `none`, `log` (dev), `fcm` (Firebase HTTP v1, service-account JWT, cached access token, dead-token detection) |
| `app/Domain/Inventory/Actions/SchedulePushForNewAlertAction.php` | debounced scheduling |
| `app/Domain/Inventory/Jobs/SendAlertPushDigestJob.php` | queued job |
| `app/Domain/Inventory/Actions/SendAlertPushDigestAction.php` | recipients, text, send, delete dead tokens |
| `config/push.php` | `PUSH_DRIVER`, `PUSH_DIGEST_DELAY_SECONDS`, `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT` |
| `tests/Feature/Api/V1/PushNotificationTest.php` | 13 tests |

**Edited files**: `app/Domain/Inventory/Models/Alert.php` (observer, `push_sent_at`),
`app/Providers/AppServiceProvider.php` (binds the sender from `PUSH_DRIVER`),
`routes/api.php` (`POST` and `DELETE /api/v1/push-tokens`; any signed-in member),
`docker-compose.yml` (`PUSH_DRIVER` defaults to `log` on the dev app container).

**API**

| Method | Path | Body | Result |
|---|---|---|---|
| POST | `/api/v1/push-tokens` | `token`, `platform`, `app_version?` + `Idempotency-Key` | 204; 422 on bad token/platform; 401 signed out |
| DELETE | `/api/v1/push-tokens` | `token` | 204 |

**Tests (13)**: registers once however often; 422 on bad input; 401 signed out;
phone handed to a colleague stops notifying the first person; switching off
removes only that phone; sign-out deletes the phone; generic text only; a burst
is one notification and each alert is announced once; a member who lost the role
is not notified; one practice never notifies another's phones; `none` driver
sends nothing but keeps tokens; `log` driver writes what would be sent; FCM:
dead token deleted, working one sent, no clinical text in the payload.

**Live proof (dev stack)**: registered a token through the real API → raised a
real alert → the server logged `push.sent` with "1 alerte critique à traiter".
Delivery to a real phone needs the owner's Firebase project (see `docs/RELEASE.md`).

**Operating it**: `PUSH_DRIVER=fcm`, `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT`
(path to the service-account JSON or that JSON base64-encoded), then
`php artisan config:cache` and restart Horizon. The job runs on the `default`
queue (Horizon is already part of the stack).

## 3. Data export keeps every attachment

**Problem.** `GenerateDataExportJob` wrote `files/<original name>`. Two
attachments both called `IMG_0001.jpg` overwrote each other and one piece of
evidence vanished from a legal archive without any error.

**Change** (`app/Domain/Reporting/Jobs/GenerateDataExportJob.php`).
- Files are stored as `<media id>_<path-safe name>` (`storedName()`, also blocks
  `../` and backslash tricks).
- `files_manifest.json` lists every file: media id, original name, stored name,
  size, **SHA-256**. A file the database lists but storage no longer holds is
  recorded as `missing` instead of being skipped.
- Writing a file or uploading the archive that fails now fails the export
  (previously `put()` returning false was ignored).

**Proof**: `DataExportRequestTest` (naming rules, path escape); live
`scripts/verify_export_files.py` (two same-named PNGs both present, contents
intact, checksums match). The full job round trip cannot run inside Pest (it
uses a separate admin DB session), which is why the live script exists.

## 4. Cycle creation refuses an inactive program

`app/Http/Requests/Api/V1/Sterilization/CreateCycleRequest.php`: the
`device_program_id` rule now also requires `is_active = true` (the device match
was already enforced). Test: `CycleCreationRulesTest` "refuses a program that
has been switched off".

## 5. Public sign-up switch

- `config/registration.php`: `STERIQORE_REGISTRATION_ENABLED` (default **true** so
  development and demos are unchanged).
- `RegisterTenantController`: when off, responds `403` with error code
  `REGISTRATION_DISABLED`.
- `.env.staging.example` sets it to **false**. Turn it on briefly to create the
  pilot practice, then off.
- Test: `RateLimitTest` "public sign-up can be switched off…".

## 6. Contract, env templates, ignores

- `docs/openapi.yaml` regenerated with the README procedure; contract test green.
- `.env.example` and `.env.staging.example`: push and registration variables.
- `.gitignore`: ignores `docs/_pilot_env.sh` (contains a token), generated
  captures, and code dumps (`BACKEND_DUMP.txt`, `all_code.txt`, `structure.txt`,
  `openapi.json`).

## If the backend owner accepts it, a suggested split

1. `fix(auth): per-account login limiter` — `AppServiceProvider` (limiter only), `routes/api.php` (login line), `RateLimitTest` (first two tests).
2. `feat(push): device tokens, alert digest, FCM sender` — section 2.
3. `fix(export): keep same-named attachments, add checksum manifest` — section 3.
4. `fix(cycles): refuse an inactive program` — section 4.
5. `feat(auth): public sign-up switch` — section 5.
6. `docs/chore: openapi, env templates, ignores` — section 6.

`routes/api.php` and `AppServiceProvider.php` also contain other work in the
tree; stage those hunks with `git add -p`.

---

# Everything the backend lacks for the mobile app (for the web engineer)

The mobile app works against the backend **exactly as it is**. These are the
gaps found, in one place. None is applied by the mobile side. "Needs" says who
must decide or build.

| # | Gap | Effect today | Needs |
|---|---|---|---|
| P-1 | Login, registration, forgot-password and invitation-accept share 10 requests/minute **per IP** | A clinic behind one connection can lock colleagues out at opening time | Web engineer: a per-account login limit plus a higher per-IP ceiling |
| P-2 | No push-notification support (no token registry, no sender) | The app's notification switch answers "ce serveur ne propose pas encore les notifications"; alerts stay in the Alertes tab | Web engineer + a Firebase project. The complete proposal is in `new-files.zip` |
| P-3 | Data export writes attachments as `files/<original name>` | Two same-named files overwrite each other: evidence silently missing from the archive (Cahier §8) | Web engineer, **priority** |
| P-4 | A cycle can be created with a switched-off device program | Wrong program recorded on a cycle | Web engineer |
| P-5 | Public practice sign-up is open | Anyone who finds the server can create practices | Web engineer: a switch, off on the pilot server |
| P-6 | Alert texts are English strings in a fixed shape (`Stock for "X" is below threshold (2/10).`) | The app translates the four known shapes and shows anything else unchanged; a new alert type would appear in English | Return a stable code + parameters (and ideally French text) |
| P-7 | No API for alert thresholds (`AlertSettings` exists server-side, no route) | Thresholds can only be changed on the web | Optional: read/update route |
| P-8 | No "overdue control" alert (A-05) | The Cahier's control logbook cannot warn on the phone | The clinic must state the control schedule first |
| P-9 | `POST /v1/sites` and `POST /v1/locations` do not exist (A-06) | Sites and storage locations are created on the web only (as the Cahier assigns) | None for the pilot |
| P-10 | No `PATCH /v1/cycles/{id}` (A-07) | Cycle notes live on the phone only | Optional |
| P-11 | The server has six roles; the prosthetic brief speaks of a "reception" role | Payment edits are limited to owner/admin (`prosthetic_payments.manage`) | Decision: which role plays reception |
| P-12 | No erasure-request flow, no stated retention period | Open RGPD question in `PRIVACY.md` | Client's DPO + web engineer |
| P-13 | Prosthetic cases waiting too long raise no automatic alert (brief "post-MVP") | The waiting list shows aging colours, nothing is pushed | Later |
| P-14 | `429` answers carry no `Retry-After` | The app can only say "réessayez dans un instant" | Optional header |
| P-15 | Open items of `BACKEND_BUGS.md` | See that file | Web engineer to triage |

Proof for P-1 to P-5 existed on the dev stack before the revert (tests and live
scripts); they are described hunk by hunk above and the new files are in
`new-files.zip`. The proof script for P-3 is `verify_export_files.py`.
