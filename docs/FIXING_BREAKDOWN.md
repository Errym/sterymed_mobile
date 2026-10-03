# SteryMed — Ship Plan

Written by the mobile engineer on 3 October 2026, after re-reading the Cahier
and the prosthetic brief and re-checking every claim of the previous version of
this document against the code, the live API and the tests. It replaces that
version. Nothing below is marked done unless a command or test proves it.

**Tags used in every table**

| Tag | Meaning |
|---|---|
| ✅ proven | done, with the evidence named |
| 🔧 I do | code work I can finish alone, in the order given |
| 📱 phone | needs your phone attached; I run it, you only plug it in |
| 🧑 you | needs a decision, an account or a signature from you |

---

## 1. Where the product stands (3 Oct 2026)

| Layer | State | Evidence |
|---|---|---|
| Mobile code | ✅ proven | `dart analyze lib test` clean; **1,097 tests pass, 0 fail** (run in chunks); line coverage **61.9 %** (core 76.5, shared 89.2, features 59.6, prosthetic 60.4), enforced by per-layer floors in CI; debug APK builds with Firebase plugins |
| Backend API | ✅ proven | 272 Pest API tests pass in the isolated runner on the backend exactly as its owner left it; OpenAPI contract test green |
| Six roles | ✅ proven | `verify_authorization_matrix.py` (6 roles × 29 probes + cross-practice wall); `verify_screen_calls_by_role.py` 0 mismatches |
| Cahier journeys on the live API | ✅ proven | stock, sterilization, prosthetic, empty-clinic, invitation, two-practices, idempotency, export scripts all PASS |
| Small screens / large text | ✅ proven | `layout_resilience_*` tests at 320×568 @130 %, 390×844, tablet |
| Push notifications | ✅ app side built and tested (dormant) · 🧑 the **server has no push support** and is left untouched; needs the backend owner and a Firebase project | `push_service_test` (18), `push_remote_test`, `docs/backend-proposal/` |
| Git | ✅ mobile committed, tree clean · the backend is **not touched** by the mobile work and is the web engineer's to commit | `git log` |
| A real phone | 📱 never run | `DEVICE_TEST_LOG.md` is empty |
| Staging, signed build, CI on a candidate commit | 🧑 not started | needs your host, keystore, Play account |

## 2. Corrections to the previous breakdown

The previous version listed eight "P0 source defects". Re-checked today (the backend is left exactly as its owner has it; backend findings are proposals, not applied changes):

| P0 | Verdict |
|---|---|
| 1 double idempotency key · 2 stranded `syncing` items · 3 item edit deletes then recreates · 4 scan GET mutates · 5 foreign practitioner · 6 permission cache | ✅ **already fixed** before this review (durable outbox with one key per intent and startup recovery; `PATCH` item; read-only scan; `EligiblePractitioner`; `TenantPermissionRegistrar`) |
| 7 export overwrites same-named files | ❌ **real, in the backend, not applied by mobile**: the export writes `files/<original name>`, so same-named attachments overwrite each other (violates Cahier §8). A fix was written and proven, then reverted; it is a proposal for the backend owner (`docs/backend-proposal/`, item P-3) |
| 8 cycle accepts another device's program | ⚠️ the device match is enforced; **a switched-off program is still accepted** (backend, proposal P-4) |

Also stale in the old text: test counts, "no push", the medium list (dead
screens, `dentistrack` image, Inter font registration, goldens platform pin,
`.gitattributes`, application id are all done).

## 3. Work I do in code — in this order (🔧)

Each step ends with analyzer clean + its tests + a commit.

| # | Step | Done when |
|---|---|---|
| 1 | Inner **Cycles** screens on the new design: detail, create, items, control tests, attachments, release | each opens with a header summary, role-aware actions; layout test at 320 px; existing cycle tests green |
| 2 | Inner **Prothèses** screens: case detail, create, waiting list, payments | brief §6–§9 fields visible; create stays under 2 min (measured on phone later) |
| 3 | **Data export** request screen + **patient creation** as a real form | preview + sections like the other forms; tests |
| 4 | **User guide** (`USER_GUIDE.md`) written per role from the real screens | one page per role, French |
| 5 | Final **full `flutter test`** run alone on a quiet machine, goldens regenerated if needed, coverage floor check | green log kept in `build/` |
| 6 | Hand `docs/backend-proposal/` to the web engineer and record their decision per item | their call; the backend is not edited by the mobile side |

## 4. Needs your phone (📱) — the device matrix

Run with `scripts/run_device_journeys.sh` plus the manual rows. Each row is
logged in `DEVICE_TEST_LOG.md` with date, build and result; every failure is
fixed and re-run.

