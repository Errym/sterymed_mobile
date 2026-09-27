# UI Mapping

Which endpoint feeds which screen.

| Screen | Endpoints |
|---|---|
| Splash | `GET /v1/me` |
| Login | `POST /v1/auth/login` |
| Register | `POST /v1/tenants` |
| Dashboard | `GET /v1/cycles`, `GET /v1/alerts`, `GET /v1/audit-events` |
| Scanner | `GET /v1/labels/{code}` |
| Label detail | `GET /v1/labels/{code}`, `GET /v1/labels/{id}/usage` |
| Label blocked | `GET /v1/labels/{code}` |
| Label usage form | `POST /v1/labels/{id}/usage`, `GET /v1/patients` |
| Patients list | `GET /v1/patients`, `POST /v1/patients`, `DELETE /v1/patients/{id}` |
| Patient picker | `GET /v1/patients` |
| Cycle list | `GET /v1/cycles` |
| Cycle detail | `GET /v1/cycles/{id}`, items, control-tests, attachments |
| Cycle create | `GET /v1/devices`, `GET /v1/devices/{id}/programs`, `POST /v1/cycles` |
| Cycle transitions | `POST /v1/cycles/{id}/start\|complete\|submit-for-release\|release` |
| Cycle items | `GET/POST/DELETE /v1/cycles/{id}/items` |
| Control tests | `GET/POST /v1/cycles/{id}/control-tests` |
| Attachments | `GET/POST/DELETE /v1/cycles/{id}/attachments` |
| Stock levels | `GET /v1/stock-levels` |
| Stock issue | `POST /v1/stock-movements/issue` |
| Stock adjust | `POST /v1/stock-movements/adjust` |
| Stock transfer | `POST /v1/stock-movements/transfer` |
| Purchase orders | `GET /v1/purchase-orders` |
| PO detail | `GET /v1/purchase-orders/{id}` |
| PO create | `POST /v1/purchase-orders` |
| Goods receipt | `POST /v1/purchase-orders/{id}/receipts` |
| Suppliers list | `GET/POST /v1/suppliers` |
| Supplier detail | `GET/PATCH/DELETE /v1/suppliers/{id}`, `GET/POST /v1/suppliers/{id}/products` (attach a product to the supplier) |
| Products (Catalogue) | `GET/POST /v1/products`, `PATCH/DELETE /v1/products/{id}` |
| Non-conformities | `GET/POST /v1/non-conformities`, `POST /v1/non-conformities/{id}/resolve` |
| Lots (batches) | Derived from `GET /v1/stock-levels` — no dedicated `/v1/batches` endpoint exists yet (BUG-003, see below) |
| Evidence search | `GET /v1/evidence-search`. `GET /v1/evidence-search/export` **exists as a constant but has zero call sites** — no export button is wired to it yet. |
| Alerts | `GET /v1/alerts`, `POST /v1/alerts/{id}/resolve` |
| Audit | `GET /v1/audit-events` |
| Team | `GET /v1/members` (BUG-011, fixed — was missing entirely, now returns real data) |
| Sites | `GET /v1/sites` |
| Devices | `GET/POST/PATCH/DELETE /v1/devices` |
| Device programs | `GET/POST/PATCH/DELETE /v1/devices/{id}/programs` |
| DLU rules | `GET /v1/dlu-rules` |
| Settings | `GET /v1/me`. "Recevoir les alertes" toggle is local-only — OS notification permission via `permission_handler`, no backend call. |
| About | Local (static `BuildInfo`, no endpoint) |
| Data exports | `GET/POST /v1/data-export-requests` |
| Sync queue | Local (Hive outbox) |
| Prosthetic dashboard | `GET /v1/prosthetic-dashboard` |
| Prosthetic case list | `GET /v1/prosthetic-cases` |
| Prosthetic case create | `POST /v1/prosthetic-cases`, `GET /v1/laboratories` |
| Prosthetic case detail | `GET /v1/prosthetic-cases/{id}`, `GET .../status-history`, `PATCH /v1/prosthetic-cases/{id}` (Quick Edit), `POST .../status`, `GET/POST/DELETE .../attachments` |
| Prosthetic waiting-placement | `GET /v1/prosthetic-cases/waiting-placement` |
| Prosthetic laboratories | `GET/POST /v1/laboratories` |

Not listed above (no data-fetching endpoint of their own): the bottom-nav
shell (`ShellScreen`, pure layout), `CameraPermissionScreen` (device OS
permission only, see `docs/SECURITY.md`), and `CycleReleaseScreen` (a
sub-step of the transitions already covered by "Cycle transitions").

## States each screen handles

For every screen:
- Loading (skeleton or spinner)
- Loaded (data)
- Empty (French message + CTA)
- Error (French message + retry)
- Offline (if write) — enqueue
- Pending sync (if write) — badge

## Missing endpoints (current, 2026-09-26)

- `PATCH /v1/cycles/{id}` — missing (BUG-007). Notes are cached
  device-only, never synced.
- `GET /v1/locations` — missing (BUG-002). Mitigated: mobile derives
  location options from `GET /v1/stock-levels` instead.
- `GET /v1/batches` — missing (BUG-003). Same mitigation as above.
- `POST /v1/sites`, `POST /v1/locations` — missing (BUG-004).
- `POST /purchase-orders/{id}/receipts/attachments` — missing (BUG-009).
- No print/export endpoint for a prosthetic case (BUG-024).

**No longer missing** (kept here so a reader searching for an old entry
doesn't wonder where it went — full detail in `BACKEND_BUGS.md`):
`GET /v1/members` (BUG-011, fixed), `PATCH /v1/products/{id}` (BUG-006,
confirmed present), `PATCH /v1/patients/{id}` (BUG-005 — reclassified:
patients have no editable fields by design, not a missing endpoint), the
entire Prosthetic domain (real and live now — `docs/PROSTHETIC_MODULE.md`,
ADR 0011).

All tracked in `docs/BACKEND_BUGS.md` and summarized in
`docs/MISSING_FEATURES.md`.
