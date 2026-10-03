# Clinic readiness breakdown — 3 October 2026

Written after re-reading both source documents (`Cahier des charges MVP`,
`Prosthetic Workflow Brief`), the backend routes, `ANOMALIES.md` and the
roadmap, and after re-running the live checks listed below. Every "done" has
a command or a test behind it; everything else is listed as open.

## 1. What is proven today

| Area | Evidence (re-run 3 Oct) |
|---|---|
| Mobile code quality | `dart analyze lib test` clean; `flutter test` **965 pass**, 2 skipped |
| Backend API | `tests/Feature/Api` **273 pass** (isolated runner, not the dev DB) |
| Six roles against the live server | `verify_authorization_matrix.py` ALL PASS (6 roles × 29 probes, cross-practice wall, role change mid-session); `verify_screen_calls_by_role.py`: every call the new screens make is allowed/refused exactly as the app expects, **0 mismatches** |
| Cahier journeys against the live API | `verify_stock_journey`, `verify_sterilization_journey`, `verify_prosthetic_journey`, `verify_empty_clinic_journey`, `verify_invitation_journey`, `verify_two_practices` (4 practices, 300 interleaved calls), `verify_idempotency` all PASS |
| Layout on small phones | 320×568 at 130 % text, 390×844, tablet — 33 cases across the Stock option, Lots, Catalogue, Suppliers, Orders, Sites, Patients, Alerts, Profile (a real overflow in the profile header and in shared `StatusBadge` was found and fixed today) |
| Every screen of the bottom nav | Accueil, Stock, Cycles (pipeline overview), Alertes, Prothèses (priority headline + longest-waiting), Plus/Profil (role-gated hub, live sync status, security) are now on the new design system |

## 2. Bugs found and fixed in this pass

1. **Login lockout for a whole clinic (backend, High).** Login, registration,
   forgot-password and invitation-accept shared one 10-requests/minute bucket
   per IP. Staff on the same reception Wi-Fi would lock each other out at
   opening time. Login now has its own limiter: 10/min per account, 120/min
   per IP. Tested, deployed to the dev stack, logged as `C-16`.
2. **Text-controller used after dispose** in four dialogs (new product family,
   scanner manual entry, control-test dialog, waiting-placement note):
   crash in debug, fragile in release. Fixed; leak guard updated.
3. **Overflows**: order card (date + total), movement menu on tablets,
   product tags with long family names, profile header, shared `StatusBadge`.
4. **Privacy**: the patient sheet could show another patient's work because
   server filters are substring matches (`PAT-00001` vs `PAT-000010`) —
   exact match enforced, with a decoy test.
5. **Crashes** when a supplier/product form opened outside its list screen.

## 3. What is still missing, split by who can close it

### A. Needs the phone (I can do these the moment it is attached; none can be proven without it)
The phone is **not attached right now** (`adb devices` is empty).
- A-02/A-03: the 8 journeys have never run on a device (`DEVICE_TEST_LOG.md` is empty). They are written; expect small selector fixes after the redesign.
- A-01: open a photo and an export from a phone against real storage links.
- Offline restart scenario (airplane mode), prosthetic PDF opens, create-case stopwatch (< 2 min), screen-time measurements, A→logout→B isolation on a real device.

### B. Needs a decision or an account from you (the project owner)
These block a store release or change scope, and I must not guess them:
1. **iOS in the pilot?** (Apple account + Mac path vs Android-only first.)
2. **Android upload keystore, Play Console account, final application id**
   (`com.sterymed.mobile` is provisional).
3. **Staging host + domain** (the TLS stack exists but has never been deployed) and the **Sentry DSN** and **support channel**.
4. **Patient identity.** The prosthetic brief asks for first/last name; the backend deliberately stores a pseudonymous reference (RGPD/HDS analysis is required before real patient data — Cahier §8). Decide: keep references, or add name fields with the legal analysis.
5. **A reception role.** The brief talks about "reception" editing payments; the backend has six roles (owner, admin, stock_manager, releaser, practitioner, viewer). Decide which existing role plays reception, or add one.
6. **Push notifications — built, needs your Firebase project to deliver.** Backend (token registry, digest, FCM sender) and the app (opt-in switch, tap-to-open) are done and tested; the live chain was proven up to the server's `push.sent`. To reach a real phone you create a Firebase project and give the 4 app values + a service-account key (steps in `docs/RELEASE.md`).
7. **Control schedule** (A-05): how often must a control be done? The server raises no "overdue control" alert until the clinic states the rule.
8. **Label printer model** to test real printing; reprint stays web-only per the Cahier.

### C. Code I can still do now
- Restyle the inner Cycles screens (detail, create, items, control tests, attachments, release) and the Prothèses inner screens (case detail, create, waiting list, payments) — the lists/homes are done, these still use the older layout.
- Evidence search and data-export screens (evidence result cards are done; the form and exports list are not).
- Patient creation as a real form instead of a single confirm dialog.
- Small backend-limited gaps (not bugs): synced cycle notes (A-07), site/location creation from mobile (A-06, web by design), alert thresholds (no API exists), dead code `ApiEndpoints.site` (A-08).

### D. Delivery and operations
- **Nothing is committed.** A large amount of work in both repos (mobile and `steriqore`, including the whole prosthetic module) exists only in the working tree. Commit in logical checkpoints before anything else; I did not do it unasked.
- CI has not been run on a candidate commit; staging not deployed; restore drill passed locally only.
- Acceptance (Cahier §10): the demo on staging, recorded, with written sign-off — not possible before B and A are closed.

## 4. Honest verdict

The product is feature-complete for the Cahier's mobile scope and proven
against the live API for all six roles. It is **ready for a supervised pilot
on Android once the phone runs are done and the owner inputs in section B
are given**. It is **not yet "accepted"**: no device journey has run, nothing
is committed, nothing is deployed to staging.

## 5. Suggested order

1. Commit the working tree in checkpoints (you decide the split).
2. Attach the phone → I run the journeys and fix whatever they find.
3. Answer section B items 1–5 (they gate the release pipeline and the patient-data question).
4. Staging deploy → A-01 → recorded demo → sign-off.
5. In parallel, I finish section C.
