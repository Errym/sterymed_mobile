# Delivery plan — from "it works on my machine" to "the clinic uses it"

For the person delivering the app (you). Written 3 October 2026 from what the
code, the tests and the live scripts prove today. Companion documents:
`CLIENT_REQUEST.md` (what to ask the client, in French, ready to send),
`FIXING_BREAKDOWN.md` (status), `RELEASE.md` (how a build is cut),
`DEVICE_TEST_LOG.md` (where results go), `backend-proposal/` (for the web engineer).

## 0. Where things stand

| | State |
|---|---|
| App code | Feature-complete for the Cahier's mobile column and the prosthetic brief. Analyzer clean; 1033+ tests; all 10 live backend scripts pass against the backend as its owner left it. |
| Backend | Untouched by the mobile work (owner's code). Four things it lacks are listed as proposals P-1…P-5 in `ANOMALIES.md`. |
| Never run on a phone | The scanner, camera, opening photos/PDFs from storage, offline mode, speed. This is what step 1 is for. |
| Not possible yet | A signed release, staging, push delivery: they need the client's accounts (step 4). |

## 1. Test on your phone today (about 2 hours)

1. USB debugging on; screen timeout long (Settings → Developer options → Stay awake).
2. Backend up (`docker compose up -d` in `steriqore`).
3. ```
   adb reverse tcp:8010 tcp:8010
   adb reverse tcp:9023 tcp:9023
   adb install -r build\SteryMed-test.apk
   ```
   Rebuild if you changed code: `flutter build apk --debug --dart-define=API_BASE_URL=http://localhost:8010/api --dart-define=ENV=dev`.
4. Sign in: clinic `zz-web-cd5cbb`, the six accounts and password are in
   `build/web-journeys/defines.json` (dev data only). The backend allows 10
   sign-ins per minute from one connection: wait a minute when switching accounts.

### What to check, per role

| Role | Must see | Must NOT see |
|---|---|---|
| **owner / admin** | every module in Plus (Sites, Appareils, Équipe, DLU for owner, Audit, Exports…); can create everywhere; can edit prosthetic payments | — |
| **stock_manager** | Stock movements, orders, receive goods, create cycles | "libérer" on a cycle; create patient; edit payments |
| **releaser** | cycle in "à libérer" shows the decision button; non-conformities | stock edits, orders |
| **practitioner** | Scanner → record a usage; create patient; prosthetic cases (not payments) | release, stock edits |
| **viewer** | everything readable | any create/edit/delete button |

### Scenarios (log each in `DEVICE_TEST_LOG.md`: date, build, result)

1. **Scanner**: print or display a label QR and a DataMatrix; scan at 10, 30 and 50 cm, in low light; a damaged label. Scan a product barcode in "Produit" mode.
2. **Cycle end to end** (stock_manager then releaser): new cycle → add instruments → start → complete → record a control test → release. The header's stepper and "next step" must follow.
3. **Stock**: issue, adjust (reason required), transfer; check the remaining stock shown before you confirm.
4. **Goods receipt**: receive an order with lot + expiry + a photo of the delivery note.
5. **Alerts**: the "Gants nitrile" low-stock alert should be there; open it, follow "Voir le stock", resolve it (stock_manager).
6. **Prosthetic**: create a case (time it: target under 2 minutes), change status, upload a photo from camera and from gallery, open the case PDF, check the waiting list and aging colours.
7. **Files**: open a cycle photo full screen, a PDF in the system viewer, an export archive. *If a link does not open, note it: storage links are only proven against the dev stack.*
8. **Offline**: airplane mode → issue stock → airplane off → it syncs once (Plus → Synchronisation shows it). Kill the app mid-form → reopen → the draft is back.
9. **Security**: leave the app 3 minutes → asks for fingerprint/PIN; the app-switcher preview is blank; sign out as A, sign in as B → no trace of A.
10. **Times**: a record you create now must show your phone's clock time (not 1–2 hours off).
11. **Small text / big text**: set the phone font to the largest; walk through Accueil, Stock, Cycles, Alertes.

Send me anything that fails (screen + what you did). Each failure becomes a fix and a re-run.

## 2. Agree the backend items with the web engineer (1 meeting)

Give them `docs/backend-proposal/README.md`. Ask for a decision on each, in
writing. The two that touch written requirements:

* **P-3 export overwrites same-named files** (Cahier §8, no silent loss of evidence).
* **P-4 cycle accepts a switched-off program.**

And three asks that only they can do: deploy **staging** with HTTPS (the compose
stack and `.env.staging.example` exist), switch **public sign-up** off on the
pilot server, and confirm the **login limit** (10/min per IP) is acceptable for a
clinic behind one connection. If they add push support, the app side is ready.

## 3. Fix what step 1 finds

I fix, you re-test, entries go in `DEVICE_TEST_LOG.md`. Repeat until the nine
checks above pass on your phone with the viewer, practitioner and owner accounts.

## 4. Get the client's accounts (send `CLIENT_REQUEST.md`)

Nothing can be published without: the Play developer account, the application id
decision, the upload keystore, the production API address, Sentry, support owner.
Optional but wanted: Firebase (needs step 2 first), label printer model.

## 5. Build and install the pilot version

Follow `RELEASE.md` §2: tag `v1.0.0`; CI verifies the configuration and builds
the signed bundle; upload to Play **internal testing**; add the clinic's phones.
Check on one phone that installing over the previous build **keeps a pending
queued item** (nothing lost on update).

## 6. Pilot day at the clinic

* Create the real practice, the real users with their roles, the devices and programs, the sites and storage locations, the DLU rules (the client supplies them: see the request).
* Walk each person through the guide for their role (`USER_GUIDE.md`, one page each).
* Run the **six Cahier journeys** on their phones against staging/production, recorded:
  1. create a practice, an admin and an assistant with different rights;
  2. create a product and supplier, order, receive a lot with an expiry;
  3. print a label (web), scan it on the phone, record the exit — no double count;
  4. create and validate a cycle with controls, attachment, operator;
  5. trigger a stock/expiry alert, read the audit, export a report;
  6. check the same data on web and mobile.
* Name the support person; watch **Plus → Synchronisation** daily for two weeks.

## 7. Acceptance (Cahier §10)

Handed over in writing: code and repositories, all accounts and secrets (kept by
the client, not by you), the guide, the recording of journey 1-6, the anomaly
list with no open blocking/critical item, and the client's signed acceptance.
`ANOMALIES.md` currently has no blocking or critical item open in the mobile
app; the open items are the backend proposals and the device/staging proofs.

## Honest limits to tell the client

* iOS is not part of this pilot.
* Notifications on the phone need a server feature that does not exist yet; alerts are in the Alertes tab.
* Patients are pseudonymous references by design; adding names needs the RGPD/HDS analysis first.
* Label printing and reprinting, site/location creation and alert thresholds are done on the web.
