# Docs

This folder mixes two things: the nine docs the master plan's Day 55
("Handoff") calls for by name, and a longer tail of working documents
this project accumulated along the way. The Day 55 split, per the plan,
is **six user-facing** (`README.md` — repo root, not here —
`API_CONTRACT.md`, `OFFLINE_MATRIX.md`, `RUNBOOK.md`, `BACKUP_RESTORE.md`,
`USER_GUIDE.md`) and **three internal** (`SECURITY.md`, `PRIVACY.md`,
`MIGRATION.md`). All nine were reviewed for staleness 2026-09-26 — several
had gone actively wrong (the prosthetic module marked deleted after it
was rebuilt for real, a privacy doc overstating what patient data the app
collects) and were fixed; see [`HANDOFF.md`](HANDOFF.md) for the current
entry point and [`PILOT_READINESS.md`](PILOT_READINESS.md) for the
current go/no-go read.

A later, separate deliverable — the final pilot-readiness check — added
three more: [`PILOT_READINESS.md`](PILOT_READINESS.md),
`DEMO_SCRIPT.md`, and [`HANDOFF.md`](HANDOFF.md) (this file's sibling,
not to be confused with this `docs/README.md` itself).

Everything else here — `ARCHITECTURE.md`, `CICD.md`,
`TESTING.md`, `ROLE_MATRIX.md`, `ERROR_MATRIX.md`, `DAILY_LOG.md`,
`BACKEND_BUGS.md`, `MISSING_FEATURES.md`, `UI_MAPPING.md`,
`LOCALIZATION.md`, `SUPPORT.md`, `PERFORMANCE.md`, `RELEASE.md`,
`PROSTHETIC_MODULE.md`, `DEVICE_TEST_LOG.md`, `adr/` — is working
documentation for whoever's building this, not part of that formal
handoff list. Check each file's own header for its actual status — the
individual docs are the source of truth for their own completeness, not
this index.
