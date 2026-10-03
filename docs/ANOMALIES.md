# Anomaly report

Cahier §10.5: **zero open blocking or critical anomaly** before acceptance.
Last updated 2 October 2026. Every row names the evidence, so a status can be
re-checked. Backend defects are also written up in full in `BACKEND_BUGS.md`.

Severity: **Blocking** = the clinic cannot do a Cahier journey. **Critical** =
data loss, wrong clinical record, or one clinic seeing another's data.
**High** = a feature fails in a real deployment. **Medium** = a workaround
exists. **Low** = cosmetic or dead code.

## Open

| ID | Severity | What | Why it is open | Needed to close |
|---|---|---|---|---|
| A-01 | **High** | Presigned file links work on the dev stack (`BUG-010` fixed) but have not been opened from a phone or from staging | The fix needs the real storage host (`AWS_PUBLIC_ENDPOINT_*`), which exists only on staging | Phase 9 `T9.4`: open a photo and an export on a phone against staging; on dev over USB also `adb reverse tcp:9023 tcp:9023` |
| A-02 | Medium | No device run has ever been logged (`DEVICE_TEST_LOG.md` has no entries) | No phone was attached to this machine | Run the owed steps in `DEVICE_TEST_LOG.md`; this blocks Gate 8 |
| A-03 | Medium | The Chrome/device journeys have never been executed. `flutter drive` stayed at "Waiting for connection from debug service" on this machine (three attempts), and there is no Visual Studio toolchain for desktop. All 8 journeys are written and analyze clean: `prosthetic_case`, `waiting_placement`, `stock_issue`, `conflict_409`, `goods_receipt`, `scanner_usage`, `alert_resolve` in `integration_test/journeys/`, plus the existing `web_stock_test`, `web_role_sweep_test`, `cycle_lifecycle`, `auth` | Tooling on this machine, not product; the same flows are proven against the live API by the `scripts/verify_*_journey.py` scripts | Run them: seed with `scripts/seed_web_journeys.py`, then `scripts/run_web_journeys.sh journeys/<file>` on a machine where it connects, or `flutter drive` on a phone. Expect small selector fixes on first run |
| A-04 | Medium | The offline restart journey cannot be automated (it needs airplane mode on a phone). The empty `offline_sync_journey_test.dart` was removed so no empty file pretends to be a test | The behaviour is proven below the UI: `test/unit/storage/*`, `test/live/queue_lost_response_live_test.dart`, `verify_idempotency*.py` | Manual device scenario from `OFFLINE_MATRIX.md`, logged in `DEVICE_TEST_LOG.md` |
| A-05 | Low | Server raises no "overdue control" alert; only low stock, near expiry, expired, failed cycle | The Cahier does not define how often a control is due, so inventing a rule would be a guess | Clinic states the control schedule, then a backend change |
| A-06 | Low | `POST /v1/sites` and `POST /v1/locations` do not exist (`BUG-004`) | Site and location setup is a web step by design (Phase 3) | None for the pilot |
| A-07 | Low | No `PATCH /v1/cycles/{id}`; cycle notes are kept on the phone only (`BUG-007`) | Cycle items edit in place; only the free-text note is local | Backend route, if the clinic wants synced notes |
| A-08 | Low | `ApiEndpoints.site(id)` points at a route that does not exist (`BUG-025`) | Dead code with zero callers, guarded by a contract test | Delete when convenient |
| A-09 | Low | Some write routes validate the body before checking permission (e.g. `POST /v1/products`, `/v1/purchase-orders`) | A refused user can see validation messages but cannot create anything; proven for all six roles | None required |

## Closed

