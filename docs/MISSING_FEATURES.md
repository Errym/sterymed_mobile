# Missing Features & Workarounds

**Last updated:** 2026-09-26. This used to be a standalone list, dated
2026-09-18 — most of it was reclassified or fixed since (patient/product
edit, prosthetic's whole backend domain) without this file being updated
to match. It's now a thin index over the real source of truth,
`docs/BACKEND_BUGS.md` (25 entries, each with a curl reproduction) —
only the currently **open** gaps are listed here; anything fixed, closed,
or reclassified as "not a bug" lives in that file's own history, not
repeated here.

| BUG | Feature | Why | Priority |
|---|---------|-----|----------|
| 001 | Cycle attachment upload | Backend endpoint (`POST /cycles/{id}/attachments-base64`) works and is live-verified, but no mobile caller was ever built — the screen is disabled | 🟡 |
| 002 | Locations picker (dedicated) | No `GET /v1/locations` — mobile derives options from `GET /stock-levels` instead (see BUG-002 in `BACKEND_BUGS.md` and the Task 3.1 mitigation in `lib/core/bootstrap/stock_seed_check.dart`) | 🔴 |
| 003 | Batches picker (dedicated) | No `GET /v1/batches` — same mitigation as #002 | 🔴 |
| 004 | Site/location creation | No `POST /v1/sites` or `/v1/locations` | 🟡 |
| 007 | Cycle notes (server-side) | No `PATCH /v1/cycles/{id}` — notes are cached device-only (`CycleNotesCache`), never synced, see `docs/BACKUP_RESTORE.md` | 🟡 |
| 009 | Purchase-order receipt attachments | No `POST /purchase-orders/{id}/receipts/attachments` | 🟡 |
| 010 | Attachment/backup download URLs | Presigned URLs (`backups` + `media` disks) resolve to the internal `minio:9000` host, unreachable from outside the Docker network — needs infra/adapter work, not a mobile fix | 🔴 |
| 024 | Prosthetic case print/export | No such endpoint exists on the backend at all | 🟡 |

Reclassified as **not gaps** (kept here only so a reader searching for
the old row doesn't wonder where it went — full detail in
`BACKEND_BUGS.md`):

- **Patient edit / patient names** (old rows #1, #4) — patients are
  anonymous by design (`BUG-005`, `BUG-008`); there are no name fields to
  edit or return.
- **Product edit** (old row #2) — `PATCH /v1/products/{id}` exists;
  `BUG-006` closed it.
- **Prosthetic backend domain** (old row #9) — real and live now; see
  `docs/PROSTHETIC_MODULE.md` and `ADR 0011`.

Each open item above is documented in `docs/BACKEND_BUGS.md` with a curl
reproduction, root cause, and (where applicable) the mobile-side
mitigation and why it's a mitigation and not a fix.
