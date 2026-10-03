# Docs

Start with [ULTIMATE_ROADMAP.md](ULTIMATE_ROADMAP.md): the honest rating, requirement
coverage, milestones M1-M3 and the phase schedule. It is built on
[CLINIC_READY_MASTER_PLAN.md](CLINIC_READY_MASTER_PLAN.md) (task catalogue, six-role matrix,
release blockers F01-F18).

## Planning and audit evidence

| File | What it is |
|---|---|
| [ULTIMATE_ROADMAP.md](ULTIMATE_ROADMAP.md) | Rating, coverage vs the two briefs, phased schedule, risks, definition of done |
| [CLINIC_READY_MASTER_PLAN.md](CLINIC_READY_MASTER_PLAN.md) | Task IDs (S/O/R/C/I/P/A/V/D/H), phases, offline policy, completion ledger |
| [SOURCE_AUDIT_FINDINGS.md](SOURCE_AUDIT_FINDINGS.md) | File/line evidence behind every finding |
| [SOURCE_REVIEW_SCOPE.md](SOURCE_REVIEW_SCOPE.md), `SOURCE_REVIEW_INVENTORY.csv` | What the 2026-10-01 review covered |
| [phase0/](phase0/CONTRACT_MATRIX.md) | Contract matrix, backend dependency register, build baseline |
| [BACKEND_BUGS.md](BACKEND_BUGS.md) | Backend gaps with curl reproductions (cited from code comments) |

## How the app works

| File | What it is |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layering, feature structure, DI, routing |
| [API_CONTRACT.md](API_CONTRACT.md), [ERROR_MATRIX.md](ERROR_MATRIX.md) | Envelope, error codes, handling |
| [OFFLINE_MATRIX.md](OFFLINE_MATRIX.md) | What queues offline and the sync rules |
| [ROLE_MATRIX.md](ROLE_MATRIX.md), [UI_MAPPING.md](UI_MAPPING.md) | Permissions by role; screen to endpoint map |
| [PROSTHETIC_MODULE.md](PROSTHETIC_MODULE.md), [adr/0011-prosthetic-module-adopted.md](adr/0011-prosthetic-module-adopted.md) | Prosthetic module |
| [LOCALIZATION.md](LOCALIZATION.md) | French-only string handling |

## Operating it

| File | What it is |
|---|---|
| [SECURITY.md](SECURITY.md), [PRIVACY.md](PRIVACY.md) | Implemented controls and open legal questions |
| [TESTING.md](TESTING.md), [CICD.md](CICD.md) | Test inventory and pipelines |
| [BACKUP_RESTORE.md](BACKUP_RESTORE.md), [RUNBOOK.md](RUNBOOK.md) | Local data, recovery, triage |
| [RELEASE.md](RELEASE.md), [ANOMALIES.md](ANOMALIES.md) | How a build ships and what the owner provides; every defect found, with status |
| [DEVICE_TEST_LOG.md](DEVICE_TEST_LOG.md) | Physical-device setup, gotchas and run log (no runs yet) |
| [USER_GUIDE.md](USER_GUIDE.md) | French user guide skeleton (screenshots missing) |