| Group | Scenarios |
|---|---|
| Scanner | QR **and** DataMatrix; 5/10/20/30/50 cm; 0/45/90°; low light and glare; scuffed label |
| Navigation | hardware back from Cycles / Achats / Fournisseurs / Alertes (never exits the app mid-flow) |
| Files | cycle photo full-screen; cycle PDF in the OS viewer; prosthetic PDF opens and prints; export archive downloads and opens (**A-01**) |
| Camera | prosthetic photo from camera and gallery; permission permanently denied → recovers |
| Offline | airplane mode → issue stock → back online → synced once; kill the app mid-form → draft survives |
| Security | A logs out → B logs in → no A data; 5 min in background → fingerprint; app switcher hides content |
| Notifications | permission asked once (Android 13+), only when switching on; alert → notification → tap opens Alertes (needs Firebase) |
| Speed | slow 3G; **T6.6** prosthetic case in < 2 min (stopwatch); **T7.7** render time of the 13 first-load screens |

## 5. Needs your decisions and accounts (🧑)

I will not guess these. The right column is what I recommend.

| # | Decision / input | Why it matters | Recommendation |
|---|---|---|---|
| 1 | iOS in the pilot? | Apple account + Mac path | Android first; iOS in v1.1 |
| 2 | Android upload keystore, Play Console, **final application id** (`com.sterymed.mobile` is provisional) | cannot cut a signed build | create now; the id is permanent once published |
| 3 | Staging **host + domain**, Sentry DSN, support channel | staging stack exists, never deployed | one small VPS with the existing Caddy stack |
| 4 | **Firebase project** (4 app values + service-account key) | push cannot reach a phone | steps in `RELEASE.md` |
| 5 | Patient identity: first/last name (brief) vs pseudonymous reference (backend, RGPD/HDS) | Cahier §8 requires the legal analysis before real patient data | keep references for the pilot; add names only after the analysis |
| 6 | Which role plays "reception" (payment edits) | brief §8 | use `admin` for the pilot, or add a role later |
| 7 | Control schedule (how often a control is due) | server raises no "overdue control" alert (A-05) | the clinic states the rule, then one backend change |
| 8 | Label printer model | real print test (reprint stays web-only) | order the clinic's model |
| 9 | Final launcher icon artwork | the icon files changed; final art needs your approval | send the mark |
| 10 | Which backend proposals (P-1…P-5, `ANOMALIES.md`) the web engineer accepts | the backend is theirs; mobile works against it unchanged | ask them item by item |

## 6. Staging and release sequence (after 5.2–5.4)

1. Deploy the staging stack (DNS, `.env.staging`, `AWS_PUBLIC_ENDPOINT_*`, migrate with the admin role).
2. Phone on the LAN: `GET /docs/api.json` over HTTPS; upload a photo through the API and open its link on the phone (closes **A-01**).
3. `MIN_APP_VERSION` above the current build → the app shows "Mise à jour requise".
4. Tag `v1.0.0` → `mobile-release-android.yml` builds the signed obfuscated AAB → Play **internal testing**.
5. Install over the debug build **with a pending outbox item** → nothing lost.
6. Run the six Cahier journeys on the phone against staging (below).

## 7. Acceptance — Cahier §10 mapped to proof

| Condition | Proof |
|---|---|
| Full demo journey works on staging, no hidden fake data | the six journeys, recorded on the phone (📱🧑) |
| Rights tested; one practice never reads another | ✅ `verify_authorization_matrix.py`, `verify_two_practices.py`, IDOR tests |
| Web and mobile consistent after create/edit/scan/sync | journey 6 on staging (📱) |
| Critical error cases handled: double click/scan, network cut, bad data, print failure | ✅ idempotency scripts and tests; device rows 13–14 (📱) |
| No open blocking/critical anomaly; backup/restore really tested | ✅ none open (`ANOMALIES.md`); `verify_backup_restore.py` ALL PASS locally, to repeat on staging |
| Code, access, docs and a recorded demo handed over | 🧑 after the steps above |

The six journeys: (1) create a practice, an admin and an assistant with
different rights; (2) create a product and supplier, order, receive a lot with
an expiry; (3) print a label on the web, scan it on the phone, record the exit
with no double count; (4) create and validate a cycle with controls, attachment
and operator; (5) trigger a stock/expiry alert, read the audit, export a
report; (6) check the same data on web and mobile.

## 8. Definition of done

- [ ] Section 3 steps 1–6 finished and committed on both repos
- [ ] Device matrix (section 4) logged, every failure fixed
- [ ] Decisions 1–4 answered and staging deployed
- [ ] Signed build installed on the pilot phone, upgrade keeps the outbox
- [ ] Six journeys pass on staging; recording handed over
- [ ] `ANOMALIES.md` has no open blocking or critical row
- [ ] Written acceptance by the project owner
