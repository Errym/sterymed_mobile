# Docs

Start with [DELIVERY_PLAN.md](DELIVERY_PLAN.md) (what to do, in order, to hand the
app to the clinic) and [FIXING_BREAKDOWN.md](FIXING_BREAKDOWN.md) (the verified
status of the product).

## Delivering

| File | What it is |
|---|---|
| [DELIVERY_PLAN.md](DELIVERY_PLAN.md) | Phone test script per role, then staging, release, pilot day, acceptance |
| [CLIENT_REQUEST.md](CLIENT_REQUEST.md) | Ready-to-send request to the client (French): accounts, decisions, pilot data |
| [FIXING_BREAKDOWN.md](FIXING_BREAKDOWN.md) | What is proven, what needs the phone, what needs the client |
| [RELEASE.md](RELEASE.md) | How a signed build is cut and published; what the owner provides |
| [ANOMALIES.md](ANOMALIES.md) | Every defect found, with status; open backend items P-1 to P-5 |
| [DEVICE_TEST_LOG.md](DEVICE_TEST_LOG.md) | Physical-device setup, gotchas and run log |
| [USER_GUIDE.md](USER_GUIDE.md) | French user guide per role |
| [backend-proposal/](backend-proposal/README.md) | Backend fixes proposed to the web engineer (not applied) |

## How the app works

| File | What it is |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layering, feature structure, DI, routing |
| [API_CONTRACT.md](API_CONTRACT.md), [ERROR_MATRIX.md](ERROR_MATRIX.md) | Envelope, error codes, handling |
| [OFFLINE_MATRIX.md](OFFLINE_MATRIX.md) | What queues offline and the sync rules |
| [ROLE_MATRIX.md](ROLE_MATRIX.md), [UI_MAPPING.md](UI_MAPPING.md) | Permissions by role; screen to endpoint map |
| [PROSTHETIC_MODULE.md](PROSTHETIC_MODULE.md), [adr/0011-prosthetic-module-adopted.md](adr/0011-prosthetic-module-adopted.md) | Prosthetic module |
| [LOCALIZATION.md](LOCALIZATION.md) | French-only string handling |
| [BACKEND_BUGS.md](BACKEND_BUGS.md) | Backend gaps with curl reproductions (cited from code comments) |

## Operating it

| File | What it is |
|---|---|
| [SECURITY.md](SECURITY.md), [PRIVACY.md](PRIVACY.md) | Implemented controls and open legal questions |
| [TESTING.md](TESTING.md), [CICD.md](CICD.md) | Test inventory and pipelines |
| [BACKUP_RESTORE.md](BACKUP_RESTORE.md), [RUNBOOK.md](RUNBOOK.md) | Local data, recovery, triage |