| ID | Severity | What | Fix | Evidence |
|---|---|---|---|---|
| C-01 | **Critical** | A practice could be answered 403 on every endpoint after another practice registered (`BUG-026`): one global permission cache of per-practice roles | `TenantPermissionRegistrar`, one cache entry per practice | `verify_authorization_matrix.py` failed before, passes after; `PermissionCachePerTenantTest` |
| C-02 | High | The minimum-version gate could never trigger: the server never sent `X-Min-App-Version` | `EnforceMinAppVersion` middleware and `MIN_APP_VERSION` setting | `MinAppVersionTest` (5), live 426 check on the dev stack, `app_guard_test` |
| C-03 | High | 6 layout overflows at 320x568 with 130% text (alerts row, login footer, prosthetic info card, lock and update screens, date picker, button labels, evidence empty state); a clipped action could be unreachable | Wrap / Flexible / scroll | `layout_resilience_test` (phone, small phone at 130%, tablet; 7 screens) |
| C-04 | High | Settings offered a "Recevoir les alertes" switch although there is no push infrastructure: it only asked for an OS permission and nothing was ever delivered | Switch removed; the screen says alerts are in-app only | `settings_screen_test` |
| C-05 | Medium | About text claimed "l'audit est immuable" and encrypted data without saying what | Reworded to what is true (HTTPS, journalised actions) | `settings_screen_test` |
| C-06 | Medium | `docs/openapi.yaml` was stale (prosthetic summary endpoint and filters missing), so the contract snapshot test failed | Regenerated from the routes | `OpenApiContractTest` passes |
| C-07 | Medium | Two prosthetic status tests still expected the old "no dialog" behaviour; the leak check flagged a controller owned by its parent; 4 goldens were stale | Tests updated, allowlist entry with reason, goldens regenerated and re-run stable | full suite 833 pass, analyzer clean |
| C-08 | Medium | Backend had no tests for the laboratories routes or `/prosthetic-cases/waiting-placement` | 6 new tests (create/list/archive, validation, roles, tenant isolation, inclusion rule and days) | `ProstheticWorkflowTest` 14 pass |
| C-09 | Medium | No proof that every role is refused what it must be refused, nor that one practice cannot touch another | Authorization matrix script | `verify_authorization_matrix.py`: 6 roles x 29 probes, tenant wall (read, write, lists, credentials, cross-practice case), a role changed mid-session takes effect on the same token |
| C-10 | Low | Screen speed had never been measured | `scripts/measure_api_times.py` | all 13 first-load screens answer in under 0.31 s (server side) |
| C-11 | Low | `BUG-024`: no print endpoint for a prosthetic case | The phone builds the PDF | `prosthetic_case_pdf_test` |

## Added in Phase 9 (2 Oct 2026)

| ID | Severity | What | Fix | Evidence |
|---|---|---|---|---|
| C-12 | High | The app still carried the placeholder identity `com.example.sterymed_mobile`, `mobile-release-android.yml` and `mobile-release-ios.yml` were empty, and the iOS build ran red on every push | Provisional id `com.sterymed.mobile` (owner to confirm), signed-AAB release workflow, iOS workflows made manual-only and honest | `verify_release_config.py --mode android-release` passes; signed obfuscated `flutter build appbundle` with a throwaway keystore (see RELEASE.md) |
| C-13 | High | Presigned links used the internal storage host (A-01, `BUG-010`) | `PublicPresigner` signs against the public endpoint | `verify_media_links.py` ALL PASS, `PublicPresignerTest` |
| C-14 | High | Staging had no TLS and its env template lacked the new settings | Caddy service with automatic HTTPS, `API_DOMAIN` / `STORAGE_DOMAIN` / `AWS_PUBLIC_ENDPOINT_*` / `MIN_APP_VERSION` in the template | `docker compose config` and `caddy validate` pass; not yet deployed (no host) |
| C-15 | Medium | Backup and restore had never been performed and timed | Drill script | `verify_backup_restore.py` ALL PASS: dump 7 s, restore 20 s, counts equal, roles intact; media deleted then restored in 8 s |
| C-16 | **High** | Login, registration, forgot-password and invitation-accept shared ONE limit of 10 requests/minute per IP. A clinic whose staff share one public IP (reception Wi-Fi, carrier NAT) would lock colleagues out at opening time; the 11th sign-in was refused | Login now has its own limiter: 10/min per account+IP (guessing stays blocked) and a 120/min per-IP flood ceiling; the other three keep the strict 10/min | `RateLimitTest` (20 colleagues from one IP all pass, one account hammered is refused after 10); 273 API tests pass; deployed to the dev stack |
| C-17 | **High** | Push notifications (Cahier §7 "notifications") did not exist: no token registry, no sender, no client | Backend: `device_push_tokens` (tied to the login token, removed on sign-out), `POST/DELETE /v1/push-tokens`, alert observer → one delayed digest per practice, FCM HTTP v1 sender (+ log/none drivers). Mobile: opt-in switch in Profil, token registration, tap opens Alertes (allow-listed routes only), foreground banner. Generic text only | 13 backend tests, 24 mobile tests, live proof on the dev stack (register → alert → `push.sent`). **Delivery to a real phone needs the owner's Firebase project** (see RELEASE.md) |
| C-18 | **High** | A data export wrote attachments under their original name, so two files with the same name (two photos both called IMG_0001.jpg) overwrote each other and one piece of evidence disappeared from a legal archive with no error | Files are stored as `<media id>_<name>` (path-safe), a `files_manifest.json` lists every file with size and SHA-256, files missing from storage are recorded as `missing`, and a failed upload now fails the export | `verify_export_files.py` ALL PASS on the live stack; `DataExportRequestTest` (naming rules) |
| C-19 | Medium | A cycle could be created with a sterilization program that had been switched off (the device match was already enforced) | `CreateCycleRequest` requires the program to be active | `CycleCreationRulesTest` |

## Gate 8 status

- Authorization matrix green, including wrong-practice attempts: **done** (C-09).
- Journeys 1-6 recorded on a device with no hidden fake data: **not done** (A-02).
- Zero open blocking or critical: **no blocking or critical item is open**; A-01 is High and must be closed on staging before acceptance.
- CI green on the candidate commit: **not checked** (nothing is committed).
