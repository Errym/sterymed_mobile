# Release guide (Android pilot)

How a SteryMed build gets from this repository to the clinic's phones, and what
the owner has to provide first. iOS is **not** in the pilot (no Podfile, no Mac);
its workflows are manual-only placeholders.

## 1. Owner inputs (nothing below works without them)

| Input | Why | Where it goes |
|---|---|---|
| **Application id** (provisional `com.sterymed.mobile`) | Identity of the app on every phone and on Google Play. **Permanent after the first Play upload.** Confirm or change it before that upload | `applicationId` in `android/app/build.gradle.kts`; `scripts/verify_release_config.py` refuses any `com.example.*` |
| **Upload keystore** (owned by the clinic or the freelancer's company, not a personal laptop) | Signs every release. Losing it blocks updates; Play App Signing can reset an upload key, so enrol the app in Play App Signing | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` as repository secrets |
| **Google Play developer account** | Internal-testing track for the pilot; no public listing before acceptance | account owner = the clinic, freelancer as a named user |
| **Production API address** (HTTPS, ends at `/api`) | The app is built against it | repository variable `PROD_API_BASE_URL` |
| **Sentry projects** (one per environment) | Crash reports from phones and the server | `SENTRY_DSN` secret (mobile), `SENTRY_LARAVEL_DSN` (server) |
| **Firebase project** (Cloud Messaging) | Push notifications for alerts | Mobile secrets `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID` (Project settings → Your apps → Android app `com.sterymed.mobile`); server `PUSH_DRIVER=fcm`, `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT` (service-account key: Project settings → Service accounts) |
| **Support owner** (a named person) | Receives alerts, watches sync failures daily for two weeks | `docs/RUNBOOK.md` contacts |

Generate the upload keystore once, on a machine the owner controls:

```
keytool -genkeypair -v -keystore upload-keystore.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks     # value of ANDROID_KEYSTORE_BASE64
```

Keep two copies of the `.jks` and its passwords in the owner's password manager.

## 2. Cutting a release

1. `main` is green (analyze, tests, coverage floors).
2. Update `CHANGELOG.md`.
3. Tag and push: `git tag v1.0.0 && git push origin v1.0.0`.
4. `Mobile — Release Android` runs: analyze, tests, restores the keystore, writes
   the release defines (`ENV=production`, API address, Sentry), **verifies the
   configuration** (`scripts/verify_release_config.py --mode android-release`:
   HTTPS API, no placeholder host, no `com.example` id, no debug key), builds the
   obfuscated bundle with the tag as version and the run number as build number,
   uploads `app-release.aab` and the debug symbols as artifacts, and deletes the
   keystore from the runner.
5. Download the `.aab` and upload it to the Play **internal testing** track.
   Keep the symbols artifact: it is needed to read a crash from an obfuscated build.

A debug-signed or unsigned release cannot be produced: Gradle refuses any
`Release` task without `android/key.properties` pointing at an existing keystore.

Proven locally on 2 Oct 2026 with a throwaway keystore: the verifier passes and
`flutter build appbundle --release --obfuscate` completes (see `ANOMALIES.md` C-12).
No real keystore exists yet, so no installable signed build has been produced.

## 3. Server side (staging and production)

`docker-compose.staging.yml` in the backend repository runs the app, Postgres,
Redis, MinIO and **Caddy**, which obtains real HTTPS certificates:

1. Point two DNS names at the host: the API (`API_DOMAIN`) and storage
   (`STORAGE_DOMAIN`).
2. Copy `.env.staging.example` to `.env.staging`; replace every `CHANGE_ME`. Set
   `APP_URL=https://<API_DOMAIN>` and
   `AWS_PUBLIC_ENDPOINT_MEDIA=AWS_PUBLIC_ENDPOINT_BACKUPS=https://<STORAGE_DOMAIN>`.
   These make photo and export links openable from a phone (BUG-010).
3. `docker compose -f docker-compose.staging.yml --env-file .env.staging up -d`.
4. First start only: run migrations with the admin role (`RUN_MIGRATIONS=true`
   in the template does it at boot; verify with `php artisan migrate:status`).
5. Staging and production are two separate hosts with two separate `.env` files
   and databases. The Docker build context excludes `.env*` (`.dockerignore`).
6. To retire an old phone build set `MIN_APP_VERSION` and restart; that build
   shows "Mise à jour requise".

Secrets live in the host's secret store or an untracked `.env.staging`; none are
in the repository (`secrets-scan.yml` runs gitleaks on every push).

## 4. Backup, restore and rollback

- Nightly: `backup:run --only-db` (02:00) and `steriqore:backup-media` (02:10).
- **Drilled on 2 Oct 2026 on the dev stack** (`scripts/verify_backup_restore.py`,
  ALL PASS): database dump 7 s, restore into a scratch database 20 s with every
  business table's row count equal and a practice's six roles intact; media
  mirror 9.7 s, a deleted photo restored in 8 s and served again with the same
  bytes. Dev data is small (a 2 MB dump); repeat on staging and write down the
  timings there.
- **Rollback of the API:** redeploy the previous image tag with the same `.env`;
  restore the pre-release dump if a migration changed data. Not yet rehearsed on
  staging.
- **Rollback of the app:** halt the Play rollout and promote the previous bundle;
  raise `MIN_APP_VERSION` only to retire a build that is actively harmful.

## 5. Before the pilot starts (Gate 9)

- [ ] A signed bundle installs on a phone, upgrades over the previous one with a
      pending queue, and a forced error shows up in Sentry.
- [ ] Staging is on HTTPS under its own domain, separate from production.
- [ ] A photo and an export open on a real phone from staging.
- [ ] Restore performed and timed on staging; rollback rehearsed.
- [ ] Physical matrix: a recent mid-range Android, a small-screen Android, a
      tablet; fresh install and upgrade; a flaky 3G profile.


## Push notifications — how to switch them on

Nothing ships with Firebase keys. A build without the four `FIREBASE_*` values
says "notifications not activated in this version" in Profil → Notifications,
and the server with `PUSH_DRIVER=none` (default) sends nothing.

1. Create a Firebase project; add an Android app with the final application id.
2. Mobile build: pass the four values as `--dart-define` (CI does it from the
   secrets listed above).
3. Server: set `PUSH_DRIVER=fcm`, `FCM_PROJECT_ID`, and `FCM_SERVICE_ACCOUNT`
   (path to the service-account JSON, or that JSON base64-encoded), then
   `php artisan config:cache` and restart Horizon.
4. On a phone: sign in → Profil → Notifications → switch on (the phone asks
   permission then) → trigger an alert (e.g. a failed control test) → the
   notification arrives within ~30 s, and tapping it opens Alertes.

What is sent is deliberately generic ("2 nouvelles alertes dont 1 critique"):
no patient, product or batch is ever put on a lock screen. Local development:
`PUSH_DRIVER=log` writes the would-be notification to the server log.
