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
| Suppliers | `GET/POST /v1/suppliers` |
| Alerts | `GET /v1/alerts`, `POST /v1/alerts/{id}/resolve` |
| Audit | `GET /v1/audit-events` |
| Team | `GET /v1/members` (returns 404 — see backend bugs) |
| Sites | `GET /v1/sites` |
| Devices | `GET/POST/PATCH/DELETE /v1/devices` |
| Device programs | `GET/POST/PATCH/DELETE /v1/devices/{id}/programs` |
| DLU rules | `GET /v1/dlu-rules` |
| Settings | `GET /v1/me` |
| Data exports | `GET/POST /v1/data-export-requests` |
| Sync queue | Local (Hive outbox) |

## States each screen handles

For every screen:
- Loading (skeleton or spinner)
- Loaded (data)
- Empty (French message + CTA)
- Error (French message + retry)
- Offline (if write) — enqueue
- Pending sync (if write) — badge

## Missing endpoints

- `GET /v1/members` — returns 404. Blocked.
- `PATCH /v1/patients/{id}` — missing.
- `PATCH /v1/products/{id}` — missing.
- `PATCH /v1/cycles/{id}` — missing.
- `GET /v1/locations` — missing.
- `GET /v1/batches` — missing.
- `POST /v1/sites` — missing.
- Prosthetic domain — does not exist.

All tracked in `BACKEND_BUGS.md`.
